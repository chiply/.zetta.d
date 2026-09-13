;;; org-queue-close.el --- Close the day: the buffer and its keys -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; `org-queue-close' draws the day's close in the queue's own style:
;; what was planned and not finished, what finished, what is overdue and
;; due tomorrow, what is still in PROG, what tomorrow's routine holds, the
;; inbox count, and a draft of tomorrow.  Three keys write:
;;
;;   N          mark a draft line NEXT -- the third is refused
;;   T / W      mark a PROG line to move to TODO / WAIT
;;   C-c C-c    apply the marked moves together, undone together
;;
;; Closing stamps today's entry in the plan history, so the morning
;; report can say whether yesterday was closed.  The phrase is printed,
;; not asked.  Nothing here raises a prompt.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-queue)
(require 'org-queue-close-core)

(defcustom org-queue-close-buffer-name "*org-queue close*"
  "Name of the buffer the close is drawn in."
  :type 'string
  :group 'org-queue)

(defcustom org-queue-inbox-file nil
  "The inbox file whose unprocessed captures the close counts.
Nil means no count."
  :type '(choice (const nil) file)
  :group 'org-queue)

(defvar org-queue-close-chains-function nil
  "Function returning the chains in flight, for the close.
Each is a plist (:task TASK :prompt STRING-OR-NIL).  Set by org-chain.")

(defvar org-queue-close-routine-function nil
  "Function of a YYYYMMDD date returning tomorrow's fixed rows as strings.
Set by the routine module.")

(defvar-local org-queue--close nil
  "The close drawn in this buffer.")

(defvar-local org-queue--sweep nil
  "Alist of (ID . STATE) marks for the PROG sweep.")


;;;; The history stamp

(defun org-queue-close-stamp (date)
  "Return the close stamp of DATE from the history, or nil."
  (when-let* ((entry (cl-find date (org-queue-history)
                              :key (lambda (entry) (plist-get entry :date)))))
    (plist-get entry :closed)))

(defun org-queue-close-record (date carried)
  "Stamp DATE as closed in the history, recording CARRIED ids.
Idempotent: a day already closed keeps its first stamp."
  (let* ((history (org-queue-history))
         (entry (cl-find date history :key (lambda (entry) (plist-get entry :date)))))
    (unless (and entry (plist-get entry :closed))
      (let* ((stamped (append (list :closed (format-time-string "[%Y-%m-%d %a %H:%M]")
                                    :carried carried)
                              (or entry (list :date date :ids nil))))
             (updated (cons stamped (cl-remove date history
                                               :key (lambda (entry) (plist-get entry :date))))))
        (make-directory (file-name-directory org-queue-history-file) t)
        (with-temp-file org-queue-history-file
          (let ((print-length nil) (print-level nil))
            (prin1 updated (current-buffer))
            (insert "\n")))))
    (org-queue-close-stamp date)))


;;;; Gathering

(defun org-queue-close--inbox-count ()
  "Return the number of top-level entries in `org-queue-inbox-file'."
  (when (and org-queue-inbox-file (file-readable-p (expand-file-name org-queue-inbox-file)))
    (with-temp-buffer
      (insert-file-contents (expand-file-name org-queue-inbox-file))
      (count-matches "^\\* " (point-min) (point-max)))))

(defun org-queue-close--interruptions (tasks)
  "Return an alist of (ID . COUNT): captures made while each entry was in PROG.
Counted from the harvested entries' INTERRUPTED properties and from the
inbox, which the harvest may not read."
  (let (counts)
    (dolist (task tasks)
      (when-let* ((id (plist-get task :interrupted)))
        (cl-incf (alist-get id counts 0 nil #'equal))))
    (when (and org-queue-inbox-file (file-readable-p (expand-file-name org-queue-inbox-file)))
      (with-temp-buffer
        (insert-file-contents (expand-file-name org-queue-inbox-file))
        (goto-char (point-min))
        (while (re-search-forward "^[ \t]*:INTERRUPTED:[ \t]+\\(\\S-+\\)" nil t)
          (cl-incf (alist-get (match-string 1) counts 0 nil #'equal)))))
    counts))

(defun org-queue-close-compute (&optional date)
  "Return the close of DATE (default today) over the agenda files."
  (let* ((today (or date (org-queue-core-today)))
         (tasks (org-queue-harvest nil today))
         (entry (cl-find today (org-queue-history)
                         :key (lambda (entry) (plist-get entry :date)))))
    (org-queue-close-core
     tasks today
     :plan-ids (plist-get entry :ids)
     :history (org-queue-history)
     :inbox-count (org-queue-close--inbox-count)
     :routine-tomorrow (and org-queue-close-routine-function
                            (funcall org-queue-close-routine-function
                                     (org-queue-core-date-add today 1)))
     :interruptions (org-queue-close--interruptions tasks)
     :chains (and org-queue-close-chains-function
                  (funcall org-queue-close-chains-function))
     :closed (plist-get entry :closed))))


;;;; Drawing

(defun org-queue-close--insert-plain (title items)
  "Insert section TITLE with ITEMS, plain strings."
  (when items
    (org-queue--insert (format "\n%s\n" title) 'org-queue-section)
    (dolist (item items)
      (org-queue--insert (format "          %s\n" item) 'org-queue-detail))))

(defun org-queue-close--draw (close)
  "Draw CLOSE in the current buffer."
  (let ((inhibit-read-only t)
        (draft (plist-get close :draft)))
    (erase-buffer)
    (setq org-queue--close close
          org-queue--plan draft)
    (org-queue--insert (format "Closing %s" (org-queue--date-string (plist-get close :date)))
                       'org-queue-header)
    (org-queue--insert
     (if (plist-get close :already-closed)
         (format "   closed at %s\n" (plist-get close :already-closed))
       "\n")
     'org-queue-detail)
    (org-queue--insert-legend)
    (org-queue--insert-section
     (format "Unfinished (%d) -- carried to tomorrow" (length (plist-get close :unfinished)))
     (plist-get close :unfinished)
     (lambda (task) (format "carried %d time%s" (plist-get task :carried-count)
                            (if (= 1 (plist-get task :carried-count)) "" "s"))))
    (org-queue-close--insert-plain
     "Planned, but no longer in the corpus"
     (plist-get close :missing))
    (org-queue--insert-section
     (format "Done today (%d)" (length (plist-get close :done)))
     (plist-get close :done)
     (lambda (task) (if (plist-get task :unplanned) "unplanned" "")))
    (org-queue--insert-section
     "Overdue"
     (plist-get close :overdue)
     (lambda (task) (format "due %s" (org-queue--iso (plist-get task :deadline)))))
    (org-queue--insert-section
     "Due tomorrow"
     (plist-get close :due-tomorrow)
     (lambda (task) (if (plist-get task :deadline-soft) "soft" "hard")))
    (org-queue--insert-section
     "Still in PROG -- T to TODO, W to WAIT, C-c C-c to apply"
     (plist-get close :prog)
     (lambda (task)
       (let ((mark (alist-get (plist-get task :id) org-queue--sweep nil nil #'equal)))
         (concat (if mark (format "-> %s  " mark) "")
                 (if (> (plist-get task :interruptions) 0)
                     (format "%d interruption%s" (plist-get task :interruptions)
                             (if (= 1 (plist-get task :interruptions)) "" "s"))
                   "")))))
    (let ((chains (plist-get close :chains)))
      (when (or (plist-get chains :primed) (plist-get chains :unprimed))
        (org-queue--insert "\nChains\n" 'org-queue-section)
        (dolist (chain (plist-get chains :primed))
          (org-queue--insert-task (plist-get chain :task) "next prompt ready"))
        (dolist (chain (plist-get chains :unprimed))
          (org-queue--insert-task (plist-get chain :task) "prime: no next prompt"))))
    (org-queue-close--insert-plain
     "Tomorrow's routine"
     (plist-get close :routine-tomorrow))
    (org-queue--insert-section
     "Tomorrow's appointments"
     (plist-get close :appointments)
     (lambda (_task) "appointment"))
    (org-queue--insert (format "\nInbox: %d\n" (plist-get close :inbox-count))
                       'org-queue-section)
    (org-queue--insert
     (format "\nTomorrow's draft -- %s   (N to pick, up to %d)\n"
             (org-queue-core-summary draft) org-queue-pick-limit)
     'org-queue-section)
    (org-queue--insert (org-queue--capacity-line draft) 'org-queue-detail)
    (org-queue--insert-buckets draft)
    (org-queue--draw-body draft)
    (org-queue--insert (format "\n%s\n" (plist-get close :phrase)) 'org-queue-header)
    (goto-char (point-min))))


;;;; Commands

;;;###autoload
(defun org-queue-close (&optional prompt)
  "Close the day: draw what happened and a draft of tomorrow.
With PROMPT (\\[universal-argument]), close another day instead."
  (interactive "P")
  (let* ((date (if prompt
                   (org-queue-harvest--date (org-read-date nil t nil "Close which day? "))
                 (org-queue-core-today)))
         (close (org-queue-close-compute date))
         (buffer (get-buffer-create org-queue-close-buffer-name)))
    (org-queue-close-record date (mapcar (lambda (task) (plist-get task :id))
                                         (plist-get close :unfinished)))
    (with-current-buffer buffer
      (org-queue-close-mode)
      (setq org-queue--columns (copy-sequence org-queue-columns)
            org-queue--details nil
            org-queue--sweep nil
            org-queue--redraw-function (lambda () (org-queue-close--draw org-queue--close)))
      (org-queue-close--draw close))
    (pop-to-buffer buffer)
    (message "%s" (plist-get close :phrase))))

(defun org-queue-close-refresh ()
  "Recompute the close this buffer shows, keeping the sweep marks."
  (interactive)
  (let ((close (org-queue-close-compute (plist-get org-queue--close :date))))
    (org-queue-close--draw close)))

(defun org-queue-close-mark-next ()
  "Mark the draft line at point NEXT, unless the pick limit is reached."
  (interactive)
  (let ((task (or (org-queue-task-at-point) (user-error "No task on this line"))))
    (unless (org-queue-close-core-pick-allowed-p (org-queue-harvest) org-queue-pick-limit)
      (user-error "Already %d picks; the composite's day holds %d -- finish or unmark one first"
                  org-queue-pick-limit org-queue-pick-limit))
    (org-queue-apply-actions (list (list :action 'state :task task :to "NEXT"))
                             "N at the close")
    (org-queue-close-refresh)))

(defun org-queue-close--mark-sweep (state)
  "Mark the PROG line at point to move to STATE at apply time."
  (let ((task (or (org-queue-task-at-point) (user-error "No task on this line"))))
    (unless (equal (plist-get task :state) "PROG")
      (user-error "%s is not in PROG" (plist-get task :title)))
    (setf (alist-get (plist-get task :id) org-queue--sweep nil nil #'equal) state)
    (let ((line (line-number-at-pos)))
      (org-queue-close--draw org-queue--close)
      (goto-char (point-min))
      (forward-line (1- line)))))

(defun org-queue-close-mark-todo ()
  "Mark the PROG entry at point to go back to TODO when the sweep is applied."
  (interactive)
  (org-queue-close--mark-sweep "TODO"))

(defun org-queue-close-mark-wait ()
  "Mark the PROG entry at point to go to WAIT when the sweep is applied."
  (interactive)
  (org-queue-close--mark-sweep "WAIT"))

(defun org-queue-close-apply-sweep ()
  "Move every marked PROG entry to its state, all together, logged once.
The note a state would ask for is not asked here: add it with
\\[org-add-note] on the entry, so that a sweep of five never raises
five prompts."
  (interactive)
  (unless org-queue--sweep (user-error "Nothing marked; T or W on a PROG line first"))
  (let* ((by-id (mapcar (lambda (task) (cons (plist-get task :id) task))
                        (plist-get org-queue--close :prog)))
         (actions (delq nil
                        (mapcar (lambda (mark)
                                  (when-let* ((task (alist-get (car mark) by-id nil nil #'equal)))
                                    (list :action 'state :task task :to (cdr mark))))
                                org-queue--sweep)))
         (org-inhibit-logging 'note))
    (org-queue-apply-actions actions "PROG sweep at the close")
    (setq org-queue--sweep nil)
    (org-queue-close-refresh)
    (message "%d entr%s moved; ,-o-u undoes the sweep"
             (length actions) (if (= 1 (length actions)) "y" "ies"))))

(defvar-keymap org-queue-close-mode-map
  :doc "Keymap for `org-queue-close-mode'."
  :parent org-queue-mode-map
  "g"       #'org-queue-close-refresh
  "N"       #'org-queue-close-mark-next
  "T"       #'org-queue-close-mark-todo
  "W"       #'org-queue-close-mark-wait
  "C-c C-c" #'org-queue-close-apply-sweep)

(define-derived-mode org-queue-close-mode org-queue-mode "Close"
  "Major mode for the day's close.

\\{org-queue-close-mode-map}")

(provide 'org-queue-close)
;;; org-queue-close.el ends here
