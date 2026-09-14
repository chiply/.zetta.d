;;; org-queue-habit-core.el --- Habit strength: Loop's score, the two-miss alert -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Habits phase 2, the arithmetic.  A habit's strength is Loop's
;; exponential score: with m = 0.5 ^ (sqrt(frequency) / 13), a done day
;; moves the score toward one (s = s * m + 1 - m), a missed day toward
;; zero (s = s * m), a skipped day leaves it alone.  Thirty consecutive
;; days from zero give 0.798, sixty 0.959, ninety 0.992: the closed form
;; 1 - m^n.  No streak, no reset to zero -- a miss costs a fraction, not
;; everything.  Two consecutive misses raise an alert; a done within a
;; day of a miss clears it (the repair window).
;;
;; A series is a list of (DATE . MARK), DATE a YYYYMMDD integer and MARK
;; one of `done', `miss', `skip', oldest first.  No Org in here.

;;; Code:

(require 'cl-lib)

(defcustom org-queue-habit-half-life 13
  "Days over which a daily habit's score halves when missed: Loop's constant."
  :type 'integer
  :group 'org-queue)

(defun org-queue-habit-core-factor (&optional frequency)
  "Return the daily multiplier m for a habit done FREQUENCY times a day.
FREQUENCY defaults to 1; a habit done three times a week has frequency
3/7, so its half-life is longer than a daily one's."
  (expt 0.5 (/ (sqrt (or frequency 1.0)) (float org-queue-habit-half-life))))

(defun org-queue-habit-core-score (series &optional frequency)
  "Return the strength of a habit after SERIES, in [0, 1].
Returns (:score S :alert ALERT :misses N), ALERT `two-misses' when the
last two marked days were misses with no done since, else nil."
  (let ((m (org-queue-habit-core-factor frequency))
        (score 0.0)
        (run 0)                        ; consecutive misses, cleared by a done
        (alert nil))
    (dolist (cell series)
      (pcase (cdr cell)
        ('done (setq score (+ (* score m) (- 1.0 m)) run 0 alert nil))
        ('miss (setq score (* score m) run (1+ run))
               (when (>= run 2) (setq alert 'two-misses)))
        ('skip nil)))
    (list :score (max 0.0 (min 1.0 score)) :alert alert :misses run)))

(defun org-queue-habit-core-closed-form (days &optional frequency)
  "The score after DAYS consecutive dones from zero: 1 - m^days."
  (- 1.0 (expt (org-queue-habit-core-factor frequency) days)))

(defun org-queue-habit-core-series (dones from to applies-p &optional skips)
  "Build a series from DONES, the dates ticked, over FROM..TO.

APPLIES-P is a function of a YYYYMMDD date saying whether the habit
falls on that day (HABIT_DAYS); a day it does not fall on is not in the
series.  SKIPS are dates explicitly skipped.  Every applicable day is
exactly one of done, skip or miss."
  (let ((day from) series)
    (while (<= day to)
      (when (funcall applies-p day)
        (push (cons day (cond ((member day dones) 'done)
                              ((member day skips) 'skip)
                              (t 'miss)))
              series))
      (setq day (org-queue-habit-core--add-days day 1)))
    (nreverse series)))

(defun org-queue-habit-core--day-number (date)
  (let* ((y (/ date 10000)) (m (% (/ date 100) 100)) (d (% date 100))
         (y (if (<= m 2) (1- y) y))
         (era (/ (if (>= y 0) y (- y 399)) 400))
         (yoe (- y (* era 400)))
         (doy (+ (/ (+ (* 153 (+ m (if (> m 2) -3 9))) 2) 5) (1- d)))
         (doe (+ (* yoe 365) (/ yoe 4) (- (/ yoe 100)) doy)))
    (+ (* era 146097) doe -719468)))

(defun org-queue-habit-core--date-from-day-number (days)
  (let* ((z (+ days 719468))
         (era (/ (if (>= z 0) z (- z 146096)) 146097))
         (doe (- z (* era 146097)))
         (yoe (/ (- doe (/ doe 1460) (- (/ doe 36524)) (/ doe 146096)) 365))
         (y (+ yoe (* era 400)))
         (doy (- doe (- (+ (* 365 yoe) (/ yoe 4)) (/ yoe 100))))
         (mp (/ (+ (* 5 doy) 2) 153))
         (d (1+ (- doy (/ (+ (* 153 mp) 2) 5))))
         (m (if (< mp 10) (+ mp 3) (- mp 9)))
         (y (if (<= m 2) (1+ y) y)))
    (+ (* y 10000) (* m 100) d)))

(defun org-queue-habit-core--add-days (date days)
  (org-queue-habit-core--date-from-day-number
   (+ (org-queue-habit-core--day-number date) days)))

(provide 'org-queue-habit-core)
;;; org-queue-habit-core.el ends here
