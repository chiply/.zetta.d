;;; org-queue-apply.el --- Write placements back to Org entries -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The one place the queue writes to an Org file.  Everything else in the
;; package reads and reports; this file takes a list of actions -- schedule,
;; unschedule, change state, set a property, add a tag, refile -- and
;; applies them all or none, saves, and logs what it did with the reverse
;; of each action so `org-queue-undo-apply' can play it back.
;;
;; A placement the machine wrote carries `org-queue-placed-property', so it
;; stays distinguishable from a SCHEDULED a person typed: the harvest reads it
;; as `:placed', the planner may move such a placement while proposing, and
;; a person's schedule is never touched by a proposal.  A placement also
;; leaves a line in the LOGBOOK -- "Placed on [stamp] by proposal" -- because
;; Org keeps one pending reschedule note per command and the apply layer
;; batches many.
;;
;; Refuses to touch a buffer with unsaved changes.  On an error midway the
;; touched buffers are reverted, which is only safe because they were clean
;; when we started.
;;
;; An action that changes nothing -- a tag already set, a property already
;; at its value -- is performed as a no-op and left out of the log, so a
;; check that re-asserts a tag every day writes no history.

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

(defcustom org-queue-apply-placement-note t
  "When non-nil, a placement writes a line into the entry's LOGBOOK."
  :type 'boolean
  :group 'org-queue)


;;;; Actions
;;
;; An action is a plist:
;;   (:action schedule   :task TASK :to DATE :placed BOOL)
;;   (:action unschedule :task TASK)
;;   (:action state      :task TASK :to "NEXT")
;;   (:action restore    :task TASK :scheduled STRING-OR-NIL :placed STRING-OR-NIL)
;;   (:action property   :task TASK :name "KEPT" :value STRING-OR-NIL)   nil removes
;;   (:action tag        :task TASK :tag "dormant" :add BOOL)
;;   (:action refile     :task TASK :to FILE :heading STRING-OR-NIL)
;; TASK is a harvested plist, or the smaller reference the log keeps.

(defun org-queue-apply--ref (task)
  "Return the part of TASK the log needs to find the entry again."
  (list :id (plist-get task :id)
        :file (plist-get task :file)
        :title (substring-no-properties (or (plist-get task :title) ""))
        :point (plist-get task :point)))

(defun org-queue-apply--snapshot (action)
  "Return what the entry at point says now, for ACTION's reverse."
  (append
   (list :scheduled (org-entry-get (point) "SCHEDULED")
         :placed (org-entry-get (point) org-queue-placed-property)
         :state (org-get-todo-state)
         :tags (org-get-tags nil t)
         :file (buffer-file-name (buffer-base-buffer))
         :parent (save-excursion
                   (when (org-up-heading-safe)
                     (org-get-heading t t t t))))
   (pcase (plist-get action :action)
     ('property (list :value (org-entry-get (point) (plist-get action :name))))
     (_ nil))))

(defun org-queue-apply--reverse (action before)
  "Return the action that undoes ACTION, given the BEFORE snapshot.
Nil when ACTION changed nothing."
  (let ((ref (org-queue-apply--ref (plist-get action :task))))
    (pcase (plist-get action :action)
      ((or 'schedule 'unschedule 'restore)
       (list :action 'restore :task ref
             :scheduled (plist-get before :scheduled)
             :placed (plist-get before :placed)))
      ('state
       (unless (equal (plist-get action :to) (plist-get before :state))
         (list :action 'state :task ref :to (plist-get before :state))))
      ('property
       (unless (equal (plist-get action :value) (plist-get before :value))
         (list :action 'property :task ref
               :name (plist-get action :name)
               :value (plist-get before :value))))
      ('tag
       (let ((had (member (plist-get action :tag) (plist-get before :tags))))
         (unless (eq (and had t) (and (plist-get action :add) t))
           (list :action 'tag :task ref
                 :tag (plist-get action :tag)
                 :add (not (plist-get action :add))))))
      ('refile
       (list :action 'refile
             ;; The entry now lives in the destination; the reference
             ;; must say so or the ID lookup refuses the buffer.
             :task (plist-put (copy-sequence ref) :file
                              (expand-file-name (plist-get action :to)))
             :to (plist-get before :file)
             :heading (plist-get before :parent)))
      (other (error "Unknown queue action: %s" other)))))

(defun org-queue-apply--stamp ()
  (format-time-string "[%Y-%m-%d %a %H:%M]"))

(defun org-queue-apply--log-line (text)
  "Insert TEXT as a line in the entry's LOGBOOK (or under the heading)."
  (save-excursion
    (goto-char (org-log-beginning t))
    (insert "- " text "\n")))

(defvar org-queue-apply--touched nil
  "Buffers an apply has written to so far; bound by `org-queue-apply-actions'.")

(defun org-queue-apply--refile-location (file heading)
  "Return an RFLOC for `org-refile' into FILE, under HEADING when given."
  (let* ((file (expand-file-name file))
         (buffer (or (find-buffer-visiting file) (find-file-noselect file))))
    (with-current-buffer buffer
      (cl-pushnew buffer org-queue-apply--touched)
      (if (not heading)
          (list nil file nil nil)
        (let ((position (org-find-exact-headline-in-buffer heading buffer t)))
          (unless position
            (error "No heading %S in %s" heading (file-name-nondirectory file)))
          (list heading file nil position))))))

(defun org-queue-apply--perform (action)
  "Carry out ACTION on the entry at point."
  (pcase (plist-get action :action)
    ('schedule
     (org-schedule nil (org-queue-core-iso (plist-get action :to)))
     (if (plist-get action :placed)
         (progn
           (org-entry-put (point) org-queue-placed-property (org-queue-apply--stamp))
           (when org-queue-apply-placement-note
             (org-queue-apply--log-line
              (format "Placed on %s by proposal" (org-queue-apply--stamp)))))
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
     (unless (equal (plist-get action :to) (org-get-todo-state))
       (org-todo (plist-get action :to))))
    ('property
     (if (plist-get action :value)
         (org-entry-put (point) (plist-get action :name) (plist-get action :value))
       (org-entry-delete (point) (plist-get action :name))))
    ('tag
     (let ((tags (org-get-tags nil t))
           (tag (plist-get action :tag)))
       (if (plist-get action :add)
           (unless (member tag tags) (org-set-tags (append tags (list tag))))
         (when (member tag tags) (org-set-tags (remove tag tags))))))
    ('refile
     ;; An ID so the reverse, and anything else, can find it in its new
     ;; home; org-id is the one thing that survives a move.
     (org-id-get-create)
     (let ((org-refile-keep nil)
           (org-log-refile nil))
       (org-refile nil nil (org-queue-apply--refile-location
                            (plist-get action :to) (plist-get action :heading)))))
    (other (error "Unknown queue action: %s" other))))


;;;; Applying

(defun org-queue-apply--log ()
  "Return the apply log, newest first."
  (when (and org-queue-apply-log-file (file-readable-p org-queue-apply-log-file))
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
`:reverse' is the list of actions that undoes this one, or nil when
every action turned out to be a no-op (nothing is written or logged)."
  (let ((org-queue-apply--touched nil)
        done reverse)
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
              (cl-pushnew (current-buffer) org-queue-apply--touched)
              (save-excursion
                (save-restriction
                  (widen)
                  (goto-char (cdr where))
                  (org-back-to-heading t)
                  (let* ((before (org-queue-apply--snapshot action))
                         (undo (org-queue-apply--reverse action before)))
                    (when undo
                      (org-queue-apply--perform action)
                      (push action done)
                      (push undo reverse))))))))
      (error
       (dolist (buffer org-queue-apply--touched)
         (with-current-buffer buffer (revert-buffer t t t)))
       (signal (car err) (cdr err))))
    (when done
      (dolist (buffer org-queue-apply--touched)
        (with-current-buffer buffer
          (when (buffer-modified-p) (save-buffer))))
      (org-queue-apply--record
       (list :stamp (org-queue-apply--stamp)
             :note note
             :actions (mapcar (lambda (action)
                                (plist-put (copy-sequence action) :task
                                           (org-queue-apply--ref (plist-get action :task))))
                              (nreverse done))
             :reverse (nreverse reverse))))))

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
