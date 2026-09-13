;;; org-queue.el --- Fill a day from the Org backlog -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (org-ql "0.8"))
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; `org-queue-today' harvests the agenda files, packs a day out of them,
;; and shows the result -- including what did not make it and why.
;;
;; The report is the point.  A planner you cannot interrogate gets
;; distrusted and abandoned about a week in, so every task the harvest
;; found is accounted for on screen: planned, cut for a stated reason, or
;; excluded by a rule you can name.  Press TAB to see the ones that lost.
;;
;;   RET   jump to the task            g    replan
;;   o     show it in another window   c    calibration report
;;   TAB   what was cut, and why       q    bury
;;
;; Five keys write to the entry under point -- the only writes this
;; buffer makes, each one a decision you took on one line:
;;
;;   S  schedule it today       L  schedule it later (asks for the day)
;;   N  mark it NEXT            H  hold it, with a note
;;   U  unschedule it
;;
;; Each line shows minutes, category, the TODO state and the title.  The
;; rest of the metadata is a keypress away, one column per key, so the
;; default stays readable and the full picture is there when you argue
;; with a decision:
;;
;;   s state   # priority   e estimate   i impact   d dates
;;   w age     k clocked    t tags       f file     a all / none
;;
;; The arithmetic all lives in `org-queue-core', which has no Org in it;
;; this file only asks the questions and draws the answers.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-queue-core)
(require 'org-queue-harvest)
(require 'org-queue-apply)

(defcustom org-queue-buffer-name "*org-queue*"
  "Name of the buffer the day's plan is drawn in."
  :type 'string
  :group 'org-queue)

(defcustom org-queue-show-details nil
  "When non-nil, open the plan with the cut and excluded work expanded."
  :type 'boolean
  :group 'org-queue)

(defcustom org-queue-columns '(state)
  "Metadata columns shown on each task line.

A set, not a sequence: columns are drawn in the order of
`org-queue--column-specs' whatever order they are named here.  Toggling
a column in the plan buffer updates this variable too, so the choice
carries to the next plan in the session.  The state is on by default
because it is the one field that changes what the planner does with a
task; everything else is evidence for a decision you are questioning."
  :type '(set (const state) (const priority) (const estimate)
              (const impact) (const dates) (const age)
              (const clocked) (const tags) (const file))
  :group 'org-queue)


;;;; Faces
;;
;; Prominence, not hue: the plan is a ladder from the day itself (bold)
;; down through its supporting numbers (shadow) to the work that lost
;; (shadow, smaller weight).  Nothing here encodes meaning in colour, so
;; a theme can restyle all of it by moving the rungs.

(defface org-queue-header '((t :inherit bold))
  "Face for the plan's date line."
  :group 'org-queue)

(defface org-queue-section '((t :inherit (bold shadow)))
  "Face for section headings within the plan."
  :group 'org-queue)

(defface org-queue-detail '((t :inherit shadow))
  "Face for supporting numbers: minutes, categories, scores."
  :group 'org-queue)

(defface org-queue-guess '((t :inherit (italic shadow)))
  "Face for figures the planner made up, such as a default effort."
  :group 'org-queue)

(defface org-queue-alarm '((t :inherit bold :underline t))
  "Face for the overcommitment banner.

Underlined bold rather than red: the day being too full is the loudest
thing on the page, and it should read that way in any theme."
  :group 'org-queue)


;;;; State

(defvar-local org-queue--plan nil
  "The plan currently drawn in this buffer.")

(defvar-local org-queue--details nil
  "Whether the cut and excluded sections are expanded.")

(defvar-local org-queue--columns nil
  "The metadata columns drawn in this buffer; see `org-queue-columns'.")


;;;; Formatting

(defun org-queue--date-string (date)
  "Return DATE, a YYYYMMDD integer, as a readable date."
  (format-time-string
   "%A %-d %B %Y"
   (encode-time 0 0 12 (% date 100) (% (/ date 100) 100) (/ date 10000))))

(defconst org-queue--reason-labels
  '((committed      . "committed")
    (scored         . "chosen")
    (pulled-forward . "pulled forward")
    (no-room        . "no room left in the day")
    (wip-limit      . "would exceed the work-in-progress limit")
    (overcommitted  . "the day is already overcommitted")
    (done           . "finished")
    (state          . "not a commitment (HOLD or IDEA)")
    (blocked        . "blocked by unfinished work")
    (waiting        . "waiting, with no deadline in sight")
    (event-later    . "an appointment on a later day")
    (event-past     . "an appointment that has already happened")
    (habit          . "a habit: reserved, not planned")
    (dormant-project . "its project has no next step (dormant)")
    (in-flight      . "an agent has it")
    (bucket-closed  . "its bucket has no minutes today"))
  "Human wording for the reasons a task ends up where it does.")

(defun org-queue--reason-label (reason)
  (or (alist-get reason org-queue--reason-labels) (format "%s" reason)))

(defun org-queue--insert (string &optional face)
  (insert (if face (propertize string 'face face) string)))

;;;; Columns
;;
;; Fixed-width columns sit between the category and the title, so the
;; titles stay aligned however many are on.  Variable-width ones (tags,
;; file) trail the line after the note, where ragged edges cost nothing.

(defalias 'org-queue--iso #'org-queue-core-iso)

(defun org-queue--column-state (task)
  (or (plist-get task :state) ""))

(defun org-queue--column-priority (task)
  (if-let* ((priority (plist-get task :priority)))
      (format "#%c" priority)
    ""))

(defun org-queue--column-estimate (task)
  "The entry's own estimate, before calibration; a ? when it has none."
  (if-let* ((effort (plist-get task :effort)))
      (org-queue-core-format-minutes effort)
    "?"))

(defun org-queue--column-impact (task)
  (if-let* ((impact (plist-get task :impact))) (format "i%s" impact) ""))

(defun org-queue--column-dates (task)
  "SCHEDULED, DEADLINE and start-by as S, D and by; a soft deadline is ~."
  (string-join
   (delq nil
         (list (when-let* ((s (plist-get task :scheduled)))
                 (concat "S " (org-queue--iso s)
                         (if (plist-get task :placed) "*" "")))
               (when-let* ((d (plist-get task :deadline)))
                 (concat "D " (org-queue--iso d)
                         (if (plist-get task :deadline-soft) "~" "")))
               (when-let* ((b (plist-get task :start-by)))
                 (concat "by " (org-queue--iso b)))))
   " "))

(defun org-queue--column-bucket (task)
  (format "%s" (or (plist-get task :queue-bucket) (org-queue-core-bucket task))))

(defun org-queue--column-age (task)
  "Days since CREATED, against the plan's date."
  (if-let* ((created (plist-get task :created))
            (today (plist-get org-queue--plan :date)))
      (format "%dd" (org-queue-core-days-between created today))
    ""))

(defun org-queue--column-clocked (task)
  "Minutes the derived clock has measured on the task so far."
  (let ((minutes (plist-get task :clocked)))
    (if (and minutes (> minutes 0))
        (org-queue-core-format-minutes minutes)
      "")))

(defun org-queue--column-tags (task)
  (if-let* ((tags (plist-get task :tags)))
      (concat ":" (string-join tags ":") ":")
    ""))

(defun org-queue--column-file (task)
  (if-let* ((file (plist-get task :file)))
      (file-name-nondirectory file)
    ""))

(defconst org-queue--column-specs
  ;; (COLUMN KEY WIDTH FUNCTION)  WIDTH nil = variable, drawn after the note.
  '((state    "s"  5 org-queue--column-state)
    (priority "#"  2 org-queue--column-priority)
    (estimate "e"  5 org-queue--column-estimate)
    (impact   "i"  2 org-queue--column-impact)
    (dates    "d" 40 org-queue--column-dates)
    (bucket   "B"  8 org-queue--column-bucket)
    (age      "w"  4 org-queue--column-age)
    (clocked  "k"  5 org-queue--column-clocked)
    (tags     "t" nil org-queue--column-tags)
    (file     "f" nil org-queue--column-file))
  "The columns a task line can carry, in drawing order.")

(defun org-queue--active-columns (&optional fixed)
  "Return the specs of the columns on in this buffer.
With FIXED, only the fixed-width ones; otherwise only the trailing ones."
  (cl-remove-if-not
   (lambda (spec)
     (and (memq (car spec) org-queue--columns)
          (if fixed (nth 2 spec) (null (nth 2 spec)))))
   org-queue--column-specs))

(defun org-queue--insert-task (task &optional note)
  "Insert one line for TASK, with an optional right-hand NOTE."
  (let ((start (point)))
    (org-queue--insert
     (format "  %6s  " (org-queue-core-format-minutes
                        (or (plist-get task :queue-minutes)
                            (org-queue-core-minutes
                             task (plist-get org-queue--plan :calibration)))))
     (if (plist-get task :queue-guessed) 'org-queue-guess 'org-queue-detail))
    (org-queue--insert (format "%-7s " (or (plist-get task :category) "-"))
                       'org-queue-detail)
    (dolist (spec (org-queue--active-columns t))
      (org-queue--insert
       (format (format "%%-%ds " (nth 2 spec)) (funcall (nth 3 spec) task))
       (if (and (eq (car spec) 'estimate) (plist-get task :queue-guessed))
           'org-queue-guess
         'org-queue-detail)))
    (insert (truncate-string-to-width (or (plist-get task :title) "") 58))
    (when note
      (org-queue--insert (format "  %s" note) 'org-queue-detail))
    (dolist (spec (org-queue--active-columns))
      (let ((text (funcall (nth 3 spec) task)))
        (unless (string-empty-p text)
          (org-queue--insert (concat "  " text) 'org-queue-detail))))
    (put-text-property start (point) 'org-queue-task task)
    (insert "\n")))

(defun org-queue--insert-legend ()
  "Insert the line that says which columns are on, and the keys."
  (org-queue--insert
   (concat
    "   columns: "
    (mapconcat
     (lambda (spec)
       (let ((on (memq (car spec) org-queue--columns)))
         (propertize (format "%s %s" (nth 1 spec) (car spec))
                     'face (if on 'org-queue-detail 'org-queue-guess))))
     org-queue--column-specs "  ")
    "  a all\n")
   'org-queue-detail))

(defun org-queue--insert-section (title tasks note-function)
  (when tasks
    (org-queue--insert (format "\n%s\n" title) 'org-queue-section)
    (dolist (task tasks)
      (org-queue--insert-task task (funcall note-function task)))))

(defun org-queue--tally (cells)
  "Summarise CELLS, an alist of (TASK . REASON), as \"reason n, reason n\"."
  (let (counts)
    (dolist (cell cells)
      (cl-incf (alist-get (cdr cell) counts 0)))
    (mapconcat (lambda (cell)
                 (format "%s %d" (org-queue--reason-label (car cell))
                         (cdr cell)))
               (nreverse counts) ", ")))


;;;; Drawing

(defvar-local org-queue--redraw-function nil
  "How to redraw this buffer after a toggle; nil means draw the plan.")

(defvar org-queue-morning-line-function nil
  "Function returning one more line for the morning report, or nil.
Set by org-chain: chains in flight, the landings expected, the review
minutes they imply.")

(defun org-queue--redraw ()
  "Redraw the current buffer with its current settings."
  (if org-queue--redraw-function
      (funcall org-queue--redraw-function)
    (org-queue--draw org-queue--plan)))

(defun org-queue--capacity-line (plan)
  "Return the line of numbers under PLAN's date."
  (let ((routine (cl-reduce #'+ (mapcar (lambda (b) (plist-get b :routine))
                                        (plist-get plan :buckets))
                            :initial-value 0)))
    (format "   %s planned of %s usable (%s capacity%s, %d%% slack)\n"
            (org-queue-core-format-minutes (plist-get plan :minutes))
            (org-queue-core-format-minutes (plist-get plan :usable))
            (org-queue-core-format-minutes (plist-get plan :capacity))
            (if (> routine 0)
                (format ", routine %s" (org-queue-core-format-minutes routine))
              "")
            (round (* 100 org-queue-slack-fraction)))))

(defun org-queue--insert-buckets (plan)
  "Insert one entry per bucket when PLAN has more than one."
  (let ((buckets (plist-get plan :buckets)))
    (when (> (length buckets) 1)
      (org-queue--insert "   ")
      (dolist (bucket buckets)
        (org-queue--insert
         (format "%s %s of %s%s   "
                 (plist-get bucket :name)
                 (org-queue-core-format-minutes (plist-get bucket :minutes))
                 (org-queue-core-format-minutes (plist-get bucket :usable))
                 (cond ((plist-get bucket :overcommitted) " OVER")
                       ((and (zerop (plist-get bucket :minutes))
                             (> (plist-get bucket :usable) 0))
                        " (unfilled)")
                       (t "")))
         (if (plist-get bucket :overcommitted) 'org-queue-alarm 'org-queue-detail)))
      (org-queue--insert "\n"))))

(defun org-queue--insert-alarm (plan)
  "Insert the overcommitment banner for PLAN, naming the buckets."
  (when (plist-get plan :overcommitted)
    (let ((over (cl-remove-if-not (lambda (b) (plist-get b :overcommitted))
                                  (plist-get plan :buckets))))
      (org-queue--insert
       (format "\nOVERCOMMITTED: %s -- nothing was planned on top.\n"
               (mapconcat (lambda (b)
                            (format "%s by %s" (plist-get b :name)
                                    (org-queue-core-format-minutes
                                     (- (plist-get b :minutes) (plist-get b :usable)))))
                          over ", "))
       'org-queue-alarm)
      (org-queue--insert
       "What you have already agreed to does not fit in the day.  That is
the finding, not a bug: move a deadline, drop a commitment, or accept
that today overflows.\n"
       'org-queue-detail))))

(defun org-queue--yesterday-line (date)
  "Say whether the day before DATE was closed, from the plan history.
R12 of the composite made visible without a nag: one line, no prompt."
  (let* ((yesterday (org-queue-core-date-add date -1))
         (entry (cl-find yesterday (org-queue-history)
                         :key (lambda (entry) (plist-get entry :date)))))
    (cond
     ((null entry) nil)
     ((plist-get entry :closed)
      (format "   yesterday closed at %s\n"
              (if (string-match "\\([0-9][0-9]:[0-9][0-9]\\)" (plist-get entry :closed))
                  (match-string 1 (plist-get entry :closed))
                (plist-get entry :closed))))
     (t "   yesterday was not closed\n"))))

(defun org-queue--draw (plan)
  "Draw PLAN in the current buffer."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (setq org-queue--plan plan)
    (org-queue--insert (org-queue--date-string (plist-get plan :date))
                       'org-queue-header)
    (org-queue--insert (org-queue--capacity-line plan) 'org-queue-detail)
    (when-let* ((line (org-queue--yesterday-line (plist-get plan :date))))
      (org-queue--insert line 'org-queue-detail))
    (when-let* ((line (and org-queue-morning-line-function
                           (ignore-errors (funcall org-queue-morning-line-function)))))
      (org-queue--insert (format "   %s\n" line) 'org-queue-detail))
    (org-queue--insert-buckets plan)
    (org-queue--insert-legend)
    (org-queue--draw-body plan)
    (goto-char (point-min))))

(defun org-queue--draw-body (plan)
  "Insert PLAN's sections at point: the banner, the work, the tally."
  (let ((inhibit-read-only t))
    (org-queue--insert-alarm plan)
    (let ((by-reason (lambda (reason)
                       (cl-remove-if-not
                        (lambda (task)
                          (eq reason (plist-get task :queue-reason)))
                        (plist-get plan :planned)))))
      (org-queue--insert-section
       "Routine" (plist-get plan :routine)
       (lambda (_habit) "reserved"))
      (org-queue--insert-section
       "Committed" (funcall by-reason 'committed)
       (lambda (task) (org-queue--when-note task)))
      (org-queue--insert-section
       "Chosen" (funcall by-reason 'scored)
       (lambda (task) (format "%.1f" (or (plist-get task :queue-score) 0))))
      (org-queue--insert-section
       "Pulled forward" (funcall by-reason 'pulled-forward)
       (lambda (task)
         (format "scheduled %s" (or (plist-get task :scheduled) "")))))

    (if (not org-queue--details)
        (org-queue--insert
         (format "\n%d cut, %d excluded, %d deferred.  TAB to see why.\n"
                 (length (plist-get plan :cut))
                 (length (plist-get plan :dropped))
                 (length (plist-get plan :deferred)))
         'org-queue-detail)
      (org-queue--insert-section
       (format "Cut (%d)" (length (plist-get plan :cut)))
       (mapcar #'car (plist-get plan :cut))
       (lambda (task)
         (org-queue--reason-label
          (cdr (assq task (plist-get plan :cut))))))
      (org-queue--insert-section
       (format "Deferred (%d)" (length (plist-get plan :deferred)))
       (plist-get plan :deferred)
       (lambda (task) (format "scheduled %s" (or (plist-get task :scheduled) ""))))
      (org-queue--insert-section
       (format "Excluded (%d)" (length (plist-get plan :dropped)))
       (mapcar #'car (plist-get plan :dropped))
       (lambda (task)
         (org-queue--reason-label
          (cdr (assq task (plist-get plan :dropped)))))))

    (org-queue--insert
     (format "\n%s\n"
             (or (org-queue--tally (append (plist-get plan :cut)
                                           (plist-get plan :dropped)))
                 ""))
     'org-queue-detail)
    (when org-queue-calibrate
      (org-queue--insert
       (format "Estimates scaled by %.2fx overall; c for the breakdown.\n"
               (alist-get t (plist-get plan :calibration) 1.0))
       'org-queue-detail))))

(defun org-queue--when-note (task)
  "Return the reason TASK counts as committed today."
  (let* ((today (plist-get org-queue--plan :date))
         (scheduled (plist-get task :scheduled))
         (deadline (plist-get task :deadline))
         (start-by (plist-get task :start-by))
         (why
          (cond
           ((equal (plist-get task :state) "NEXT") "next")
           ((and (plist-get task :timestamp)
                 (= (plist-get task :timestamp) today))
            "appointment")
           ((and deadline (<= deadline today))
            (if (< deadline today)
                (format "overdue since %s" (org-queue--iso deadline))
              "due today"))
           ((and scheduled (= scheduled today))
            (if (plist-get task :placed) "placed today" "scheduled today"))
           ((and start-by (<= start-by today))
            (format "start by %s, due %s" (org-queue--iso start-by)
                    (org-queue--iso deadline)))
           (scheduled (format "scheduled %s" (org-queue--iso scheduled))))))
    (if (plist-get task :slice)
        (format "%s (slice)" (or why ""))
      why)))


;;;; Commands

(defun org-queue-plan (&optional date)
  "Return a plan for DATE, a YYYYMMDD integer defaulting to today."
  (let* ((date (or date (org-queue-core-today)))
         (tasks (org-queue-harvest nil date)))
    (org-queue-core-plan tasks date)))

;;;###autoload
(defun org-queue-today (&optional prompt)
  "Plan today from the agenda files and show the result.
With PROMPT (\\[universal-argument]), plan another day instead."
  (interactive "P")
  (let* ((date (if prompt
                   (let ((chosen (org-read-date nil t nil "Plan which day? ")))
                     (org-queue-harvest--date chosen))
                 (org-queue-core-today)))
         (plan (org-queue-plan date))
         (buffer (get-buffer-create org-queue-buffer-name)))
    (org-queue-record-plan plan)
    (with-current-buffer buffer
      (org-queue-mode)
      (setq org-queue--details org-queue-show-details)
      (setq org-queue--columns (copy-sequence org-queue-columns))
      (org-queue--draw plan))
    (pop-to-buffer buffer)
    (message "%s" (org-queue-core-summary plan))))

(defun org-queue-refresh ()
  "Replan the day this buffer shows."
  (interactive)
  (let* ((date (plist-get org-queue--plan :date))
         (plan (org-queue-plan date)))
    (org-queue-record-plan plan)
    (org-queue--draw plan)
    (message "%s" (org-queue-core-summary plan))))

(defun org-queue-toggle-details ()
  "Show or hide the work that did not make the plan."
  (interactive)
  (setq org-queue--details (not org-queue--details))
  (org-queue--redraw))

(defun org-queue-task-at-point ()
  "Return the task on the current line, or nil."
  (get-text-property (point) 'org-queue-task))

(defun org-queue--goto (task other-window)
  "Move to TASK's Org entry, in OTHER-WINDOW when non-nil."
  (let ((where (org-queue-harvest-locate task)))
    (funcall (if other-window #'pop-to-buffer #'pop-to-buffer-same-window)
             (car where))
    (widen)
    (goto-char (cdr where))
    (org-back-to-heading t)
    (org-fold-show-entry)
    (org-fold-show-children)))

(defun org-queue-goto ()
  "Jump to the task on this line."
  (interactive)
  (if-let* ((task (org-queue-task-at-point)))
      (org-queue--goto task nil)
    (user-error "No task on this line")))

(defun org-queue-display ()
  "Show the task on this line in another window."
  (interactive)
  (if-let* ((task (org-queue-task-at-point)))
      (save-selected-window (org-queue--goto task t))
    (user-error "No task on this line")))

(defun org-queue-calibration ()
  "Report how estimates compare with the clock, per category."
  (interactive)
  (let* ((tasks (org-queue-harvest))
         (report (org-queue-core-calibration-report tasks))
         (buffer (get-buffer-create "*org-queue calibration*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (special-mode)
        (org-queue--insert "Estimate versus clock, on finished work\n"
                           'org-queue-header)
        (org-queue--insert
         (format "\n%-12s %5s  %8s  %8s\n" "category" "n" "measured" "applied")
         'org-queue-section)
        (dolist (row report)
          (insert (format "%-12s %5d  %7.2fx  %7.2fx\n"
                          (if (eq (plist-get row :category) t)
                              "(all)"
                            (plist-get row :category))
                          (plist-get row :n)
                          (plist-get row :raw)
                          (plist-get row :factor))))
        (org-queue--insert
         (format "
\"measured\" is clocked minutes over estimated minutes.  \"applied\" is
that pulled toward the overall factor by %d phantom observations, so a
category with two finished tasks cannot swing the packing on its own.
Estimates are%s currently scaled by it.\n"
                 org-queue-calibration-prior
                 (if org-queue-calibrate "" " NOT"))
         'org-queue-detail)
        (goto-char (point-min))))
    (pop-to-buffer buffer)))

(defun org-queue-next ()
  "Move to the next task line."
  (interactive)
  (let ((position (next-single-property-change (point) 'org-queue-task)))
    (while (and position (not (get-text-property position 'org-queue-task)))
      (setq position (next-single-property-change position 'org-queue-task)))
    (when position (goto-char position))))

(defun org-queue-previous ()
  "Move to the previous task line."
  (interactive)
  (let ((position (previous-single-property-change (point) 'org-queue-task)))
    (while (and position (not (get-text-property position 'org-queue-task)))
      (setq position (previous-single-property-change position 'org-queue-task)))
    (when position (goto-char (line-beginning-position)))))

(defun org-queue-toggle-column (column)
  "Show or hide COLUMN on every task line, and remember the choice.
Interactively, prompt for one of `org-queue--column-specs'."
  (interactive
   (list (intern (completing-read "Column: " (mapcar #'car org-queue--column-specs)
                                  nil t))))
  (unless (assq column org-queue--column-specs)
    (user-error "No such column: %s" column))
  (setq org-queue--columns
        (if (memq column org-queue--columns)
            (delq column (copy-sequence org-queue--columns))
          (cons column org-queue--columns)))
  ;; The buffer is the place the choice is made, but the next plan should
  ;; open the same way, so the default follows the buffer.
  (setq org-queue-columns (copy-sequence org-queue--columns))
  (org-queue--redraw))

(defun org-queue-toggle-all-columns ()
  "Show every column, or, if every column is already on, only the state."
  (interactive)
  (let ((all (mapcar #'car org-queue--column-specs)))
    (setq org-queue--columns
          (if (cl-every (lambda (column) (memq column org-queue--columns)) all)
              '(state)
            all))
    (setq org-queue-columns (copy-sequence org-queue--columns))
    (org-queue--redraw)))


;;;; Writing to the entry under point

(defun org-queue--date-at-point ()
  "Return the day the line at point belongs to."
  (or (get-text-property (point) 'org-queue-date)
      (plist-get org-queue--plan :date)))

(defun org-queue--apply-here (action &optional note)
  "Apply ACTION to the task at point, then replan."
  (let ((task (or (org-queue-task-at-point)
                  (user-error "No task on this line"))))
    (org-queue-apply-actions (list (plist-put action :task task)) note)
    (org-queue-refresh)))

(defun org-queue-schedule-today ()
  "Schedule the task at point on the day this line belongs to, as a placement."
  (interactive)
  (let ((date (org-queue--date-at-point)))
    (org-queue--apply-here (list :action 'schedule :to date :placed t)
                           (format "S in the plan for %s" (org-queue--iso date)))))

(defun org-queue-schedule-later ()
  "Schedule the task at point on a day you choose, as a placement."
  (interactive)
  (let ((date (org-queue-harvest--date
               (org-read-date nil t nil "Schedule for: "))))
    (org-queue--apply-here (list :action 'schedule :to date :placed t)
                           (format "L in the plan, to %s" (org-queue--iso date)))))

(defun org-queue-mark-next ()
  "Mark the task at point NEXT: a commitment from you, not a date."
  (interactive)
  (org-queue--apply-here (list :action 'state :to "NEXT") "N in the plan"))

(defun org-queue-hold ()
  "Put the task at point on HOLD; the state asks for its note."
  (interactive)
  (org-queue--apply-here (list :action 'state :to "HOLD") "H in the plan"))

(defun org-queue-unschedule ()
  "Remove the task at point's SCHEDULED.
A schedule a person wrote is only removed after asking."
  (interactive)
  (let ((task (or (org-queue-task-at-point) (user-error "No task on this line"))))
    (unless (plist-get task :scheduled)
      (user-error "%s is not scheduled" (plist-get task :title)))
    (when (or (plist-get task :placed)
              (y-or-n-p "Not a machine placement; remove the schedule anyway? "))
      (org-queue--apply-here (list :action 'unschedule) "U in the plan"))))

(defvar-keymap org-queue-mode-map
  :doc "Keymap for `org-queue-mode'."
  "RET" #'org-queue-goto
  "o"   #'org-queue-display
  "g"   #'org-queue-refresh
  "TAB" #'org-queue-toggle-details
  "c"   #'org-queue-calibration
  "n"   #'org-queue-next
  "p"   #'org-queue-previous
  "a"   #'org-queue-toggle-all-columns
  "S"   #'org-queue-schedule-today
  "L"   #'org-queue-schedule-later
  "N"   #'org-queue-mark-next
  "H"   #'org-queue-hold
  "U"   #'org-queue-unschedule)

;; One named command per column, so `describe-mode' and which-key show
;; "org-queue-toggle-tags" rather than an anonymous lambda.
(dolist (spec org-queue--column-specs)
  (let* ((column (car spec))
         (name (intern (format "org-queue-toggle-%s" column))))
    (defalias name
      (lambda () (interactive) (org-queue-toggle-column column))
      (format "Show or hide the %s column." column))
    (keymap-set org-queue-mode-map (nth 1 spec) name)))

(define-derived-mode org-queue-mode special-mode "Queue"
  "Major mode for the day's queue.

\\{org-queue-mode-map}"
  (setq truncate-lines t)
  (setq-local cursor-type nil))

(provide 'org-queue)
;;; org-queue.el ends here
