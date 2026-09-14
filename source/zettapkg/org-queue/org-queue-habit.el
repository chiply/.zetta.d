;;; org-queue-habit.el --- Habit strength written back, the two-miss alert -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Habits phase 2, the Org side.  Each habit's series is derived from
;; its own LOGBOOK -- every transition into DONE is a tick, the days it
;; falls on with no tick are misses, `HABIT_SKIP' names the days that
;; were neither -- and `org-queue-habit-core' scores it.  The score and
;; the alert are written back as HABIT_STRENGTH and HABIT_ALERT through
;; the apply layer, once a day from the close; a two-miss alert also
;; goes through `zetta-notify'.  org-habit's own graph is the chart; the
;; faces are re-skinned onto the ink ladder in the module.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-queue-core)
(require 'org-queue-harvest)
(require 'org-queue-apply)
(require 'org-queue-habit-core)

(declare-function zetta-notify "alert" (message &optional title severity))

(defcustom org-queue-habit-window 90
  "Days of history a habit's score is built over."
  :type 'integer
  :group 'org-queue)

(defun org-queue-habit--dones (task)
  "The dates TASK's LOGBOOK shows a transition into a done state."
  (delq nil (mapcar (lambda (cell)
                      (and (member (car cell) org-queue-done-states) (cdr cell)))
                    (plist-get task :transitions))))

(defun org-queue-habit--skips (task)
  "The dates TASK's HABIT_SKIP names."
  (let ((where (org-queue-harvest-locate task)))
    (with-current-buffer (car where)
      (org-with-wide-buffer
       (goto-char (cdr where))
       (when-let* ((raw (org-entry-get (point) "HABIT_SKIP")))
         (delq nil (mapcar (lambda (word)
                             (and (string-match "\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)" word)
                                  (+ (* 10000 (string-to-number (match-string 1 word)))
                                     (* 100 (string-to-number (match-string 2 word)))
                                     (string-to-number (match-string 3 word)))))
                           (split-string raw))))))))

(defun org-queue-habit-series (task today)
  "TASK's series over the window ending TODAY, from its ticks."
  (let* ((dones (org-queue-habit--dones task))
         (from (max (or (plist-get task :created) 0)
                    (org-queue-core-date-add today (- org-queue-habit-window))))
         (from (if dones (min from (apply #'min dones)) from)))
    (org-queue-habit-core-series
     dones from today
     (lambda (day) (org-queue-core-habit-applies-p task day))
     (org-queue-habit--skips task))))

(defun org-queue-habit-scores (&optional today)
  "Return (TASK . SCORE-PLIST) for every habit, as of TODAY."
  (let ((today (or today (org-queue-core-today))))
    (mapcar (lambda (habit)
              (cons habit (org-queue-habit-core-score (org-queue-habit-series habit today))))
            (cl-remove-if-not #'org-queue-core-habit-p (org-queue-harvest nil today)))))

;;;###autoload
(defun org-queue-habit-update (&optional today quiet)
  "Write every habit's HABIT_STRENGTH and HABIT_ALERT, and raise the alerts.
One apply; unchanged values write nothing.  With QUIET, no notification."
  (interactive)
  (let* ((scores (org-queue-habit-scores today))
         (actions
          (apply #'append
                 (mapcar (lambda (cell)
                           (let ((task (car cell)) (score (cdr cell)))
                             (list (list :action 'property :task task :name "HABIT_STRENGTH"
                                         :value (format "%.2f" (plist-get score :score)))
                                   (list :action 'property :task task :name "HABIT_ALERT"
                                         :value (and (plist-get score :alert)
                                                     (symbol-name (plist-get score :alert)))))))
                         scores)))
         (alerts (cl-remove-if-not (lambda (cell) (plist-get (cdr cell) :alert)) scores)))
    (when actions
      (org-queue-apply-actions actions "habit strength"))
    (when (and alerts (not quiet) (fboundp 'zetta-notify))
      (zetta-notify (format "Two misses: %s"
                            (mapconcat (lambda (cell) (plist-get (car cell) :title)) alerts ", "))
                    "Habits"))
    (unless quiet
      (message "%d habit%s scored, %d alert%s" (length scores) (if (= 1 (length scores)) "" "s")
               (length alerts) (if (= 1 (length alerts)) "" "s")))
    scores))

(provide 'org-queue-habit)
;;; org-queue-habit.el ends here
