;;; org-queue.el --- Fill a day from the Org backlog -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (org-ql "0.8"))
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; `org-queue-today' harvests the agenda files, packs a day out of them,
;; and shows the result -- including what did not make it and why.
;;
;; The report is the point.  A planner you cannot interrogate gets
;; distrusted and abandoned about a week in, so every task the harvest
;; found is accounted for on screen: planned, cut for a stated reason, or
;; excluded by a rule you can name.  Press TAB to see the ones that lost.
;;
;;   RET   jump to the task            g    replan
;;   o     show it in another window   c    calibration report
;;   TAB   what was cut, and why       q    bury
;;
;; The arithmetic all lives in `org-queue-core', which has no Org in it;
;; this file only asks the questions and draws the answers.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-queue-core)
(require 'org-queue-harvest)

(defcustom org-queue-buffer-name "*org-queue*"
  "Name of the buffer the day's plan is drawn in."
  :type 'string
  :group 'org-queue)

(defcustom org-queue-show-details nil
  "When non-nil, open the plan with the cut and excluded work expanded."
  :type 'boolean
  :group 'org-queue)


;;;; Faces
;;
;; Prominence, not hue: the plan is a ladder from the day itself (bold)
;; down through its supporting numbers (shadow) to the work that lost
;; (shadow, smaller weight).  Nothing here encodes meaning in colour, so
;; a theme can restyle all of it by moving the rungs.

(defface org-queue-header '((t :inherit bold))
  "Face for the plan's date line."
  :group 'org-queue)

(defface org-queue-section '((t :inherit (bold shadow)))
  "Face for section headings within the plan."
  :group 'org-queue)

(defface org-queue-detail '((t :inherit shadow))
  "Face for supporting numbers: minutes, categories, scores."
  :group 'org-queue)

(defface org-queue-guess '((t :inherit (italic shadow)))
  "Face for figures the planner made up, such as a default effort."
  :group 'org-queue)

(defface org-queue-alarm '((t :inherit bold :underline t))
  "Face for the overcommitment banner.

Underlined bold rather than red: the day being too full is the loudest
thing on the page, and it should read that way in any theme."
  :group 'org-queue)


;;;; State

(defvar-local org-queue--plan nil
  "The plan currently drawn in this buffer.")

(defvar-local org-queue--details nil
  "Whether the cut and excluded sections are expanded.")


;;;; Formatting

(defun org-queue--date-string (date)
  "Return DATE, a YYYYMMDD integer, as a readable date."
  (format-time-string
   "%A %-d %B %Y"
   (encode-time 0 0 12 (% date 100) (% (/ date 100) 100) (/ date 10000))))

(defconst org-queue--reason-labels
  '((committed      . "committed")
    (scored         . "chosen")
    (pulled-forward . "pulled forward")
    (no-room        . "no room left in the day")
    (wip-limit      . "would exceed the work-in-progress limit")
    (overcommitted  . "the day is already overcommitted")
    (done           . "finished")
    (state          . "not a commitment (HOLD or IDEA)")
    (blocked        . "blocked by unfinished work")
    (waiting        . "waiting, with no deadline in sight")
    (event-later    . "an appointment on a later day")
    (event-past     . "an appointment that has already happened"))
  "Human wording for the reasons a task ends up where it does.")

(defun org-queue--reason-label (reason)
  (or (alist-get reason org-queue--reason-labels) (format "%s" reason)))

(defun org-queue--insert (string &optional face)
  (insert (if face (propertize string 'face face) string)))

(defun org-queue--insert-task (task &optional note)
  "Insert one line for TASK, with an optional right-hand NOTE."
  (let ((start (point)))
    (org-queue--insert
     (format "  %6s  " (org-queue-core-format-minutes
                        (or (plist-get task :queue-minutes)
                            (org-queue-core-minutes
                             task (plist-get org-queue--plan :calibration)))))
     (if (plist-get task :queue-guessed) 'org-queue-guess 'org-queue-detail))
    (org-queue--insert (format "%-7s " (or (plist-get task :category) "-"))
                       'org-queue-detail)
    (insert (truncate-string-to-width (or (plist-get task :title) "") 58))
    (when note
      (org-queue--insert (format "  %s" note) 'org-queue-detail))
    (put-text-property start (point) 'org-queue-task task)
    (insert "\n")))

(defun org-queue--insert-section (title tasks note-function)
  (when tasks
    (org-queue--insert (format "\n%s\n" title) 'org-queue-section)
    (dolist (task tasks)
      (org-queue--insert-task task (funcall note-function task)))))

(defun org-queue--tally (cells)
  "Summarise CELLS, an alist of (TASK . REASON), as \"reason n, reason n\"."
  (let (counts)
    (dolist (cell cells)
      (cl-incf (alist-get (cdr cell) counts 0)))
    (mapconcat (lambda (cell)
                 (format "%s %d" (org-queue--reason-label (car cell))
                         (cdr cell)))
               (nreverse counts) ", ")))


;;;; Drawing

(defun org-queue--draw (plan)
  "Draw PLAN in the current buffer."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (setq org-queue--plan plan)
    (org-queue--insert (org-queue--date-string (plist-get plan :date))
                       'org-queue-header)
    (org-queue--insert
     (format "   %s planned of %s usable (%s capacity, %d%% slack)\n"
             (org-queue-core-format-minutes (plist-get plan :minutes))
             (org-queue-core-format-minutes (plist-get plan :usable))
             (org-queue-core-format-minutes (plist-get plan :capacity))
             (round (* 100 org-queue-slack-fraction)))
     'org-queue-detail)
    (when (plist-get plan :overcommitted)
      (org-queue--insert
       (format "\nOVERCOMMITTED by %s -- nothing was planned on top.\n"
               (org-queue-core-format-minutes
                (- (plist-get plan :minutes) (plist-get plan :usable))))
       'org-queue-alarm)
      (org-queue--insert
       "What you have already agreed to does not fit in the day.  That is
the finding, not a bug: move a deadline, drop a commitment, or accept
that today overflows.\n"
       'org-queue-detail))

    (let ((by-reason (lambda (reason)
                       (cl-remove-if-not
                        (lambda (task)
                          (eq reason (plist-get task :queue-reason)))
                        (plist-get plan :planned)))))
      (org-queue--insert-section
       "Committed" (funcall by-reason 'committed)
       (lambda (task) (org-queue--when-note task)))
      (org-queue--insert-section
       "Chosen" (funcall by-reason 'scored)
       (lambda (task) (format "%.1f" (or (plist-get task :queue-score) 0))))
      (org-queue--insert-section
       "Pulled forward" (funcall by-reason 'pulled-forward)
       (lambda (task)
         (format "scheduled %s" (or (plist-get task :scheduled) "")))))

    (if (not org-queue--details)
        (org-queue--insert
         (format "\n%d cut, %d excluded, %d deferred.  TAB to see why.\n"
                 (length (plist-get plan :cut))
                 (length (plist-get plan :dropped))
                 (length (plist-get plan :deferred)))
         'org-queue-detail)
      (org-queue--insert-section
       (format "Cut (%d)" (length (plist-get plan :cut)))
       (mapcar #'car (plist-get plan :cut))
       (lambda (task)
         (org-queue--reason-label
          (cdr (assq task (plist-get plan :cut))))))
      (org-queue--insert-section
       (format "Deferred (%d)" (length (plist-get plan :deferred)))
       (plist-get plan :deferred)
       (lambda (task) (format "scheduled %s" (or (plist-get task :scheduled) ""))))
      (org-queue--insert-section
       (format "Excluded (%d)" (length (plist-get plan :dropped)))
       (mapcar #'car (plist-get plan :dropped))
       (lambda (task)
         (org-queue--reason-label
          (cdr (assq task (plist-get plan :dropped)))))))

    (org-queue--insert
     (format "\n%s\n"
             (or (org-queue--tally (append (plist-get plan :cut)
                                           (plist-get plan :dropped)))
                 ""))
     'org-queue-detail)
    (when org-queue-calibrate
      (org-queue--insert
       (format "Estimates scaled by %.2fx overall; c for the breakdown.\n"
               (alist-get t (plist-get plan :calibration) 1.0))
       'org-queue-detail))
    (goto-char (point-min))))

(defun org-queue--when-note (task)
  "Return the reason TASK counts as committed today."
  (cond
   ((and (plist-get task :timestamp)
         (= (plist-get task :timestamp) (plist-get org-queue--plan :date)))
    "appointment")
   ((and (plist-get task :deadline)
         (<= (plist-get task :deadline) (plist-get org-queue--plan :date)))
    (if (< (plist-get task :deadline) (plist-get org-queue--plan :date))
        (format "overdue since %s" (plist-get task :deadline))
      "due today"))
   ((plist-get task :scheduled)
    (if (< (plist-get task :scheduled) (plist-get org-queue--plan :date))
        (format "scheduled %s" (plist-get task :scheduled))
      "scheduled today"))))


;;;; Commands

(defun org-queue-plan (&optional date)
  "Return a plan for DATE, a YYYYMMDD integer defaulting to today."
  (let* ((date (or date (org-queue-core-today)))
         (tasks (org-queue-harvest nil date)))
    (org-queue-core-plan tasks date)))

;;;###autoload
(defun org-queue-today (&optional prompt)
  "Plan today from the agenda files and show the result.
With PROMPT (\\[universal-argument]), plan another day instead."
  (interactive "P")
  (let* ((date (if prompt
                   (let ((chosen (org-read-date nil t nil "Plan which day? ")))
                     (org-queue-harvest--date chosen))
                 (org-queue-core-today)))
         (plan (org-queue-plan date))
         (buffer (get-buffer-create org-queue-buffer-name)))
    (org-queue-record-plan plan)
    (with-current-buffer buffer
      (org-queue-mode)
      (setq org-queue--details org-queue-show-details)
      (org-queue--draw plan))
    (pop-to-buffer buffer)
    (message "%s" (org-queue-core-summary plan))))

(defun org-queue-refresh ()
  "Replan the day this buffer shows."
  (interactive)
  (let* ((date (plist-get org-queue--plan :date))
         (plan (org-queue-plan date)))
    (org-queue-record-plan plan)
    (org-queue--draw plan)
    (message "%s" (org-queue-core-summary plan))))

(defun org-queue-toggle-details ()
  "Show or hide the work that did not make the plan."
  (interactive)
  (setq org-queue--details (not org-queue--details))
  (org-queue--draw org-queue--plan))

(defun org-queue-task-at-point ()
  "Return the task on the current line, or nil."
  (get-text-property (point) 'org-queue-task))

(defun org-queue--goto (task other-window)
  "Move to TASK's Org entry, in OTHER-WINDOW when non-nil."
  (let* ((file (plist-get task :file))
         (position (plist-get task :point))
         (id (plist-get task :id))
         (buffer (and file (find-file-noselect file))))
    (unless buffer (user-error "No file recorded for this task"))
    (with-current-buffer buffer
      ;; The recorded position is only as fresh as the last harvest, so
      ;; check the heading is still the one that was planned and fall
      ;; back to the ID -- which survives any amount of editing -- if the
      ;; file has moved underneath us.
      (let ((found (save-excursion
                     (goto-char (min position (point-max)))
                     (and (ignore-errors (org-back-to-heading t))
                          (equal (org-get-heading t t t t)
                                 (plist-get task :title))
                          (point)))))
        (setq position (or found
                           (when id
                             (when-let* ((marker (org-id-find id t)))
                               (marker-position marker)))
                           position))))
    (funcall (if other-window #'pop-to-buffer #'pop-to-buffer-same-window)
             buffer)
    (widen)
    (goto-char position)
    (org-back-to-heading t)
    (org-fold-show-entry)
    (org-fold-show-children)))

(defun org-queue-goto ()
  "Jump to the task on this line."
  (interactive)
  (if-let* ((task (org-queue-task-at-point)))
      (org-queue--goto task nil)
    (user-error "No task on this line")))

(defun org-queue-display ()
  "Show the task on this line in another window."
  (interactive)
  (if-let* ((task (org-queue-task-at-point)))
      (save-selected-window (org-queue--goto task t))
    (user-error "No task on this line")))

(defun org-queue-calibration ()
  "Report how estimates compare with the clock, per category."
  (interactive)
  (let* ((tasks (org-queue-harvest))
         (report (org-queue-core-calibration-report tasks))
         (buffer (get-buffer-create "*org-queue calibration*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (special-mode)
        (org-queue--insert "Estimate versus clock, on finished work\n"
                           'org-queue-header)
        (org-queue--insert
         (format "\n%-12s %5s  %8s  %8s\n" "category" "n" "measured" "applied")
         'org-queue-section)
        (dolist (row report)
          (insert (format "%-12s %5d  %7.2fx  %7.2fx\n"
                          (if (eq (plist-get row :category) t)
                              "(all)"
                            (plist-get row :category))
                          (plist-get row :n)
                          (plist-get row :raw)
                          (plist-get row :factor))))
        (org-queue--insert
         (format "
\"measured\" is clocked minutes over estimated minutes.  \"applied\" is
that pulled toward the overall factor by %d phantom observations, so a
category with two finished tasks cannot swing the packing on its own.
Estimates are%s currently scaled by it.\n"
                 org-queue-calibration-prior
                 (if org-queue-calibrate "" " NOT"))
         'org-queue-detail)
        (goto-char (point-min))))
    (pop-to-buffer buffer)))

(defun org-queue-next ()
  "Move to the next task line."
  (interactive)
  (let ((position (next-single-property-change (point) 'org-queue-task)))
    (while (and position (not (get-text-property position 'org-queue-task)))
      (setq position (next-single-property-change position 'org-queue-task)))
    (when position (goto-char position))))

(defun org-queue-previous ()
  "Move to the previous task line."
  (interactive)
  (let ((position (previous-single-property-change (point) 'org-queue-task)))
    (while (and position (not (get-text-property position 'org-queue-task)))
      (setq position (previous-single-property-change position 'org-queue-task)))
    (when position (goto-char (line-beginning-position)))))

(defvar-keymap org-queue-mode-map
  :doc "Keymap for `org-queue-mode'."
  "RET" #'org-queue-goto
  "o"   #'org-queue-display
  "g"   #'org-queue-refresh
  "TAB" #'org-queue-toggle-details
  "c"   #'org-queue-calibration
  "n"   #'org-queue-next
  "p"   #'org-queue-previous)

(define-derived-mode org-queue-mode special-mode "Queue"
  "Major mode for the day's queue.

\\{org-queue-mode-map}"
  (setq truncate-lines t)
  (setq-local cursor-type nil))

(provide 'org-queue)
;;; org-queue.el ends here
