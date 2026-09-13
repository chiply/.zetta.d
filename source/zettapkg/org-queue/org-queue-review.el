;;; org-queue-review.el --- The weekly review pack, drawn from the files -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; `org-queue-review-week' assembles the Monday pack: one buffer in the
;; queue's style with a section per group, in a fixed order, from what
;; the files already say.  Sacha Chua's way: generated from the log, not
;; retyped.  Three keys:
;;
;;   y          "still worth it?" on the line at point
;;   w          write the review lines into the reviews file's datetree
;;   D          run the dormant project check (tags through the apply layer)
;;
;; Showing a parked item counts as surfacing it: the pack bumps SURFACED
;; on every parked-due and proposed item, in one apply, so the counter
;; the dismissal rule reads is real.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-datetree)
(require 'org-queue)
(require 'org-queue-close)
(require 'org-queue-dormant)
(require 'org-queue-review-core)
(require 'org-queue-worth)

(declare-function org-gantt-harvest "org-gantt-harvest")
(declare-function org-gantt-core-summarize "org-gantt-core" (rows &optional now))

(defcustom org-queue-review-buffer-name "*org-queue review*"
  "Name of the buffer the pack is drawn in."
  :type 'string
  :group 'org-queue)

(defcustom org-queue-reviews-file "~/kb/notes/reviews.org"
  "Where the review lines are written, in a datetree."
  :type 'file
  :group 'org-queue)

(defcustom org-queue-review-count-surfacings t
  "When non-nil, the pack bumps SURFACED on the parked items it shows."
  :type 'boolean
  :group 'org-queue)

(defvar org-queue-review-expected-function nil
  "Function of (FROM TO), YYYYMMDD, returning expected minutes per bucket.
Set by the routine module from the table.")

(defvar org-queue-review-floors-function nil
  "Function returning the areas' (CATEGORY MIN . MAX) hours a week.
Set by the horizons module.")

(defvar org-queue-review-chains-function nil
  "Function of (FROM TO) returning the chains' week, drawn as lines.
Set by org-chain.")

(defvar-local org-queue--pack nil
  "The pack drawn in this buffer.")


;;;; Gathering

(defun org-queue-review--inbox-ages (today)
  "Return the age in days of every top-level inbox entry."
  (when (and org-queue-inbox-file (file-readable-p (expand-file-name org-queue-inbox-file)))
    (with-temp-buffer
      (insert-file-contents (expand-file-name org-queue-inbox-file))
      (org-mode)
      (let (ages)
        (org-map-entries
         (lambda ()
           (let ((created (org-queue-harvest--timestamp-date (org-entry-get (point) "CREATED"))))
             (push (if created (org-queue-core-days-between created today) 0) ages)))
         "LEVEL=1" 'file)
        ages))))

(defun org-queue-review--time (from-date today)
  "Return (BY-CATEGORY . BY-BUCKET) worked minutes between FROM-DATE and TODAY."
  (when (and (require 'org-gantt-harvest nil t) (require 'org-gantt-core nil t))
    (let* ((from (org-queue-daylog--day-start from-date))
           (to (+ (org-queue-daylog--day-start today) 86400))
           (rows (org-gantt-core-summarize (org-gantt-harvest :from from :to to)))
           by-category by-bucket)
      (dolist (row rows)
        (let ((worked (or (plist-get row :worked) 0)))
          (when (> worked 0)
            (cl-incf (alist-get (plist-get row :category) by-category 0 nil #'equal) worked)
            (cl-incf (alist-get (org-queue-core-bucket
                                 (list :category (plist-get row :category)
                                       :tags (plist-get row :tags)))
                                by-bucket 0)
                     worked))))
      (cons by-category by-bucket))))

(declare-function org-queue-daylog--day-start "org-queue-daylog" (date))

(defun org-queue-review-compute (&optional today)
  "Return the pack for the week ending TODAY."
  (require 'org-queue-daylog)
  (let* ((today (or today (org-queue-core-today)))
         (from (org-queue-core-date-add today (- org-queue-review-window)))
         (tasks (org-queue-harvest nil today))
         (time (org-queue-review--time from today)))
    (org-queue-review-core
     tasks today
     :history (org-queue-history)
     :inbox-ages (org-queue-review--inbox-ages today)
     :dormant (org-queue-dormant-check nil t)
     :calibration (org-queue-core-calibration-report tasks)
     :time-by-category (car time)
     :time-by-bucket (cdr time)
     :expected-by-bucket (and org-queue-review-expected-function
                              (funcall org-queue-review-expected-function from today))
     :floors (and org-queue-review-floors-function
                  (funcall org-queue-review-floors-function))
     :chains (and org-queue-review-chains-function
                  (funcall org-queue-review-chains-function from today)))))

(defun org-queue-review--count-surfacings (pack)
  "Bump SURFACED on every parked item PACK shows, in one apply."
  (when org-queue-review-count-surfacings
    (let ((seen (make-hash-table :test #'equal))
          actions)
      (dolist (task (append (plist-get pack :parked-due) (plist-get pack :worth)))
        (let ((key (or (plist-get task :id) (plist-get task :title))))
          (unless (gethash key seen)
            (puthash key t seen)
            (push (list :action 'property :task task :name "SURFACED"
                        :value (number-to-string (1+ (or (plist-get task :surfaced) 0))))
                  actions))))
      (when actions
        (org-queue-apply-actions (nreverse actions) "surfaced by the review pack")))))


;;;; Drawing

(defun org-queue-review--plain (title lines)
  "Insert section TITLE with LINES, plain strings, when there are any."
  (when lines
    (org-queue--insert (format "\n%s\n" title) 'org-queue-section)
    (dolist (line lines)
      (org-queue--insert (format "  %s\n" line) 'org-queue-detail))))

(defun org-queue-review--draw (pack)
  "Draw PACK in the current buffer."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (setq org-queue--pack pack
          org-queue--plan (list :date (plist-get pack :date) :calibration nil))
    (org-queue--insert (format "Review -- the %d days to %s\n" (plist-get pack :window)
                               (org-queue--date-string (plist-get pack :date)))
                       'org-queue-header)
    (dolist (question (plist-get pack :questions))
      (org-queue--insert (format "   %s\n" question) 'org-queue-detail))
    (org-queue--insert "   w to write the answers\n" 'org-queue-detail)
    (org-queue--insert-legend)
    (org-queue--insert-section
     (format "Moved (%d)" (length (plist-get pack :moved))) (plist-get pack :moved)
     (lambda (task) (let ((last (plist-get task :last-transition)))
                      (if last (format "-> %s %s" (car last) (org-queue--iso (cdr last))) ""))))
    (org-queue--insert-section
     (format "Finished (%d)" (length (plist-get pack :finished))) (plist-get pack :finished)
     (lambda (task) (if (plist-get task :closed) (org-queue--iso (plist-get task :closed)) "")))
    (dolist (bucket (plist-get pack :stalled))
      (unless (eq (car bucket) 'week)
        (org-queue--insert-section
         (format "Neglected -- %s (%d)" (alist-get (car bucket) org-queue-review-stalled-buckets)
                 (length (cdr bucket)))
         (cdr bucket)
         (lambda (task) (if (plist-get task :touched)
                            (format "touched %s" (org-queue--iso (plist-get task :touched)))
                          "")))))
    (org-queue--insert-section
     (format "Chase (%d)" (length (plist-get pack :chase))) (plist-get pack :chase)
     (lambda (task) (format "%s, %s" (or (plist-get task :waiting-on) "nobody named")
                            (if (plist-get task :touched)
                                (format "since %s" (org-queue--iso (plist-get task :touched)))
                              "undated"))))
    (org-queue--insert-section
     (format "Parked, due for another look (%d) -- y to decide" (length (plist-get pack :parked-due)))
     (plist-get pack :parked-due)
     (lambda (task) (format "review on %s" (org-queue--iso (plist-get task :review-on)))))
    (org-queue--insert-section
     (format "Untriaged (%d)" (length (plist-get pack :untriaged))) (plist-get pack :untriaged)
     (lambda (task) (string-join (delq nil (list (unless (plist-get task :effort) "no estimate")
                                                 (unless (plist-get task :priority) "no priority")
                                                 (unless (or (plist-get task :scheduled)
                                                             (plist-get task :deadline)
                                                             (plist-get task :timestamp))
                                                   "no date")))
                                 ", ")))
    (let ((inbox (plist-get pack :inbox)))
      (org-queue--insert (format "\nInbox: %d  (%d this week, %d this month, %d older)\n"
                                 (plist-get inbox :count)
                                 (plist-get (plist-get inbox :ages) :week)
                                 (plist-get (plist-get inbox :ages) :month)
                                 (plist-get (plist-get inbox :ages) :older))
                         'org-queue-section))
    (org-queue--insert-section
     (format "Dormant projects (%d) -- no next step" (length (plist-get pack :dormant)))
     (mapcar (lambda (p) (plist-get p :task)) (plist-get pack :dormant))
     (lambda (_task) "dormant"))
    (org-queue--insert-section
     (format "Finished? (%d) -- every child done" (length (plist-get pack :finished-projects)))
     (mapcar (lambda (p) (plist-get p :task)) (plist-get pack :finished-projects))
     (lambda (_task) "close it"))
    (org-queue--insert-section
     (format "Still worth it? (%d) -- surfaced %d times; y to decide"
             (length (plist-get pack :worth)) org-queue-dismiss-after)
     (plist-get pack :worth)
     (lambda (task) (format "surfaced %d, carried %d"
                            (plist-get (plist-get task :evidence) :surfaced)
                            (plist-get (plist-get task :evidence) :carried))))
    (when-let* ((rows (plist-get pack :calibration)))
      (org-queue-review--plain
       "Calibration -- measured over estimated"
       (mapcar (lambda (row) (format "%-12s n=%-3d %.2fx measured, %.2fx applied"
                                     (if (eq (plist-get row :category) t) "(all)"
                                       (plist-get row :category))
                                     (plist-get row :n) (plist-get row :raw) (plist-get row :factor)))
               rows)))
    (org-queue-review--plain
     "Time by category"
     (mapcar (lambda (cell) (format "%-12s %s" (car cell) (org-queue-core-format-minutes (cdr cell))))
             (sort (copy-sequence (plist-get pack :time)) (lambda (a b) (> (cdr a) (cdr b))))))
    (org-queue-review--plain
     "Against the routine"
     (mapcar (lambda (row) (format "%-12s %s of %s  %s"
                                   (plist-get row :bucket)
                                   (org-queue-core-format-minutes (plist-get row :actual))
                                   (org-queue-core-format-minutes (plist-get row :expected))
                                   (pcase (plist-get row :verdict)
                                     ('under "under") ('over "over") ('on "") (_ ""))))
             (plist-get pack :template)))
    (org-queue-review--plain
     "Areas against their floors"
     (mapcar (lambda (row) (format "%-12s %s  %s"
                                   (plist-get row :category)
                                   (org-queue-core-format-minutes (plist-get row :minutes))
                                   (pcase (plist-get row :verdict)
                                     ('below (format "below the floor of %sh" (plist-get row :min)))
                                     ('above (format "above the ceiling of %sh" (plist-get row :max)))
                                     (_ ""))))
             (plist-get pack :floors)))
    (let ((rotten (plist-get pack :rotten)))
      (when (> (plist-get rotten :count) 0)
        (org-queue--insert-section
         (format "Rescheduled -- ROTTEN %d" (plist-get rotten :count))
         (plist-get rotten :tasks)
         (lambda (task) (format "%d time%s" (plist-get task :rotten)
                                (if (= 1 (plist-get task :rotten)) "" "s"))))))
    (org-queue-review--plain "Chains" (plist-get pack :chains))
    (goto-char (point-min))))


;;;; Commands

;;;###autoload
(defun org-queue-review-week (&optional prompt)
  "Assemble the weekly review pack.
With PROMPT (\\[universal-argument]), end the week on another day."
  (interactive "P")
  (let* ((today (if prompt
                    (org-queue-harvest--date (org-read-date nil t nil "Week ending: "))
                  (org-queue-core-today)))
         (pack (org-queue-review-compute today))
         (buffer (get-buffer-create org-queue-review-buffer-name)))
    (org-queue-review--count-surfacings pack)
    (with-current-buffer buffer
      (org-queue-review-mode)
      (setq org-queue--columns (copy-sequence org-queue-columns)
            org-queue--redraw-function (lambda () (org-queue-review--draw org-queue--pack)))
      (org-queue-review--draw pack))
    (pop-to-buffer buffer)
    (message "%s" (org-queue-review-core-summary pack))))

(defun org-queue-review-refresh ()
  "Assemble the pack again, without counting surfacings twice."
  (interactive)
  (org-queue-review--draw (org-queue-review-compute (plist-get org-queue--pack :date))))

(defun org-queue-review-write ()
  "Write the answers to the questions into the reviews file's datetree."
  (interactive)
  (let* ((pack org-queue--pack)
         (date (plist-get pack :date))
         (answers (mapcar (lambda (question)
                            (cons question (read-string (concat question " "))))
                          (plist-get pack :questions)))
         (file (expand-file-name org-queue-reviews-file)))
    (unless (file-exists-p file)
      (with-temp-file file (insert "#+TITLE: Reviews\n\n")))
    (with-current-buffer (find-file-noselect file)
      (save-excursion
        (save-restriction
          (widen)
          (org-datetree-find-date-create
           (list (% (/ date 100) 100) (% date 100) (/ date 10000)))
          (org-end-of-subtree t t)
          (insert (format "**** Review -- %s\n" (org-queue-review-core-summary pack)))
          (dolist (answer answers)
            (unless (string-empty-p (cdr answer))
              (insert (format "- %s :: %s\n" (car answer) (cdr answer)))))
          (save-buffer))))
    (message "Written to %s" (file-name-nondirectory file))))

(defun org-queue-review-dormant-check ()
  "Run the project check and redraw."
  (interactive)
  (org-queue-dormant-check)
  (org-queue-review-refresh))

(defvar-keymap org-queue-review-mode-map
  :doc "Keymap for `org-queue-review-mode'."
  :parent org-queue-mode-map
  "g" #'org-queue-review-refresh
  "y" #'org-queue-still-worth-it
  "w" #'org-queue-review-write
  "D" #'org-queue-review-dormant-check)

(define-derived-mode org-queue-review-mode org-queue-mode "Review"
  "Major mode for the weekly review pack.

\\{org-queue-review-mode-map}")

(provide 'org-queue-review)
;;; org-queue-review.el ends here
