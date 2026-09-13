;;; org-queue-harvest.el --- Turn Org entries into queue plists -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (org-ql "0.8"))
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The Org half of the queue: read the agenda files, hand
;; `org-queue-core' a list of plists.
;;
;; Everything Org-shaped is normalised here so the core never has to know
;; about it -- timestamps become YYYYMMDD integers, `Effort' becomes
;; minutes, an absent priority stays absent rather than becoming org's
;; default B, and clock lines are summed per entry rather than per
;; subtree so a parent does not inherit its children's hours.
;;
;; DONE entries are harvested too.  The core drops them from the plan but
;; needs them for calibration: an estimate is only worth correcting
;; against work that actually finished.

;;; Code:

(require 'cl-lib)
(require 'calendar)
(require 'org)
(require 'org-ql)
(require 'org-queue-core)

;; Called from `org-ql-select''s expansion, and defined in org-ql.el after
;; its point of use, which the byte-compiler cannot see.
(declare-function org-ql--normalize-query "org-ql" (query))

(defcustom org-queue-files nil
  "Files to harvest.  When nil, `org-agenda-files' is used."
  :type '(choice (const :tag "org-agenda-files" nil)
                 (repeat file))
  :group 'org-queue)

(defcustom org-queue-history-file
  (locate-user-emacs-file "org-queue-history.el")
  "Where planned days are recorded, so carry-over can be detected.

Kept outside the Org files on purpose: \"this was on yesterday's plan\"
is a fact about the planner, not about the task, and writing it into the
notes would make every plan a diff in the kb."
  :type 'file
  :group 'org-queue)

(defcustom org-queue-history-length 30
  "How many past plans to keep in `org-queue-history-file'."
  :type 'integer
  :group 'org-queue)

(defconst org-queue-harvest-query '(or (todo) (done))
  "The org-ql query harvested from.
Every entry with a TODO keyword, finished or not.")


;;;; Reading one entry

(defun org-queue-harvest--date (time)
  "Return TIME, an Emacs time value, as a YYYYMMDD integer."
  (when time
    (let ((decoded (decode-time time)))
      (+ (* 10000 (nth 5 decoded)) (* 100 (nth 4 decoded)) (nth 3 decoded)))))

(defun org-queue-harvest--timestamp-date (string)
  "Return the date of Org timestamp STRING as a YYYYMMDD integer."
  (when (and string (string-match-p "[0-9]" string))
    (when-let* ((parsed (ignore-errors (org-parse-time-string string t))))
      (when (nth 3 parsed)
        (+ (* 10000 (nth 5 parsed)) (* 100 (nth 4 parsed)) (nth 3 parsed))))))

(defun org-queue-harvest--effort ()
  "Return the current entry's Effort in minutes, or nil if unestimated."
  (when-let* ((raw (org-entry-get (point) "Effort")))
    (when (org-string-nw-p raw)
      (let ((minutes (org-duration-to-minutes raw)))
        (when (and minutes (> minutes 0)) (round minutes))))))

;;;; Time spent, from state transitions

;; This config does not clock.  Time spent on an entry is the time it sat
;; in a working state, read from the LOGBOOK transitions the `!' and `@'
;; flags in `org-todo-keywords' already write:
;;
;;   - State "DONE"       from "STARTED"    [2025-01-08 Wed 15:25]
;;   - State "STARTED"    from              [2025-01-08 Wed 15:15]
;;
;; is ten minutes of work.  The `from' field is NOT used -- the real kb
;; leaves it blank on most lines (only 54 of 251 logbooks carry one) -- so
;; the state of an interval is taken from the ENTRY THAT OPENS it, and its
;; end from whatever transition came next.  That also means the parser does
;; not care what the states were called: this kb's history contains
;; STARTED, CANCELLED, OBSOLETE and NEXT from an older schema, and they
;; measure exactly as well as PROG does.
;;
;; Org parses these stamps to minute resolution and discards the seconds
;; the kb happens to carry, which is the right granularity here anyway.

(defcustom org-queue-working-states '("PROG" "STARTED")
  "TODO states whose duration counts as time spent.

STARTED is this kb's older name for PROG and is kept so historical
entries measure rather than reading as zero."
  :type '(repeat string)
  :group 'org-queue)

(defconst org-queue--state-log-re
  (concat "^[ \t]*- State[ \t]+\"\\([^\"]+\\)\""
          "[ \t]+from[ \t]*\\(?:\"[^\"]*\"\\)?[ \t]*"
          "\\(\\[[^]]+\\]\\)")
  "Matches an Org state-change log line, capturing the NEW state and its stamp.
The `from' state is matched but deliberately not captured; see above.")

(defun org-queue-state-log (&optional pom)
  "Return the state transitions of the entry at POM, oldest first.

Each element is a cons (STATE . TIME), TIME an Emacs time value.  Only
the entry's own drawer is read, never its children's.

Sorted rather than assumed: Org writes newest-first by default, but
`org-log-states-order-reversed' can flip that, and a hand-edited drawer
can be in any order at all."
  (org-with-point-at (or pom (point))
    (save-restriction
      (widen)
      (org-back-to-heading t)
      (let ((end (save-excursion (outline-next-heading) (point)))
            entries)
        (while (re-search-forward org-queue--state-log-re end t)
          ;; Both groups must be read BEFORE parsing the stamp:
          ;; `org-time-string-to-time' runs its own regexps and so resets
          ;; the match data, after which (match-string 1) is whatever it
          ;; last matched rather than the state.
          (let ((state (match-string 1))
                (stamp (match-string 2)))
            (when-let* ((time (ignore-errors (org-time-string-to-time stamp))))
              (push (cons state time) entries))))
        (sort entries (lambda (a b) (time-less-p (cdr a) (cdr b))))))))

(defun org-queue-state-intervals (&optional pom now)
  "Return the intervals the entry at POM spent in each state.

Each element is a plist:

  :state    the state held during the interval
  :start    when it was entered
  :end      when it was left, or NOW for an interval still open
  :minutes  its length, rounded down
  :open     non-nil if the entry is still in this state

An interval's state comes from the transition that OPENS it and its end
from the next transition, so a drawer of N transitions yields N
intervals -- the last one open, running to NOW.  Callers that only want
finished work should filter on `:open'.

This is the primitive a clock table or a gantt chart wants: every row is
a bar."
  (let* ((log (org-queue-state-log pom))
         (now (or now (current-time))))
    (cl-loop for (entry . rest) on log
             collect (let* ((start (cdr entry))
                            (end (if rest (cdr (car rest)) now)))
                       (list :state (car entry)
                             :start start
                             :end end
                             :minutes (max 0 (floor (/ (float-time
                                                        (time-subtract end start))
                                                       60)))
                             :open (null rest))))))

(defcustom org-queue-max-interval-minutes 480
  "Longest a single working interval may count as, in minutes.

An interval is wall-clock: a task moved to PROG on Monday afternoon and
to DONE on Wednesday morning measures 47 hours, because nothing marked
the evenings.  That is the right answer for a gantt chart and the wrong
one for \"how long did this take\", so the measurement -- and only the
measurement -- is capped here.  `org-queue-state-intervals' stays raw.

Set to nil to measure uncapped."
  :type '(choice (const :tag "No cap" nil) integer)
  :group 'org-queue)

(defun org-queue-state-minutes (&optional states pom now)
  "Return minutes the entry at POM spent in STATES.

STATES defaults to `org-queue-working-states'.  Each interval is capped
at `org-queue-max-interval-minutes' before summing; see that variable
for why."
  (let ((states (or states org-queue-working-states)))
    (cl-loop for interval in (org-queue-state-intervals pom now)
             when (member (plist-get interval :state) states)
             sum (let ((minutes (plist-get interval :minutes)))
                   (if org-queue-max-interval-minutes
                       (min minutes org-queue-max-interval-minutes)
                     minutes)))))

(defun org-queue-harvest--clock-lines ()
  "Return minutes of CLOCK lines on the current entry itself.

Legacy only: this kb has 49 such lines from before it stopped clocking,
and `org-queue-harvest--clocked' falls back to them when an entry has no
state transitions to measure instead.

Deliberately not `org-clock-sum-current-item', which sums the whole
subtree: for calibration a parent must not be credited with the hours
its children logged, or every estimate above a subtree looks wildly
under."
  (save-excursion
    (save-restriction
      (widen)
      (org-back-to-heading t)
      (let ((end (save-excursion (outline-next-heading) (point)))
            (total 0))
        (forward-line)
        (while (re-search-forward
                "^[ \t]*CLOCK:.*=>[ \t]*\\([0-9]+\\):\\([0-9]+\\)" end t)
          (setq total (+ total
                         (* 60 (string-to-number (match-string 1)))
                         (string-to-number (match-string 2)))))
        total))))

(defun org-queue-harvest--clocked ()
  "Return minutes worked on the current entry itself.

State transitions first, CLOCK lines only when there are none.  The two
are never added: an entry that was both clocked and state-tracked would
otherwise count the same work twice, and every estimate above it would
calibrate as half as long as it really was."
  (let ((worked (org-queue-state-minutes)))
    (if (> worked 0) worked (org-queue-harvest--clock-lines))))

(defun org-queue-harvest--absolute-to-date (absolute)
  "Return calendar day number ABSOLUTE as a YYYYMMDD integer."
  (let ((gregorian (calendar-gregorian-from-absolute absolute)))
    (+ (* 10000 (nth 2 gregorian))
       (* 100 (nth 0 gregorian))
       (nth 1 gregorian))))

(defun org-queue-harvest--date-to-absolute (date)
  "Return DATE, a YYYYMMDD integer, as a calendar day number."
  (calendar-absolute-from-gregorian
   (list (% (/ date 100) 100) (% date 100) (/ date 10000))))

(defun org-queue-harvest--timestamps (today)
  "Return (NEXT . PAST) for the current entry's plain active timestamps.

NEXT is the first occurrence on or after TODAY, PAST the last one before
it, both YYYYMMDD or nil.  Repeaters are rolled forward, so a weekly 1:1
stamped three weeks ago reports the occurrence that actually falls in
this week.

Only plain timestamps count: SCHEDULED, DEADLINE, CLOSED and CLOCK lines
are read elsewhere, and everything in a properties or logbook drawer is
an inactive stamp, which this regexp does not match."
  (save-excursion
    (save-restriction
      (widen)
      (org-back-to-heading t)
      (let ((end (save-excursion (outline-next-heading) (point)))
            (daynr (org-queue-harvest--date-to-absolute today))
            next past)
        (while (re-search-forward org-ts-regexp end t)
          (let ((raw (match-string 0)))
            (unless (save-excursion
                      (goto-char (line-beginning-position))
                      (looking-at-p
                       "[ \t]*\\(SCHEDULED\\|DEADLINE\\|CLOSED\\|CLOCK\\):"))
              (when-let* ((absolute (ignore-errors
                                      (org-time-string-to-absolute
                                       raw daynr 'future)))
                          (date (org-queue-harvest--absolute-to-date absolute)))
                (if (>= date today)
                    (setq next (if next (min next date) date))
                  (setq past (if past (max past date) date)))))))
        (cons next past)))))

(defun org-queue-harvest--blocked-by ()
  "Return the IDs listed in the current entry's BLOCKED_BY property."
  (when-let* ((raw (org-entry-get (point) "BLOCKED_BY")))
    (split-string raw "[ ,]+" t)))

(defun org-queue-harvest--impact ()
  "Return the entry's IMPACT as an integer, or nil when unset.

Out-of-range or non-numeric values are treated as unset rather than
clamped: a typo should behave like no answer, not like a strong one."
  (when-let* ((raw (org-entry-get (point) "IMPACT")))
    (let ((n (string-to-number raw)))
      (when (and (> n 0) (<= n 5) (= n (truncate n)))
        (truncate n)))))

(defun org-queue-harvest--soft-deadline-p ()
  "Return non-nil when the entry's deadline is declared soft.
Anything other than the literal \"soft\" -- including an absent property --
means hard, so the strict reading is the default."
  (equal (org-entry-get (point) "DEADLINE_TYPE") "soft"))

(defun org-queue-harvest--waiting-on ()
  "Return who the entry is waiting on, or nil.
Free text on purpose: this is a person, and a controlled vocabulary of
people is a worse problem than a typo."
  (when-let* ((raw (org-entry-get (point) "WAITING_ON")))
    (let ((trimmed (string-trim raw)))
      (unless (string-empty-p trimmed) trimmed))))

(defconst org-queue-harvest--weekdays
  '(("sun" . 0) ("mon" . 1) ("tue" . 2) ("wed" . 3) ("thu" . 4) ("fri" . 5) ("sat" . 6))
  "Weekday names as HABIT_DAYS writes them, to day-of-week numbers.")

(defun org-queue-harvest--habit-days ()
  "Return HABIT_DAYS as a list of weekday numbers, or nil for every day."
  (when-let* ((days (org-entry-get (point) "HABIT_DAYS")))
    (delq nil (mapcar (lambda (word)
                        (alist-get (downcase (substring word 0 (min 3 (length word))))
                                   org-queue-harvest--weekdays nil nil #'equal))
                      (split-string days)))))

(defun org-queue-harvest--habit-p ()
  "Return non-nil if the entry at point is a habit (STYLE habit)."
  (equal (org-entry-get (point) "STYLE") "habit"))

(defun org-queue-harvest--placed ()
  "Return the date a machine placement wrote this entry's SCHEDULED, or nil."
  (org-queue-harvest--timestamp-date (org-entry-get (point) "PLACED")))

(defun org-queue-harvest--review-on ()
  "Return the entry's REVIEW_ON date as a YYYYMMDD integer, or nil."
  (org-queue-harvest--timestamp-date (org-entry-get (point) "REVIEW_ON")))

(defun org-queue-harvest--closed ()
  "Return the entry's CLOSED stamp as a YYYYMMDD integer, or nil."
  (org-queue-harvest--timestamp-date (org-entry-get (point) "CLOSED")))

(defun org-queue-harvest--last-transition ()
  "Return (STATE . DATE) of the entry's newest state change, or nil."
  (when-let* ((last (car (last (org-queue-state-log)))))
    (cons (car last) (org-queue-harvest--date (cdr last)))))

(defun org-queue-harvest--interrupted ()
  "Return the ID of the entry a capture interrupted, from INTERRUPTED."
  (when-let* ((raw (org-entry-get (point) "INTERRUPTED")))
    (let ((trimmed (string-trim raw)))
      (unless (string-empty-p trimmed) trimmed))))

(defcustom org-queue-dormant-tag "dormant"
  "Tag the project check writes on a parent with no next step.
Read by the harvest as `:dormant-parent' on the children."
  :type 'string
  :group 'org-queue)

(defun org-queue-harvest--dormant-parent-p ()
  "Return non-nil if an ancestor of the entry carries the dormant tag."
  (save-excursion
    (let (found)
      (while (and (not found) (org-up-heading-safe))
        (when (member org-queue-dormant-tag (org-get-tags nil t))
          (setq found t)))
      found)))

(defun org-queue-harvest-entry (&optional today)
  "Return the Org entry at point as a queue task plist.
TODAY, a YYYYMMDD integer, anchors repeating timestamps."
  (let ((components (org-heading-components))
        (stamps (org-queue-harvest--timestamps
                 (or today (org-queue-core-today)))))
    (list :id (org-id-get)
          :file (buffer-file-name (buffer-base-buffer))
          :point (point)
          :category (org-get-category)
          :title (org-get-heading t t t t)
          :state (nth 2 components)
          ;; `org-entry-get' answers "B" for an entry with no cookie at
          ;; all, which is exactly the distinction the scorer needs to
          ;; keep; the heading components report nil.
          :priority (nth 3 components)
          :scheduled (org-queue-harvest--date (org-get-scheduled-time (point)))
          :deadline (org-queue-harvest--date (org-get-deadline-time (point)))
          :effort (org-queue-harvest--effort)
          :created (org-queue-harvest--timestamp-date
                    (org-entry-get (point) "CREATED"))
          :tags (org-get-tags)
          :clocked (org-queue-harvest--clocked)
          :blocked-by (org-queue-harvest--blocked-by)
          :impact (org-queue-harvest--impact)
          :deadline-soft (org-queue-harvest--soft-deadline-p)
          :waiting-on (org-queue-harvest--waiting-on)
          :review-on (org-queue-harvest--review-on)
          :habit (org-queue-harvest--habit-p)
          :habit-days (org-queue-harvest--habit-days)
          :placed (org-queue-harvest--placed)
          :closed (org-queue-harvest--closed)
          :last-transition (org-queue-harvest--last-transition)
          :interrupted (org-queue-harvest--interrupted)
          :dormant-parent (org-queue-harvest--dormant-parent-p)
          :timestamp (car stamps)
          :timestamp-past (cdr stamps))))


;;;; Finding an entry again

(defun org-queue-harvest-locate (task)
  "Return (BUFFER . POSITION) of TASK's heading, or signal a user error.

The recorded position is only as fresh as the last harvest, so the
heading there is checked against the title and the ID is the fallback
-- it survives any amount of editing."
  (let* ((file (plist-get task :file))
         (position (plist-get task :point))
         (id (plist-get task :id))
         (buffer (and file (find-file-noselect file))))
    (unless buffer (user-error "No file recorded for this task"))
    (with-current-buffer buffer
      (save-restriction
        (widen)
        (let ((found (and position
                          (save-excursion
                            (goto-char (min position (point-max)))
                            (and (ignore-errors (org-back-to-heading t))
                                 (equal (org-get-heading t t t t)
                                        (plist-get task :title))
                                 (point))))))
          (setq position
                (or found
                    (when id
                      (when-let* ((marker (org-id-find id t)))
                        (and (eq (marker-buffer marker) buffer)
                             (marker-position marker))))
                    position))
          (unless position (user-error "Cannot find %s" (plist-get task :title)))
          (cons buffer position))))))


;;;; Reading the corpus

(defun org-queue-harvest-files ()
  "Return the list of files to harvest."
  (or org-queue-files (org-agenda-files)))

(defun org-queue-harvest (&optional files today)
  "Harvest FILES into a list of task plists.

FILES defaults to `org-queue-harvest-files'.  Tasks that were on a
previous day's plan and are still open are marked `:carried', so the
queue stops re-litigating the same decision every morning."
  (let* ((files (or files (org-queue-harvest-files)))
         (today (or today (org-queue-core-today)))
         (carried (org-queue-carried-ids today))
         (tasks (org-ql-select files org-queue-harvest-query
                  :action (lambda () (org-queue-harvest-entry today)))))
    (mapcar (lambda (task)
              (if (and (plist-get task :id)
                       (member (plist-get task :id) carried))
                  (plist-put task :carried t)
                task))
            tasks)))


;;;; Plan history, for carry-over

(defun org-queue-history ()
  "Return the recorded plans, newest first."
  (when (file-readable-p org-queue-history-file)
    (with-temp-buffer
      (insert-file-contents org-queue-history-file)
      (ignore-errors (read (current-buffer))))))

(defun org-queue-record-plan (plan)
  "Record the IDs PLAN planned, for tomorrow's carry-over detection."
  (let* ((date (plist-get plan :date))
         (ids (delq nil (mapcar (lambda (task) (plist-get task :id))
                                (plist-get plan :planned))))
         (history (cl-remove date (org-queue-history)
                             :key (lambda (entry) (plist-get entry :date))))
         (updated (cons (list :date date :ids ids)
                        (cl-subseq history
                                   0 (min (length history)
                                          (1- org-queue-history-length))))))
    (make-directory (file-name-directory org-queue-history-file) t)
    (with-temp-file org-queue-history-file
      (let ((print-length nil) (print-level nil))
        (prin1 updated (current-buffer))
        (insert "\n")))
    updated))

(defun org-queue-carried-ids (today)
  "Return IDs planned on the most recent day before TODAY."
  (when-let* ((previous (cl-find-if (lambda (entry)
                                      (< (plist-get entry :date) today))
                                    (org-queue-history))))
    (plist-get previous :ids)))

(provide 'org-queue-harvest)
;;; org-queue-harvest.el ends here
