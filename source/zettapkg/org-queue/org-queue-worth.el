;;; org-queue-worth.el --- "Still worth it?": one item, its evidence, one key -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; `org-queue-still-worth-it' puts one entry's evidence in front of one
;; question: age, times carried, times surfaced, days since anything
;; happened to it, reschedules, and Forster's four questions.  Then one
;; key:
;;
;;   k   keep     stamps KEPT, resets SURFACED
;;   p   park     HOLD, with REVIEW_ON a season out
;;   d   dismiss  NOPE, stamped DISMISSED (the state asks for its note)
;;   q   leave it
;;
;; Every key is an apply, so it is logged and `org-queue-undo-apply'
;; reverses it.  Dismissed is a state, not a deletion: the entry stays
;; where it is, greppable, and is never proposed again.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-queue)
(require 'org-queue-review-core)

(defvar-local org-queue--worth-task nil
  "The task under question in this buffer.")

(defvar-local org-queue--worth-evidence nil
  "Its evidence.")

(defun org-queue-worth--stamp ()
  (format-time-string "[%Y-%m-%d %a]"))

(defun org-queue-worth--task-here ()
  "Return the task at point: a queue line, or the Org entry around point."
  (or (org-queue-task-at-point)
      (when (derived-mode-p 'org-mode)
        (save-excursion
          (org-back-to-heading t)
          (org-queue-harvest-entry)))
      (user-error "No task here")))

(defun org-queue-worth--draw (task evidence)
  "Draw TASK's EVIDENCE in the current buffer."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (setq org-queue--worth-task task
          org-queue--worth-evidence evidence
          org-queue--plan (list :date (org-queue-core-today) :calibration nil))
    (org-queue--insert "Still worth it?\n" 'org-queue-header)
    (org-queue--insert "\n")
    (org-queue--insert-task task (plist-get task :state))
    (org-queue--insert "\n")
    (dolist (row (list (cons "age" (if (plist-get evidence :age)
                                       (format "%d days" (plist-get evidence :age))
                                     "unknown -- no CREATED"))
                       (cons "carried" (format "%d plan%s" (plist-get evidence :carried)
                                               (if (= 1 (plist-get evidence :carried)) "" "s")))
                       (cons "surfaced" (format "%d time%s without a pull"
                                                (plist-get evidence :surfaced)
                                                (if (= 1 (plist-get evidence :surfaced)) "" "s")))
                       (cons "touched" (if (plist-get evidence :touched)
                                           (format "%d days ago" (plist-get evidence :touched))
                                         "never"))
                       (cons "rescheduled" (format "%d time%s" (plist-get evidence :rotten)
                                                   (if (= 1 (plist-get evidence :rotten)) "" "s")))
                       (cons "kept" (if (plist-get evidence :kept)
                                        (org-queue--iso (plist-get evidence :kept))
                                      "never"))))
      (org-queue--insert (format "  %-12s %s\n" (car row) (cdr row)) 'org-queue-detail))
    (org-queue--insert "\n")
    (dolist (question org-queue-review-forster-questions)
      (org-queue--insert (format "  %s\n" question) 'org-queue-section))
    (org-queue--insert "\n  k keep   p park a season   d dismiss   q leave it\n" 'org-queue-detail)
    (goto-char (point-min))))

;;;###autoload
(defun org-queue-still-worth-it ()
  "Show the evidence for the entry at point and take one key."
  (interactive)
  (let* ((task (org-queue-worth--task-here))
         (evidence (org-queue-review-core-evidence task (org-queue-history)
                                                   (org-queue-core-today)))
         (buffer (get-buffer-create "*org-queue worth*")))
    (with-current-buffer buffer
      (org-queue-worth-mode)
      (setq org-queue--columns '(state age))
      (org-queue-worth--draw task evidence))
    (pop-to-buffer buffer)))

(defun org-queue-worth--apply (actions note)
  "Apply ACTIONS to the task under question, then close the buffer."
  (let ((task org-queue--worth-task))
    (org-queue-apply-actions
     (mapcar (lambda (action) (plist-put action :task task)) actions)
     note)
    (quit-window t)
    (message "%s: %s.  ,-o-u undoes it" (plist-get task :title) note)))

(defun org-queue-worth-keep ()
  "Keep the entry: stamp KEPT and reset SURFACED."
  (interactive)
  (org-queue-worth--apply
   (list (list :action 'property :name "KEPT" :value (org-queue-worth--stamp))
         (list :action 'property :name "SURFACED" :value nil))
   "kept"))

(defun org-queue-worth-park ()
  "Park the entry: HOLD with REVIEW_ON a season out."
  (interactive)
  (let ((review (org-queue-core-date-add (org-queue-core-today) org-queue-season-days)))
    (org-queue-worth--apply
     (list (list :action 'property :name "REVIEW_ON"
                 :value (format "<%s>" (org-queue--iso review)))
           (list :action 'property :name "SURFACED" :value nil)
           (list :action 'state :to "HOLD"))
     (format "parked until %s" (org-queue--iso review)))))

(defun org-queue-worth-dismiss ()
  "Dismiss the entry: NOPE, stamped DISMISSED.  The state asks for its note."
  (interactive)
  (org-queue-worth--apply
   (list (list :action 'property :name "DISMISSED" :value (org-queue-worth--stamp))
         (list :action 'state :to "NOPE"))
   "dismissed"))

(defvar-keymap org-queue-worth-mode-map
  :doc "Keymap for `org-queue-worth-mode'."
  :parent org-queue-mode-map
  "k" #'org-queue-worth-keep
  "p" #'org-queue-worth-park
  "d" #'org-queue-worth-dismiss
  "N" #'ignore "S" #'ignore "L" #'ignore "H" #'ignore "U" #'ignore "g" #'ignore)

(define-derived-mode org-queue-worth-mode org-queue-mode "Worth"
  "Major mode for the still-worth-it question.

\\{org-queue-worth-mode-map}")

(provide 'org-queue-worth)
;;; org-queue-worth.el ends here
