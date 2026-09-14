;;; org-queue-review-core.el --- The weekly review pack and "still worth it?", arithmetic only -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Two readers over the same evidence, no Org in either:
;;
;; The PACK is a pure function of (corpus, today, config).  It assembles,
;; in a fixed order so two packs diff readably: what moved, what
;; finished, the open work by how long since anything happened to it,
;; the chase list by person and age, parked items whose review date has
;; arrived, the untriaged, the inbox and its ages, dormant projects, the
;; "still worth it?" candidates, calibration (only with enough evidence),
;; the week's minutes by category against the routine's template, the
;; ROTTEN count, and the chains' week when there is one.  Every open item
;; lands in exactly one stalled bucket.
;;
;; "STILL WORTH IT?" is the evidence for one parked item -- age, times
;; carried, times surfaced, days since touch -- and the rule that turns
;; it into a proposal: surfaced `org-queue-dismiss-after' times without
;; a pull, and never dismissed before.  The proposal carries its evidence
;; and Forster's four questions.  Nothing here dismisses anything.

;;; Code:

(require 'cl-lib)
(require 'org-queue-core)
(require 'org-queue-close-core)

(defcustom org-queue-review-window 7
  "Days the pack looks back over."
  :type 'integer
  :group 'org-queue)

(defcustom org-queue-dismiss-after 3
  "Surfacings without a pull after which the pack proposes dismissal.
Proposed, never automatic (Part 6 question 7 of composite.org)."
  :type 'integer
  :group 'org-queue)

(defcustom org-queue-chase-days 7
  "Days a WAIT or QUES may sit untouched before it is listed to chase."
  :type 'integer
  :group 'org-queue)

(defcustom org-queue-season-days 90
  "Days a parked item is put away for; a season."
  :type 'integer
  :group 'org-queue)

(defconst org-queue-review-questions
  '("What did I do that was worth doing?"
    "What would I do differently?"
    "Did I do what I intended?")
  "The questions at the top of the pack: Meier's two and Eyal's one.")

(defconst org-queue-review-forster-questions
  '("Do I want it in my life?"
    "Does it belong in the next few weeks?"
    "Is there a smaller version I would do?"
    "Would I be relieved if it disappeared?")
  "The four questions attached to a dismissal proposal.")


;;;; Evidence for one item

(defun org-queue-review-core-evidence (task history today)
  "Return the evidence tuple for TASK as a plist.

  :age        days since CREATED, or nil
  :carried    plans in HISTORY that held it
  :surfaced   the SURFACED counter
  :touched    days since the newest stamp anywhere in it, or nil
  :kept       the KEPT stamp's date, or nil
  :dismissed  the DISMISSED stamp's date, or nil
  :rotten     reschedules"
  (list :age (and (plist-get task :created)
                  (max 0 (org-queue-core-days-between (plist-get task :created) today)))
        :carried (if (plist-get task :id)
                     (org-queue-close-core-carried-count (plist-get task :id) history today)
                   0)
        :surfaced (or (plist-get task :surfaced) 0)
        :touched (and (plist-get task :touched)
                      (max 0 (org-queue-core-days-between (plist-get task :touched) today)))
        :kept (plist-get task :kept)
        :dismissed (plist-get task :dismissed)
        :rotten (or (plist-get task :rotten) 0)))

(defun org-queue-review-core-parked-p (task)
  "Return non-nil if TASK is parked: HOLD or IDEA."
  (member (plist-get task :state) org-queue-excluded-states))

(defun org-queue-review-core-proposals (tasks history today &optional threshold)
  "Return the tasks proposed for dismissal, each annotated with its evidence.

A task is proposed when it has surfaced THRESHOLD times (default
`org-queue-dismiss-after') without being pulled -- a KEPT stamp resets
the count, so it is the counter that says -- and has never been
dismissed.  Finished tasks and habits are never proposed."
  (let ((threshold (or threshold org-queue-dismiss-after))
        proposals)
    (dolist (task tasks)
      (unless (or (org-queue-core-done-p task) (org-queue-core-habit-p task))
        (let ((evidence (org-queue-review-core-evidence task history today)))
          (when (and (>= (plist-get evidence :surfaced) threshold)
                     (null (plist-get evidence :dismissed)))
            (push (org-queue-core--annotate
                   task :evidence evidence
                   :questions org-queue-review-forster-questions)
                  proposals)))))
    (nreverse proposals)))

(defun org-queue-review-core-came-back-p (task tasks)
  "Return the older task TASK duplicates, if a done or dismissed one shares its title.
Basecamp's event: it came back."
  (let ((title (downcase (string-trim (or (plist-get task :title) "")))))
    (cl-find-if (lambda (other)
                  (and (not (eq other task))
                       (equal title (downcase (string-trim (or (plist-get other :title) ""))))
                       (or (org-queue-core-done-p other) (plist-get other :dismissed))
                       (or (null (plist-get task :created))
                           (null (plist-get other :created))
                           (< (plist-get other :created) (plist-get task :created)))))
                tasks)))


;;;; The stalled buckets

(defconst org-queue-review-stalled-buckets
  '((week    . "touched this week")
    (month   . "touched this month")
    (quarter . "quiet for one to three months")
    (longer  . "quiet for over three months")
    (never   . "no timestamp at all"))
  "The five partitions of the open work by last touch, in order.")

(defun org-queue-review-core-stalled-bucket (task today)
  "Return the stalled bucket TASK falls in on TODAY."
  (let ((touched (plist-get task :touched)))
    (if (null touched)
        'never
      (let ((days (org-queue-core-days-between touched today)))
        (cond ((<= days 7) 'week)
              ((<= days 30) 'month)
              ((<= days 90) 'quarter)
              (t 'longer))))))


;;;; The pack

(defun org-queue-review-core--in-window-p (date today window)
  "Return non-nil if DATE is within WINDOW days before TODAY, inclusive."
  (and date (<= (org-queue-core-days-between date today) window)
       (<= date today)))

(defun org-queue-review-core-template-rows (expected actual)
  "Compare ACTUAL minutes per bucket with EXPECTED, both alists.
Returns rows (:bucket :expected :actual :ratio :verdict), the verdict
`under' below half, `over' above one and a half, else `on'."
  (mapcar (lambda (cell)
            (let* ((name (car cell))
                   (expected (cdr cell))
                   (actual (or (alist-get name actual) 0))
                   (ratio (and (> expected 0) (/ (float actual) expected))))
              (list :bucket name :expected expected :actual actual :ratio ratio
                    :verdict (cond ((null ratio) 'none)
                                   ((< ratio 0.5) 'under)
                                   ((> ratio 1.5) 'over)
                                   (t 'on)))))
          expected))

(defun org-queue-review-core-floor-rows (floors minutes)
  "Compare MINUTES per category with FLOORS: alist of (CATEGORY MIN . MAX) hours a week.
Returns rows (:category :minutes :min :max :verdict) with the verdict
`below', `above' or `within'."
  (mapcar (lambda (cell)
            (let* ((category (car cell))
                   (minimum (car (cdr cell)))
                   (maximum (cdr (cdr cell)))
                   (worked (or (alist-get category minutes 0 nil #'equal) 0)))
              (list :category category :minutes worked
                    :min minimum :max maximum
                    :verdict (cond ((and minimum (< worked (* 60 minimum))) 'below)
                                   ((and maximum (> worked (* 60 maximum))) 'above)
                                   (t 'within)))))
          floors))

(cl-defun org-queue-review-core (tasks today &key history window inbox-ages
                                       dormant calibration time-by-category
                                       time-by-bucket expected-by-bucket floors
                                       chains)
  "Assemble the review pack for the WINDOW days ending on TODAY.

TASKS is the harvest; HISTORY the plan history; INBOX-AGES a list of
days-old per inbox entry; DORMANT the project list from the check;
CALIBRATION the report rows from `org-queue-core-calibration-report';
TIME-BY-CATEGORY and TIME-BY-BUCKET alists of worked minutes in the
window; EXPECTED-BY-BUCKET the routine's minutes per bucket over the
window; FLOORS the areas' (CATEGORY MIN . MAX) hours; CHAINS the
chains' week, drawn as given.

Returns a plist whose sections are always present, empty or not, in
this order: :moved :finished :stalled :chase :parked-due :untriaged
:inbox :dormant :worth :calibration :time :template :floors :rotten
:chains."
  (let* ((window (or window org-queue-review-window))
         (open (cl-remove-if (lambda (task) (or (org-queue-core-done-p task)
                                                (org-queue-core-habit-p task)))
                             tasks))
         (moved (cl-remove-if-not
                 (lambda (task)
                   (cl-some (lambda (transition)
                              (org-queue-review-core--in-window-p (cdr transition) today window))
                            (plist-get task :transitions)))
                 tasks))
         (finished (cl-remove-if-not
                    (lambda (task)
                      (and (org-queue-core-done-p task)
                           (or (org-queue-review-core--in-window-p (plist-get task :closed) today window)
                               (let ((last (plist-get task :last-transition)))
                                 (and last (member (car last) org-queue-done-states)
                                      (org-queue-review-core--in-window-p (cdr last) today window))))))
                    tasks))
         (stalled (mapcar (lambda (bucket)
                            (cons (car bucket)
                                  (cl-remove-if-not
                                   (lambda (task)
                                     (and (not (org-queue-review-core-parked-p task))
                                          (eq (car bucket)
                                              (org-queue-review-core-stalled-bucket task today))))
                                   open)))
                          org-queue-review-stalled-buckets))
         (chase (cl-remove-if-not
                 (lambda (task)
                   (and (member (plist-get task :state) '("WAIT" "QUES"))
                        (let ((touched (plist-get task :touched)))
                          (or (null touched)
                              (> (org-queue-core-days-between touched today)
                                 org-queue-chase-days)))))
                 open))
         (parked-due (cl-remove-if-not
                      (lambda (task)
                        (and (org-queue-review-core-parked-p task)
                             (plist-get task :review-on)
                             (<= (plist-get task :review-on) today)
                             ;; Raised once: a KEPT on or after the review
                             ;; date means it was already looked at.
                             (not (and (plist-get task :kept)
                                       (>= (plist-get task :kept) (plist-get task :review-on))))))
                      open))
         (untriaged (cl-remove-if-not
                     (lambda (task)
                       (and (not (org-queue-review-core-parked-p task))
                            (or (null (plist-get task :effort))
                                (null (plist-get task :priority))
                                (and (null (plist-get task :scheduled))
                                     (null (plist-get task :deadline))
                                     (null (plist-get task :timestamp))))))
                     open))
         (worth (org-queue-review-core-proposals tasks history today))
         (rotten (cl-remove-if-not (lambda (task) (> (or (plist-get task :rotten) 0) 0)) open)))
    (list :date today
          :window window
          :questions org-queue-review-questions
          :moved moved
          :finished finished
          :stalled stalled
          :chase (sort (copy-sequence chase)
                       (lambda (a b) (string< (or (plist-get a :waiting-on) "~")
                                              (or (plist-get b :waiting-on) "~"))))
          :parked-due parked-due
          :untriaged untriaged
          :inbox (list :count (length inbox-ages)
                       :ages (list :week (cl-count-if (lambda (d) (<= d 7)) inbox-ages)
                                   :month (cl-count-if (lambda (d) (and (> d 7) (<= d 30))) inbox-ages)
                                   :older (cl-count-if (lambda (d) (> d 30)) inbox-ages)))
          :dormant (cl-remove-if-not (lambda (p) (eq (plist-get p :status) 'dormant)) dormant)
          :finished-projects (cl-remove-if-not (lambda (p) (eq (plist-get p :status) 'finished)) dormant)
          :worth worth
          :calibration (when (and calibration
                                  (>= (length finished) org-queue-calibration-prior))
                         calibration)
          :time time-by-category
          :template (and expected-by-bucket
                         (org-queue-review-core-template-rows expected-by-bucket time-by-bucket))
          :floors (and floors (org-queue-review-core-floor-rows floors time-by-category))
          :rotten (list :count (cl-reduce #'+ (mapcar (lambda (task) (plist-get task :rotten)) rotten)
                                          :initial-value 0)
                        :tasks (sort (copy-sequence rotten)
                                     (lambda (a b) (> (plist-get a :rotten) (plist-get b :rotten)))))
          :chains chains)))

(defun org-queue-review-core-summary (pack)
  "Return one line summarising PACK."
  (format "%d moved, %d finished, %d to chase, %d parked due, %d untriaged, %d in the inbox, %d dormant, %d still worth it?"
          (length (plist-get pack :moved))
          (length (plist-get pack :finished))
          (length (plist-get pack :chase))
          (length (plist-get pack :parked-due))
          (length (plist-get pack :untriaged))
          (plist-get (plist-get pack :inbox) :count)
          (length (plist-get pack :dormant))
          (length (plist-get pack :worth))))

(provide 'org-queue-review-core)
;;; org-queue-review-core.el ends here
