;;; org-queue-intake-core.el --- The intake gate: what a new deadline costs -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Before a deadline is written, the evidence: the hours already
;; committed on or before that date against the capacity in the window,
;; the commitments ahead of the candidate, and the first day the work
;; fits -- or that it does not, and by how much.  The horizon simulator
;; is the loop; this file asks it one question.  Never refuses the
;; write; the evidence is the point.

;;; Code:

(require 'cl-lib)
(require 'org-queue-core)
(require 'org-queue-horizon)

(defun org-queue-intake-core (tasks candidate deadline today)
  "Report what committing CANDIDATE to DEADLINE means, over TASKS from TODAY.

CANDIDATE is a task plist (its own deadline, if any, is replaced).
Returns a plist:

  :window       days from TODAY to DEADLINE inclusive
  :capacity     usable minutes in the window, every bucket
  :committed    calibrated minutes of TASKS already due or scheduled
                inside the window
  :ahead        how many hard deadlines fall inside the window
  :fits         non-nil when the simulation places the candidate whole
                and no hard deadline inside the window is missed that
                was met without it
  :eta          the first day the candidate is placed, or nil
  :shortfall    minutes the window cannot cover, when it does not fit
  :displaced    the tasks whose deadlines the candidate would push past:
                what would have to move
  :soft         non-nil when the candidate's deadline is soft; the gate
                has nothing to say then"
  (let* ((candidate (org-queue-core--annotate candidate :deadline deadline
                                             :id (or (plist-get candidate :id) "intake-candidate")))
         (soft (plist-get candidate :deadline-soft))
         (window (1+ (org-queue-core-days-between today deadline)))
         (pool (cons candidate (cl-remove-if
                                (lambda (task) (equal (org-queue-horizon-key task)
                                                      (org-queue-horizon-key candidate)))
                                tasks)))
         (factors (org-queue-core-calibration tasks))
         (capacity (cl-loop for i from 0 below window
                            sum (let ((day (org-queue-core-date-add today i)))
                                  (cl-reduce #'+ (mapcar (lambda (cell)
                                                           (org-queue-core-free-minutes (car cell) day))
                                                         (org-queue-core-bucket-specs))
                                             :initial-value 0))))
         (committed (cl-reduce
                     #'+ (mapcar (lambda (task) (org-queue-core-minutes task factors))
                                 (cl-remove-if-not
                                  (lambda (task)
                                    (and (not (org-queue-core-done-p task))
                                         (not (org-queue-core-habit-p task))
                                         (or (and (plist-get task :deadline)
                                                  (<= (plist-get task :deadline) deadline))
                                             (and (plist-get task :scheduled)
                                                  (<= today (plist-get task :scheduled) deadline))
                                             (equal (plist-get task :state) "NEXT"))))
                                  tasks))
                     :initial-value 0))
         (ahead (cl-count-if (lambda (task)
                               (and (plist-get task :deadline)
                                    (not (plist-get task :deadline-soft))
                                    (not (org-queue-core-done-p task))
                                    (<= today (plist-get task :deadline) deadline)))
                             tasks)))
    (if soft
        (list :window window :capacity capacity :committed committed :ahead ahead :soft t)
      (let* ((key (org-queue-horizon-key candidate))
             (before (org-queue-core-horizon (cdr pool) today deadline))
             (horizon (org-queue-core-horizon pool today deadline))
             (placement (cdr (assoc key (plist-get horizon :placements))))
             (missed-before (mapcar (lambda (m) (org-queue-horizon-key (car m)))
                                    (plist-get before :missed)))
             ;; Deadlines the candidate pushes past: missed now, met before.
             (displaced (cl-remove-if
                         (lambda (m) (member (org-queue-horizon-key (car m)) missed-before))
                         (plist-get horizon :missed)))
             (own (cl-find key displaced
                           :key (lambda (m) (org-queue-horizon-key (car m))) :test #'equal)))
        (list :window window
              :capacity capacity
              :committed committed
              :ahead ahead
              :fits (and placement (plist-get placement :complete) (null displaced) t)
              :eta (and placement (car (car (plist-get placement :days))))
              :shortfall (and displaced
                              (cl-reduce #'+ (mapcar #'cdr displaced) :initial-value 0))
              :displaced (mapcar #'car (cl-remove own displaced))
              :soft nil)))))

(defun org-queue-intake-core-line (report deadline)
  "Return REPORT for DEADLINE as one line."
  (if (plist-get report :soft)
      "a soft deadline: no capacity argument, it only pulls"
    (format "by %s: %s committed of %s in %d day%s, %d hard deadline%s ahead; %s"
            (org-queue-core-iso deadline)
            (org-queue-core-format-minutes (plist-get report :committed))
            (org-queue-core-format-minutes (plist-get report :capacity))
            (plist-get report :window) (if (= 1 (plist-get report :window)) "" "s")
            (plist-get report :ahead) (if (= 1 (plist-get report :ahead)) "" "s")
            (cond ((plist-get report :fits)
                   (format "fits, first on %s" (org-queue-core-iso (plist-get report :eta))))
                  ((plist-get report :shortfall)
                   (format "does not fit: %s short%s"
                           (org-queue-core-format-minutes (plist-get report :shortfall))
                           (if (plist-get report :displaced)
                               (format ", or move %s"
                                       (mapconcat (lambda (task) (plist-get task :title))
                                                  (plist-get report :displaced) ", "))
                             "")))
                  (t "not placed inside the window")))))

(provide 'org-queue-intake-core)
;;; org-queue-intake-core.el ends here
