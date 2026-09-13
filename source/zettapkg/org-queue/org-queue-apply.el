;;; org-queue-apply.el --- Write placements back to Org entries -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The one place the queue writes to an Org file.  Everything else in the
;; package reads and reports; this file takes a list of actions -- schedule,
;; unschedule, change state -- and applies them all or none, saves, and logs
;; what it did with the reverse of each action so `org-queue-undo-apply' can
;; play it back.
;;
;; A placement the machine wrote carries `org-queue-placed-property', so it
;; stays distinguishable from a SCHEDULED a person typed: the harvest reads it
;; as `:placed', the planner may move such a placement while proposing, and
;; a person's schedule is never touched by a proposal.
;;
;; Refuses to touch a buffer with unsaved changes.  On an error midway the
;; touched buffers are reverted, which is only safe because they were clean
;; when we started.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-id)
(require 'org-queue-core)
(require 'org-queue-harvest)

(defcustom org-queue-placed-property "PLACED"
  "Property stamped on an entry whose SCHEDULED the queue wrote."
  :type 'string
  :group 'org-queue)

(defcustom org-queue-apply-log-file
  (expand-file-name "org-queue-applies.el" user-emacs-directory)
  "Where applied actions and their reverses are recorded."
  :type 'file
  :group 'org-queue)

(defcustom org-queue-apply-log-length 50
  "How many applies to keep in the log."
  :type 'integer
  :group 'org-queue)


;;;; Actions
;;
;; An action is a plist:
;;   (:action schedule   :task TASK :to DATE :placed BOOL)
;;   (:action unschedule :task TASK)
;;   (:action state      :task TASK :to "NEXT")
;;   (:action restore    :task TASK :scheduled STRING-OR-NIL :placed STRING-OR-NIL)
;; TASK is a harvested plist, or the smaller reference the log keeps.

(defun org-queue-apply--ref (task)
  "Return the part of TASK the log needs to find the entry again."
  (list :id (plist-get task :id)
        :file (plist-get task :file)
        :title (substring-no-properties (or (plist-get task :title) ""))
        :point (plist-get task :point)))

(defun org-queue-apply--snapshot ()
  "Return what the entry at point says now, for the reverse action."
  (list :scheduled (org-entry-get (point) "SCHEDULED")
        :placed (org-entry-get (point) org-queue-placed-property)
        :state (org-get-todo-state)))

(defun org-queue-apply--reverse (action before)
  "Return the action that undoes ACTION, given the BEFORE snapshot."
  (let ((ref (org-queue-apply--ref (plist-get action :task))))
    (pcase (plist-get action :action)
      ((or 'schedule 'unschedule 'restore)
       (list :action 'restore :task ref
             :scheduled (plist-get before :scheduled)
             :placed (plist-get before :placed)))
      ('state (list :action 'state :task ref :to (plist-get before :state))))))

(defun org-queue-apply--stamp ()
  (format-time-string "[%Y-%m-%d %a %H:%M]"))

(defun org-queue-apply--perform (action)
  "Carry out ACTION on the entry at point."
  (pcase (plist-get action :action)
    ('schedule
     (org-schedule nil (org-queue-core-iso (plist-get action :to)))
     (if (plist-get action :placed)
         (org-entry-put (point) org-queue-placed-property (org-queue-apply--stamp))
       (org-entry-delete (point) org-queue-placed-property)))
    ('unschedule
     (org-schedule '(4))
     (org-entry-delete (point) org-queue-placed-property))
    ('restore
     (if (plist-get action :scheduled)
         (org-schedule nil (plist-get action :scheduled))
       (org-schedule '(4)))
     (if (plist-get action :placed)
         (org-entry-put (point) org-queue-placed-property (plist-get action :placed))
       (org-entry-delete (point) org-queue-placed-property)))
    ('state
     (org-todo (plist-get action :to)))
    (other (error "Unknown queue action: %s" other))))


;;;; Applying

(defun org-queue-apply--log ()
  "Return the apply log, newest first."
  (when (file-readable-p org-queue-apply-log-file)
    (with-temp-buffer
      (insert-file-contents org-queue-apply-log-file)
      (ignore-errors (read (current-buffer))))))

(defun org-queue-apply--record (entry)
  "Prepend ENTRY to the apply log on disk."
  (let ((log (cons entry (seq-take (org-queue-apply--log)
                                   (1- org-queue-apply-log-length)))))
    (make-directory (file-name-directory org-queue-apply-log-file) t)
    (with-temp-file org-queue-apply-log-file
      (let ((print-length nil) (print-level nil))
        (prin1 log (current-buffer))
        (insert "\n")))
    entry))

(defun org-queue-apply-actions (actions &optional note)
  "Apply ACTIONS to their entries, all or none, save, and log them.

NOTE is kept with the log entry.  Returns the log entry, whose
`:reverse' is the list of actions that undoes this one."
  (let (touched reverse)
    ;; Every buffer first, so a dirty one is found before anything is written.
    (dolist (action actions)
      (let ((buffer (car (org-queue-harvest-locate (plist-get action :task)))))
        (when (buffer-modified-p buffer)
          (user-error "%s has unsaved changes; save it before applying"
                      (buffer-name buffer)))))
    (condition-case err
        (dolist (action actions)
          (let* ((task (plist-get action :task))
                 (where (org-queue-harvest-locate task)))
            (with-current-buffer (car where)
              (cl-pushnew (current-buffer) touched)
              (save-excursion
                (save-restriction
                  (widen)
                  (goto-char (cdr where))
                  (org-back-to-heading t)
                  (let ((before (org-queue-apply--snapshot)))
                    (org-queue-apply--perform action)
                    (push (org-queue-apply--reverse action before) reverse)))))))
      (error
       (dolist (buffer touched)
         (with-current-buffer buffer (revert-buffer t t t)))
       (signal (car err) (cdr err))))
    (dolist (buffer touched)
      (with-current-buffer buffer (save-buffer)))
    (org-queue-apply--record
     (list :stamp (org-queue-apply--stamp)
           :note note
           :actions (mapcar (lambda (action)
                              (plist-put (copy-sequence action) :task
                                         (org-queue-apply--ref (plist-get action :task))))
                            actions)
           :reverse (nreverse reverse)))))

;;;###autoload
(defun org-queue-undo-apply ()
  "Reverse the most recent apply.
The undo is itself logged, so a second call redoes it."
  (interactive)
  (let ((last (car (org-queue-apply--log))))
    (unless last (user-error "Nothing to undo"))
    (org-queue-apply-actions (plist-get last :reverse)
                             (format "undo of %s" (plist-get last :stamp)))
    (message "Undid the apply of %s (%d action%s)"
             (plist-get last :stamp)
             (length (plist-get last :reverse))
             (if (= 1 (length (plist-get last :reverse))) "" "s"))))

(provide 'org-queue-apply)
;;; org-queue-apply.el ends here
