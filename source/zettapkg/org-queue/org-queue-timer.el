;;; org-queue-timer.el --- A unit timer inside the dip -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Pomodoros where focus is weakest, never rung in the deep block.  On
;; the transition into PROG, when now falls inside the routine's dip,
;; `org-timer-set-timer' starts with the entry's Effort; `org-queue-timer'
;; offers the same by hand and says why not otherwise.  A bell only: the
;; interval comes from the state log, never from the timer, and the
;; bell is `zetta-notify'.

;;; Code:

(require 'org)
(require 'org-timer)

(declare-function org-routine-in-dip-p "org-routine" (&optional time))
(declare-function zetta-notify "alert" (message &optional title severity))
(defvar org-state)

(defcustom org-queue-timer-on-prog t
  "When non-nil, entering PROG inside the dip starts the timer."
  :type 'boolean
  :group 'org-queue)

(defcustom org-queue-timer-default-minutes 25
  "Minutes when the entry has no Effort: a pomodoro."
  :type 'integer
  :group 'org-queue)

(defun org-queue-timer-applicable-p (&optional time)
  "Return non-nil when TIME (default now) falls inside the routine's dip.
Nil when there is no routine to ask."
  (and (fboundp 'org-routine-in-dip-p)
       (ignore-errors (org-routine-in-dip-p time))))

(defun org-queue-timer--minutes ()
  "The entry's Effort in minutes, or the default."
  (or (when-let* ((effort (org-entry-get (point) "Effort")))
        (let ((minutes (ignore-errors (org-duration-to-minutes effort))))
          (and minutes (> minutes 0) (round minutes))))
      org-queue-timer-default-minutes))

(defun org-queue-timer--start (minutes)
  "Start the timer for MINUTES, replacing a running one."
  (when (and (boundp 'org-timer-countdown-timer) org-timer-countdown-timer)
    (org-timer-stop))
  (let ((org-timer-default-timer (number-to-string minutes)))
    (org-timer-set-timer '(64)))
  (message "Timer: %d minutes on %s" minutes (org-get-heading t t t t)))

;;;###autoload
(defun org-queue-timer ()
  "Start a timer on the entry at point, if now is inside the dip."
  (interactive)
  (unless (derived-mode-p 'org-mode) (user-error "Not on an entry"))
  (if (org-queue-timer-applicable-p)
      (org-queue-timer--start (org-queue-timer--minutes))
    (message "Not inside the dip: no timer in a deep block, by design")))

(defun org-queue-timer--on-prog ()
  "Start the timer when an entry enters PROG inside the dip."
  (when (and org-queue-timer-on-prog
             (equal org-state "PROG")
             (org-queue-timer-applicable-p))
    (org-queue-timer--start (org-queue-timer--minutes))))

(defun org-queue-timer--bell ()
  "The bell, through the one notification path."
  (if (fboundp 'zetta-notify)
      (zetta-notify "The unit is over" "Timer")
    (message "The unit is over")))

(add-hook 'org-after-todo-state-change-hook #'org-queue-timer--on-prog)
(add-hook 'org-timer-done-hook #'org-queue-timer--bell)

(provide 'org-queue-timer)
;;; org-queue-timer.el ends here
