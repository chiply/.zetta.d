;;; org-queue-intake.el --- The intake gate at the deadline prompt -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; `org-queue-intake' shows what a deadline would cost the entry at
;; point; the advice on `org-deadline' shows the same line just after
;; an interactive deadline is written.  Never refuses the write, never
;; runs for an IDEA or a soft deadline, never from anything but the
;; interactive command.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-queue)
(require 'org-queue-intake-core)

(defcustom org-queue-intake-advise t
  "When non-nil, an interactive `org-deadline' reports the gate afterwards."
  :type 'boolean
  :group 'org-queue)

(defun org-queue-intake-report (deadline)
  "Return the gate's report for the entry at point given DEADLINE, or nil.
Nil for an IDEA, a HOLD, a habit or a soft deadline: none consults it."
  (let* ((entry (org-queue-harvest-entry))
         (state (plist-get entry :state)))
    (unless (or (member state org-queue-excluded-states)
                (org-queue-core-habit-p entry)
                (plist-get entry :deadline-soft))
      (org-queue-intake-core (org-queue-harvest) entry deadline (org-queue-core-today)))))

;;;###autoload
(defun org-queue-intake (&optional deadline)
  "Report what committing the entry at point to DEADLINE would mean.
Prompts for the date; writes nothing."
  (interactive)
  (unless (derived-mode-p 'org-mode) (user-error "Not on an entry"))
  (let* ((date (or deadline
                   (org-queue-harvest--date (org-read-date nil t nil "Deadline to weigh: "))))
         (report (org-queue-intake-report date)))
    (if report
        (message "%s" (org-queue-intake-core-line report date))
      (message "Not a commitment the gate weighs (parked, a habit, or soft)"))))

(defun org-queue-intake--after-deadline (&rest _)
  "After an interactive `org-deadline', say what it cost."
  (when (and org-queue-intake-advise
             (derived-mode-p 'org-mode)
             (called-interactively-p 'interactive))
    (ignore-errors
      (when-let* ((deadline (org-queue-harvest--date (org-get-deadline-time (point)))))
        (when-let* ((report (org-queue-intake-report deadline)))
          (message "%s" (org-queue-intake-core-line report deadline)))))))

(advice-add 'org-deadline :after #'org-queue-intake--after-deadline)

(provide 'org-queue-intake)
;;; org-queue-intake.el ends here
