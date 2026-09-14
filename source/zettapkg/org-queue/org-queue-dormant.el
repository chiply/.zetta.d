;;; org-queue-dormant.el --- The project invariant: every project has a next step -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; A project is a heading with at least one child that has a TODO
;; keyword.  It is
;;
;;   live       when a child is open and not parked (TODO, NEXT, PROG,
;;              WAIT, QUES), or the project itself carries a plain
;;              timestamp within `org-queue-dormant-days' -- a block on
;;              the parent is a next step without children (Newport);
;;   finished?  when every child is DONE or NOPE;
;;   dormant    otherwise: the children are all parked or done, and
;;              nobody has decided what comes next.
;;
;; `org-queue-dormant-check' tags dormant projects `:dormant:' and clears
;; the tag from the rest, through the apply layer, so a check that finds
;; nothing changed writes nothing.  The queue drops a dormant parent's
;; children with reason `dormant-project'; the `j' agenda view lists
;; them; the review pack reads the same function.  Runs from the close
;; and the pack, never from a timer.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-ql)
(require 'org-queue-core)
(require 'org-queue-harvest)
(require 'org-queue-apply)

(defvar org-ql-cache)

(defcustom org-queue-dormant-days 14
  "Days ahead within which a timestamp on a project counts as a next step."
  :type 'integer
  :group 'org-queue)

(defcustom org-queue-dormant-skip-modes '(hyrolo-org-mode)
  "Major modes whose buffers the check never writes to."
  :type '(repeat symbol)
  :group 'org-queue)

(defun org-queue-dormant--child-states ()
  "Return the TODO states of the current heading's direct children."
  (save-excursion
    (save-restriction
      (org-narrow-to-subtree)
      (let ((level (org-current-level))
            states)
        (while (outline-next-heading)
          (when (= (org-current-level) (1+ level))
            (when-let* ((state (org-get-todo-state)))
              (push state states))))
        (nreverse states)))))

(defun org-queue-dormant--timestamp-within-p (days)
  "Return non-nil if the current entry has a plain active stamp within DAYS."
  (let* ((today (org-queue-core-today))
         (stamps (org-queue-harvest--timestamps today))
         (next (car stamps)))
    (and next (<= (org-queue-core-days-between today next) days))))

(defun org-queue-dormant-status ()
  "Return `live', `dormant', `finished' for the project at point, or nil.
Nil when the heading has no child with a keyword: not a project."
  (let ((states (org-queue-dormant--child-states)))
    (when states
      (cond
       ((cl-some (lambda (state)
                   (not (or (member state org-queue-done-states)
                            (member state org-queue-excluded-states))))
                 states)
        'live)
       ((org-queue-dormant--timestamp-within-p org-queue-dormant-days) 'live)
       ((cl-every (lambda (state) (member state org-queue-done-states)) states)
        'finished)
       (t 'dormant)))))

(org-ql-defpred dormant-project ()
  "Return non-nil if the entry is a project with no next step."
  :body (eq 'dormant (org-queue-dormant-status)))

(org-ql-defpred project-status (status)
  "Return non-nil if the entry is a project whose status is STATUS.
STATUS is one of `live', `dormant', `finished'."
  :body (eq status (org-queue-dormant-status)))

(defun org-queue-dormant-projects (&optional files)
  "Return every project in FILES with its status.
Each is a plist (:task TASK :status STATUS :tagged BOOL)."
  ;; org-ql caches results by query and action, and a project's status
  ;; also depends on today: a long-running daemon would keep reporting a
  ;; project live after its block has passed.  So no cache for this one.
  (let ((org-ql-cache (make-hash-table :test #'equal)))
    (org-ql-select (or files (org-queue-harvest-files))
    '(children (or (todo) (done)))
    :action (lambda ()
              (list :task (org-queue-harvest-entry)
                    :status (org-queue-dormant-status)
                    :tagged (and (member org-queue-dormant-tag (org-get-tags nil t)) t))))))

(defun org-queue-dormant--skip-p (task)
  "Return non-nil if TASK's buffer is in a mode the check must not write to."
  (when-let* ((buffer (find-buffer-visiting (plist-get task :file))))
    (memq (buffer-local-value 'major-mode buffer) org-queue-dormant-skip-modes)))

;;;###autoload
(defun org-queue-dormant-check (&optional files quiet)
  "Tag dormant projects and clear the tag from live and finished ones.
Returns the project list from `org-queue-dormant-projects'.  With
QUIET, no message."
  (interactive)
  (let* ((projects (org-queue-dormant-projects files))
         (actions
          (delq nil
                (mapcar
                 (lambda (project)
                   (let ((dormant (eq (plist-get project :status) 'dormant))
                         (tagged (plist-get project :tagged)))
                     (when (and (not (eq dormant tagged))
                                (not (org-queue-dormant--skip-p (plist-get project :task))))
                       (list :action 'tag :task (plist-get project :task)
                             :tag org-queue-dormant-tag :add dormant))))
                 projects))))
    (when actions
      (org-queue-apply-actions actions "dormant project check"))
    (unless quiet
      (message "%d project%s: %d dormant, %d finished?, %d live; %d tag%s changed"
               (length projects) (if (= 1 (length projects)) "" "s")
               (cl-count 'dormant projects :key (lambda (p) (plist-get p :status)))
               (cl-count 'finished projects :key (lambda (p) (plist-get p :status)))
               (cl-count 'live projects :key (lambda (p) (plist-get p :status)))
               (length actions) (if (= 1 (length actions)) "" "s")))
    projects))

(provide 'org-queue-dormant)
;;; org-queue-dormant.el ends here
