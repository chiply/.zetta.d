;;; org-queue-horizon.el --- Plan more than one day, read-only -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The day packer, run once per day across a range, with the pool evolving
;; as it goes: a task planned on day N is gone on N+1, a task deferred to
;; day D shows up on D, and a commitment too big for its day is sliced --
;; that is where deadline backpressure actually happens.
;;
;; No Org in here.  `org-queue-core-horizon' takes task plists and returns
;; day plans plus what never fit, and is tested in batch like the core.
;; Repeating appointments are a known limit: the harvest rolls a repeater
;; forward once, to its first occurrence on or after the harvest date, so
;; a daily standup appears on one day of the range rather than every day.

;;; Code:

(require 'cl-lib)
(require 'org-queue-core)

(defcustom org-queue-horizon-max-days 90
  "Ceiling on the days a backlog run may simulate."
  :type 'integer
  :group 'org-queue)

(defun org-queue-horizon-key (task)
  "Return what identifies TASK across copies: its ID, else file and point."
  (or (plist-get task :id)
      (cons (plist-get task :file) (plist-get task :point))
      (plist-get task :title)))

(defun org-queue-horizon--remaining (task planned factors)
  "Return TASK with PLANNED calibrated minutes taken off its effort."
  (let* ((factor (org-queue-core-factor factors (plist-get task :category)))
         (raw (max 1 (round (/ planned factor))))
         (left (max 1 (- (org-queue-core-effort task) raw))))
    (org-queue-core--annotate
     task
     :effort left
     :sliced-from (or (plist-get task :sliced-from) (org-queue-core-effort task))
     :slices (1+ (or (plist-get task :slices) 0)))))

(defun org-queue-horizon--free-function (pool factors)
  "Return a free-minutes function that knows what POOL already commits.

Free minutes for a bucket on a day are its usable minutes less the
calibrated minutes of every pool task committed to that day by a date
-- scheduled, due, or an appointment.  That is what start-by should
walk back over, rather than an empty calendar."
  (let ((cache (make-hash-table :test #'equal)))
    (lambda (bucket date)
      (let* ((self (and org-queue-core-start-by-task
                        (org-queue-horizon-key org-queue-core-start-by-task)))
             (key (list bucket date self)))
        (or (gethash key cache)
            (puthash
             key
             (let* ((habits (cl-remove-if-not
                             (lambda (task)
                               (and (org-queue-core-habit-p task)
                                    (org-queue-core-habit-applies-p task date)
                                    (eq (org-queue-core-bucket task) bucket)))
                             pool))
                    (routine (cl-reduce #'+ (mapcar #'org-queue-core-effort habits)
                                        :initial-value 0))
                    (usable (max 0 (round (* (- (org-queue-core-bucket-capacity bucket date)
                                                routine)
                                             (- 1.0 org-queue-slack-fraction)))))
                    (committed
                     (cl-reduce
                      #'+
                      (mapcar (lambda (task) (org-queue-core-minutes task factors))
                              (cl-remove-if-not
                               (lambda (task)
                                 (and (not (org-queue-core-habit-p task))
                                      (not (org-queue-core-done-p task))
                                      ;; A placement the planner may move
                                      ;; is not booking the day.
                                      (not (and org-queue-core-placed-soft
                                                (plist-get task :placed)))
                                      ;; Nor is the task asking the question.
                                      (not (and self (equal (org-queue-horizon-key task) self)))
                                      (eq (org-queue-core-bucket task) bucket)
                                      (or (eql (plist-get task :scheduled) date)
                                          (eql (plist-get task :deadline) date)
                                          (eql (plist-get task :timestamp) date))))
                               pool))
                      :initial-value 0)))
               (max 0 (- usable committed)))
             cache))))))

(defun org-queue-core-horizon (tasks from to)
  "Simulate day plans for TASKS from FROM to TO, both YYYYMMDD.

Returns a plist:

  :from :to     the range
  :days         one `org-queue-core-plan' result per day, in order
  :placements   alist of (KEY . (:task TASK :days ((DATE . MINUTES) ...)
                :complete BOOL)), what was planned where
  :unplaced     tasks still eligible after the last day, with the effort
                they have left
  :missed       (TASK . MINUTES-LEFT) for hard deadlines inside the range
                that the simulation could not meet

The pool evolves: a task planned whole leaves it, a slice takes its
minutes off the task's effort, and nothing else changes -- carry-over is
not simulated because it describes the past."
  (let* ((factors (org-queue-core-calibration tasks))
         (pool (copy-sequence tasks))
         (org-queue-core-slice-commitments t)
         (org-queue-core-free-minutes-function
          (org-queue-horizon--free-function pool factors))
         (day from)
         (limit (min to (org-queue-core-date-add from (1- org-queue-horizon-max-days))))
         days placements missed)
    (while (<= day limit)
      (let ((plan (org-queue-core-plan pool day)))
        (push plan days)
        (dolist (task (plist-get plan :planned))
          (let* ((key (org-queue-horizon-key task))
                 (cell (or (assoc key placements)
                           (car (push (cons key (list :task task :days nil
                                                      :complete nil))
                                      placements))))
                 (record (cdr cell)))
            (plist-put record :days
                       (append (plist-get record :days)
                               (list (cons day (plist-get task :queue-minutes)))))
            (if (plist-get task :slice)
                (setq pool (mapcar (lambda (candidate)
                                     (if (equal (org-queue-horizon-key candidate) key)
                                         (org-queue-horizon--remaining
                                          candidate (plist-get task :queue-minutes)
                                          factors)
                                       candidate))
                                   pool))
              (plist-put record :complete t)
              (setq pool (cl-remove-if
                          (lambda (candidate)
                            (equal (org-queue-horizon-key candidate) key))
                          pool)))))
        ;; A hard deadline that passed with effort still in the pool was
        ;; not met, whatever the packer said on the day.
        (dolist (task pool)
          (when (and (eql (plist-get task :deadline) day)
                     (not (plist-get task :deadline-soft))
                     (not (org-queue-core-done-p task))
                     (not (org-queue-core-habit-p task)))
            (push (cons task (org-queue-core-minutes task factors)) missed)))
        ;; The free-minutes cache was built over the starting pool; what
        ;; is committed by date has not changed, so it stays valid.
        (setq day (org-queue-core-date-add day 1))))
    (let ((last (car days)))
      (list :from from :to limit
            :days (nreverse days)
            :placements (nreverse placements)
            :unplaced (mapcar #'car (plist-get last :cut))
            :missed (nreverse missed)))))

(defun org-queue-horizon-summary (horizon)
  "Return a one-line summary of HORIZON."
  (let ((days (plist-get horizon :days)))
    (format "%d day%s, %d task%s placed, %d unplaced, %d deadline%s missed"
            (length days) (if (= 1 (length days)) "" "s")
            (length (plist-get horizon :placements))
            (if (= 1 (length (plist-get horizon :placements))) "" "s")
            (length (plist-get horizon :unplaced))
            (length (plist-get horizon :missed))
            (if (= 1 (length (plist-get horizon :missed))) "" "s"))))

;;;; Proposals
;;
;; A proposal is the diff between a horizon and what the files already
;; say.  It places what has no date, moves what the machine placed
;; before, and never touches a date a person wrote -- those become
;; findings.  Accept everything and run again: the proposal is empty.

(defun org-queue-horizon--why (task)
  "Say in a few words why the simulation put TASK where it did."
  (let ((reason (plist-get task :queue-reason)))
    (concat
     (pcase reason
       ('committed
        (cond ((equal (plist-get task :state) "NEXT") "next")
              ((and (plist-get task :deadline)
                    (<= (plist-get task :deadline) (plist-get task :queue-date)))
               "due")
              ((plist-get task :start-by)
               (format "start by %s for %s"
                       (org-queue-core-iso (plist-get task :start-by))
                       (org-queue-core-iso (plist-get task :deadline))))
              (t "committed")))
       ('scored (format "scored %.1f" (or (plist-get task :queue-score) 0)))
       ('pulled-forward "room left, pulled forward")
       (_ (format "%s" reason)))
     (if (plist-get task :slice) ", first slice" ""))))

(defun org-queue-core-proposal (horizon tasks &optional rejected)
  "Turn HORIZON, simulated over TASKS, into actions and findings.

REJECTED is a list of (KEY . DATE) placements not to propose again.
Returns a list of plists: actions carry `:action' (schedule, move or
unschedule) with `:task', `:to', `:from', `:minutes', `:why' and
`:date'; findings carry `:finding' with `:task' and `:text'."
  (let ((from (plist-get horizon :from))
        (to (plist-get horizon :to))
        (placed-keys (mapcar #'car (plist-get horizon :placements)))
        proposal)
    ;; Placements: schedule what has no date, move what the machine placed.
    (dolist (cell (plist-get horizon :placements))
      (let* ((key (car cell))
             (record (cdr cell))
             (task (plist-get record :task))
             (first (car (plist-get record :days)))
             (day (car first))
             (total (cl-reduce #'+ (mapcar #'cdr (plist-get record :days))
                               :initial-value 0))
             (scheduled (plist-get task :scheduled))
             (placed (plist-get task :placed))
             (why (org-queue-horizon--why (org-queue-core--annotate task :queue-date day)))
             (slices (length (plist-get record :days))))
        (when (> slices 1)
          (setq why (format "%s; %d slices to %s" why slices
                            (org-queue-core-iso (car (car (last (plist-get record :days))))))))
        (unless (or (member (cons key day) rejected)
                    ;; Already fixed on that day by something a SCHEDULED
                    ;; would only repeat: an appointment, or a deadline.
                    (eql (plist-get task :timestamp) day)
                    (and (plist-get task :deadline)
                         (<= (plist-get task :deadline) day)))
          (cond
           ((and scheduled (not placed)) nil)          ; a person's date: a fact
           ((null scheduled)
            (push (list :action 'schedule :task task :to day :date day
                        :minutes total :why why)
                  proposal))
           ((/= scheduled day)
            (push (list :action 'move :task task :from scheduled :to day :date day
                        :minutes total :why why)
                  proposal))))))
    ;; Machine placements inside the range that the simulation never used.
    (dolist (task tasks)
      (when (and (plist-get task :placed)
                 (plist-get task :scheduled)
                 (<= from (plist-get task :scheduled) to)
                 (not (member (org-queue-horizon-key task) placed-keys))
                 (not (org-queue-core-done-p task)))
        (push (list :action 'unschedule :task task
                    :from (plist-get task :scheduled)
                    :date (plist-get task :scheduled)
                    :why "no longer fits where it was placed")
              proposal)))
    ;; Findings: deadlines the days cannot cover.
    (dolist (miss (plist-get horizon :missed))
      (push (list :finding 'missed :task (car miss)
                  :date (plist-get (car miss) :deadline)
                  :text (format "does not fit before %s: %s short"
                                (org-queue-core-iso (plist-get (car miss) :deadline))
                                (org-queue-core-format-minutes (cdr miss))))
            proposal))
    (nreverse proposal)))

(provide 'org-queue-horizon)
;;; org-queue-horizon.el ends here
