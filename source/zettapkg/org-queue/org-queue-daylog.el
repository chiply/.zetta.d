;;; org-queue-daylog.el --- The day log, drawn from the files -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; `org-queue-day-log' reads one day's evidence -- the state transitions
;; and the intervals they open, the captures made that day, the journal
;; lines, whatever `org-queue-daylog-extra-functions' contribute -- and
;; draws it in time order in the queue's own buffer, one line per event,
;; RET to jump.  Under it, the stretches inside a working block with
;; nothing in PROG.  A view, never a write.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-ql)
(require 'org-queue)
(require 'org-queue-daylog-core)

(defcustom org-queue-daylog-buffer-name "*org-queue day*"
  "Name of the buffer the day log is drawn in."
  :type 'string
  :group 'org-queue)

(defcustom org-queue-journal-file nil
  "The journal file whose lines the day log reads; nil for none.
Journal lines are headings of the form `* HH:MM text' under a heading
that names the day."
  :type '(choice (const nil) file)
  :group 'org-queue)

(defvar org-queue-daylog-blocks-function nil
  "Function of a YYYYMMDD date returning the routine's blocks for it.
Set by the routine module; nil means no gaps are computed.")

(defvar org-queue-daylog-extra-functions nil
  "Functions of (DATE DAY-START DAY-END) returning extra events.
Commits, mail, whatever else leaves a trace; each returns a list of
event plists as `org-queue-daylog-core' documents them.")

(defun org-queue-daylog--day-start (date)
  "Return midnight opening DATE, a YYYYMMDD integer, in epoch seconds."
  (floor (float-time (encode-time 0 0 0 (% date 100) (% (/ date 100) 100) (/ date 10000)))))

(defun org-queue-daylog--intervals (day-start day-end)
  "Return (INTERVALS . TRANSITIONS) for the day between DAY-START and DAY-END.

INTERVALS are the working intervals overlapping the day, clipped to it;
TRANSITIONS are events for every state change that happened inside the
day.  An entry that has sat in DONE for a month has an open DONE
interval covering today, and that is not evidence of anything, so only
working states become bars."
  (let (intervals transitions)
    (org-ql-select (org-queue-harvest-files) org-queue-harvest-query
      :action (lambda ()
                (let ((title (org-get-heading t t t t))
                      (id (or (org-id-get) (format "%s:%d" (buffer-file-name) (point))))
                      (file (buffer-file-name (buffer-base-buffer)))
                      (point (point)))
                  (dolist (interval (org-queue-state-intervals nil (current-time)))
                    (let* ((start (floor (float-time (plist-get interval :start))))
                           (end (floor (float-time (plist-get interval :end))))
                           (working (and (member (plist-get interval :state)
                                                 org-queue-working-states)
                                         t)))
                      (when (and (>= start day-start) (< start day-end))
                        (push (list :time start :kind 'transition
                                    :title title :id id :state (plist-get interval :state)
                                    :file file :point point)
                              transitions))
                      (when (and working (< start day-end) (> end day-start))
                        (push (list :start (max start day-start)
                                    :end (if (plist-get interval :open) nil (min end day-end))
                                    :open (plist-get interval :open)
                                    :working t
                                    :state (plist-get interval :state)
                                    :title title :id id :file file :point point)
                              intervals)))))))
    (cons (nreverse intervals) (nreverse transitions))))

(defun org-queue-daylog--captures (day-start day-end)
  "Return the entries captured between DAY-START and DAY-END, as events."
  (let ((files (delete-dups
                (append (org-queue-harvest-files)
                        (when (and (boundp 'org-queue-inbox-file) org-queue-inbox-file
                                   (file-readable-p (expand-file-name org-queue-inbox-file)))
                          (list (expand-file-name org-queue-inbox-file)))))))
    (delq
     nil
     (org-ql-select files '(property "CREATED")
      :action (lambda ()
                (when-let* ((created (org-entry-get (point) "CREATED"))
                            (time (ignore-errors (org-time-string-to-time created)))
                            (seconds (floor (float-time time))))
                  (when (and (>= seconds day-start) (< seconds day-end))
                    (list :time seconds :kind 'capture
                          :title (org-get-heading t t t t)
                          :id (org-id-get)
                          :state (org-get-todo-state)
                          :interrupted (org-entry-get (point) "INTERRUPTED")
                          :backlink (save-excursion
                                      (let ((end (save-excursion (outline-next-heading) (point))))
                                        (when (re-search-forward
                                               "\\[\\[\\(mu4e\\|elfeed\\|https?\\|eww\\):" end t)
                                          (match-string 1))))
                          :file (buffer-file-name (buffer-base-buffer))
                          :point (point)))))))))

(defun org-queue-daylog--journal (date day-start)
  "Return the journal lines of DATE as events."
  (when (and org-queue-journal-file (file-readable-p (expand-file-name org-queue-journal-file)))
    (with-temp-buffer
      (insert-file-contents (expand-file-name org-queue-journal-file))
      (org-mode)
      (goto-char (point-min))
      (let ((iso (org-queue-core-iso date))
            (journal (let* ((time (encode-time 0 0 12 (% date 100) (% (/ date 100) 100)
                                               (/ date 10000)))
                            (day (% date 100)))
                       (format "%s %d%s, %d" (format-time-string "%b" time) day
                               (cond ((memq day '(11 12 13)) "th")
                                     ((= (% day 10) 1) "st")
                                     ((= (% day 10) 2) "nd")
                                     ((= (% day 10) 3) "rd")
                                     (t "th"))
                               (/ date 10000))))
            events)
        (when (re-search-forward (format "^\\* .*\\(%s\\|%s\\)" (regexp-quote iso)
                                         (regexp-quote journal))
                                 nil t)
          (let ((end (save-excursion (org-end-of-subtree t t) (point))))
            (while (re-search-forward "^\\*\\* \\([0-9]\\{2\\}\\):\\([0-9]\\{2\\}\\) \\(.*\\)$" end t)
              (push (list :time (+ day-start (* 3600 (string-to-number (match-string 1)))
                                   (* 60 (string-to-number (match-string 2))))
                          :kind 'journal
                          :title (match-string 3)
                          :file (expand-file-name org-queue-journal-file)
                          :point (match-beginning 0))
                    events))))
        (nreverse events)))))

(defun org-queue-daylog-compute (date)
  "Return the assembled day log of DATE, a YYYYMMDD integer."
  (let* ((day-start (org-queue-daylog--day-start date))
         (day-end (+ day-start 86400))
         (now (floor (float-time)))
         (read (org-queue-daylog--intervals day-start day-end))
         (intervals (car read))
         (blocks (and org-queue-daylog-blocks-function
                      (funcall org-queue-daylog-blocks-function date))))
    (append
     (list :date date :day-start day-start :blocks blocks)
     (org-queue-daylog-core-assemble
      :intervals intervals
      :captures (org-queue-daylog--captures day-start day-end)
      :journal (org-queue-daylog--journal date day-start)
      :commits (append (cdr read)
                       (apply #'append
                              (mapcar (lambda (function) (funcall function date day-start day-end))
                                      org-queue-daylog-extra-functions)))
      :blocks blocks
      :day-start day-start
      :now (and (< now day-end) now)))))


;;;; Drawing

(defvar-local org-queue--daylog nil
  "The day log drawn in this buffer.")

(defun org-queue-daylog--event-task (event)
  "Return EVENT as a task plist `org-queue--insert-task' can draw."
  (list :title (plist-get event :title)
        :id (plist-get event :id)
        :file (plist-get event :file)
        :point (plist-get event :point)
        :category (pcase (plist-get event :kind)
                    ('interval-start "start")
                    ('interval-end "end")
                    ('transition "state")
                    ('capture "capture")
                    ('journal "journal")
                    ('commit "commit")
                    (kind (format "%s" kind)))
        :state (plist-get event :state)
        :effort (or (plist-get event :minutes) 0)
        :queue-minutes (or (plist-get event :minutes) 0)))

(defun org-queue-daylog--draw (log)
  "Draw LOG in the current buffer."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (setq org-queue--daylog log
          org-queue--plan (list :date (plist-get log :date) :calibration nil))
    (org-queue--insert (org-queue--date-string (plist-get log :date)) 'org-queue-header)
    (org-queue--insert (format "   %d events\n" (length (plist-get log :events)))
                       'org-queue-detail)
    (org-queue--insert-legend)
    (org-queue--insert "\nThe day\n" 'org-queue-section)
    (dolist (event (plist-get log :events))
      (org-queue--insert-task
       (org-queue-daylog--event-task event)
       (concat (format-time-string "%H:%M" (plist-get event :time))
               (pcase (plist-get event :kind)
                 ('interval-start (format "  into %s" (plist-get event :state)))
                 ('interval-end (format "  left %s" (plist-get event :state)))
                 ('transition (format "  -> %s" (plist-get event :state)))
                 ('capture (if (plist-get event :interrupted)
                               (format "  interrupted %s%s"
                                       (plist-get event :interrupted)
                                       (if (plist-get event :joined-by-time) " (by time)" ""))
                             ""))
                 (_ "")))))
    (when (plist-get log :gaps)
      (org-queue--insert "\nUntracked -- nothing in PROG inside a working block\n"
                         'org-queue-section)
      (dolist (gap (plist-get log :gaps))
        (org-queue--insert
         (format "  %6s  %s-%s  %s\n"
                 (org-queue-core-format-minutes (plist-get gap :minutes))
                 (format-time-string "%H:%M" (plist-get gap :start))
                 (format-time-string "%H:%M" (plist-get gap :end))
                 (or (plist-get gap :block) ""))
         'org-queue-detail)))
    (when-let* ((counts (cl-remove-if (lambda (c) (and (zerop (plist-get c :internal))
                                                       (zerop (plist-get c :external))))
                                      (plist-get log :interruptions))))
      (org-queue--insert "\nInterruptions per block\n" 'org-queue-section)
      (dolist (count counts)
        (org-queue--insert (format "  %-24s %d internal, %d external\n"
                                   (plist-get count :block)
                                   (plist-get count :internal) (plist-get count :external))
                           'org-queue-detail)))
    (goto-char (point-min))))

;;;###autoload
(defun org-queue-day-log (&optional prompt)
  "Show the day's evidence in time order.
With PROMPT (\\[universal-argument]), another day."
  (interactive "P")
  (let* ((date (if prompt
                   (org-queue-harvest--date (org-read-date nil t nil "Day: "))
                 (org-queue-core-today)))
         (log (org-queue-daylog-compute date))
         (buffer (get-buffer-create org-queue-daylog-buffer-name)))
    (with-current-buffer buffer
      (org-queue-daylog-mode)
      (setq org-queue--columns (copy-sequence org-queue-columns)
            org-queue--redraw-function (lambda () (org-queue-daylog--draw org-queue--daylog)))
      (org-queue-daylog--draw log))
    (pop-to-buffer buffer)))

(defun org-queue-daylog-refresh ()
  "Re-read the day this buffer shows."
  (interactive)
  (org-queue-daylog--draw (org-queue-daylog-compute (plist-get org-queue--daylog :date))))

(defvar-keymap org-queue-daylog-mode-map
  :doc "Keymap for `org-queue-daylog-mode'."
  :parent org-queue-mode-map
  "g" #'org-queue-daylog-refresh)

(define-derived-mode org-queue-daylog-mode org-queue-mode "Day"
  "Major mode for the day log.

\\{org-queue-daylog-mode-map}")

(provide 'org-queue-daylog)
;;; org-queue-daylog.el ends here
