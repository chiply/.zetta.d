;;; org-routine.el --- Read the routine table and hand it to the queue -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The Org half of org-routine.  It finds the named tables in the routine
;; note, parses them with `org-routine-core', and answers the questions
;; the rest of the config asks:
;;
;;   `org-routine-routine'          the parsed routine, cached by mtime
;;   `org-routine-blocks'           today's blocks
;;   `org-routine-in-dip-p'         is now inside the dip
;;   `org-routine-windows'          the kick, review and quiet windows
;;   `org-routine-apply-to-queue'   derive `org-queue-buckets' and
;;                                  `org-queue-capacity' from the table
;;   `org-routine-generate-habits'  write `(todo) routine.org' from the
;;                                  rows marked as habits
;;   `org-routine-report'           the day's shape, in a buffer
;;
;; The note is the user's prose (`~/kb/notes/schedule.org'); only a table
;; with `#+NAME: routine' is read, and the file is never written.  The
;; habits file IS written -- generated, never hand-edited: it starts with
;; a `#+GENERATED' line and the generator refuses to overwrite a file
;; that lacks one.  IDs are kept across regenerations by title, so the
;; queue's history keeps meaning something.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-id)
(require 'org-routine-core)

(defvar org-queue-buckets)
(defvar org-queue-capacity)
(defvar org-queue-slack-fraction)

(defcustom org-routine-file "~/kb/notes/schedule.org"
  "The note holding the routine table."
  :type 'file
  :group 'org-routine)

(defcustom org-routine-table-name "routine"
  "The `#+NAME:' of the routine table in `org-routine-file'."
  :type 'string
  :group 'org-routine)

(defcustom org-routine-variants-table-name "variants"
  "The `#+NAME:' of the variants table, when there is one."
  :type 'string
  :group 'org-routine)

(defcustom org-routine-habits-file nil
  "Where the generated habits file is written.
Nil means `(todo) routine.org' beside the first agenda file."
  :type '(choice (const nil) file)
  :group 'org-routine)

(defcustom org-routine-bucket-matches
  '((work         . (:category ("work" "emacs" "cal")))
    (reading      . (:tags ("reading") :category ("learn")))
    (body         . (:tags ("body")))
    (housekeeping . (:tags ("housekeeping") :category ("home" "buy"))))
  "How each derived bucket claims tasks; see `org-queue-buckets'.
The table says how many minutes a bucket has; this says which tasks
belong in it, which the table cannot know."
  :type '(alist :key-type symbol :value-type plist)
  :group 'org-routine)

(defcustom org-routine-variant-days nil
  "Alist of (YYYYMMDD . VARIANT-NAME): which days run a variant."
  :type '(alist :key-type integer :value-type string)
  :group 'org-routine)

(defvar org-routine--cache nil
  "(FILE MTIME . ROUTINE) of the last parse.")


;;;; Reading the tables

(defun org-routine--table-text (name)
  "Return the text of the table named NAME in the current buffer, or nil."
  (save-excursion
    (save-restriction
      (widen)
      (goto-char (point-min))
      (when (re-search-forward (format "^[ \t]*#\\+NAME:[ \t]*%s[ \t]*$" (regexp-quote name))
                               nil t)
        (forward-line 1)
        (while (and (not (eobp)) (looking-at-p "^[ \t]*#\\+")) (forward-line 1))
        (when (looking-at-p "^[ \t]*|")
          (let ((start (point)))
            (while (and (not (eobp)) (looking-at-p "^[ \t]*|")) (forward-line 1))
            (buffer-substring-no-properties start (point))))))))

(defun org-routine-read (&optional file)
  "Parse the routine and variants tables in FILE and return the routine.
Signals an error naming the table and line when the table is malformed;
returns nil when FILE does not exist or has no routine table."
  (let ((file (expand-file-name (or file org-routine-file))))
    (when (file-readable-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (let ((routine (org-routine--table-text org-routine-table-name))
              (variants (org-routine--table-text org-routine-variants-table-name)))
          (when routine
            (org-routine-core-make
             (org-routine-core-parse routine org-routine-table-name)
             (and variants
                  (org-routine-core-parse variants org-routine-variants-table-name)))))))))

(defun org-routine-routine (&optional force)
  "Return the parsed routine, re-reading the file when it changed.
With FORCE, re-read regardless."
  (let* ((file (expand-file-name org-routine-file))
         (mtime (and (file-readable-p file)
                     (file-attribute-modification-time (file-attributes file)))))
    (if (and (not force) org-routine--cache
             (equal (car org-routine--cache) file)
             (equal (cadr org-routine--cache) mtime))
        (cddr org-routine--cache)
      (let ((routine (org-routine-read file)))
        (setq org-routine--cache (cons file (cons mtime routine)))
        routine))))


;;;; Today's questions

(defun org-routine--date (&optional time)
  "Return TIME as a YYYYMMDD integer."
  (let ((decoded (decode-time (or time (current-time)))))
    (+ (* 10000 (nth 5 decoded)) (* 100 (nth 4 decoded)) (nth 3 decoded))))

(defun org-routine--weekday (&optional time)
  "Return the weekday of TIME, Sunday 0."
  (nth 6 (decode-time (or time (current-time)))))

(defun org-routine--minute (&optional time)
  "Return the minute of the day of TIME."
  (let ((decoded (decode-time (or time (current-time)))))
    (+ (* 60 (nth 2 decoded)) (nth 1 decoded))))

(defun org-routine-variant (&optional date)
  "Return the variant DATE (YYYYMMDD, default today) runs, or nil."
  (alist-get (or date (org-routine--date)) org-routine-variant-days))

(defun org-routine-blocks (&optional time)
  "Return the routine's blocks for the day of TIME (default now)."
  (when-let* ((routine (org-routine-routine)))
    (org-routine-core-active-blocks routine (org-routine--weekday time)
                                    (org-routine-variant (org-routine--date time)))))

(defun org-routine-in-dip-p (&optional time)
  "Return non-nil when TIME (default now) falls inside the dip."
  (when-let* ((routine (org-routine-routine)))
    (org-routine-core-in-dip-p routine (org-routine--weekday time)
                               (org-routine--minute time)
                               (org-routine-variant (org-routine--date time)))))

(defun org-routine-block-at (&optional time)
  "Return the block containing TIME (default now), or nil."
  (when-let* ((routine (org-routine-routine)))
    (org-routine-core-block-at routine (org-routine--weekday time)
                               (org-routine--minute time)
                               (org-routine-variant (org-routine--date time)))))

(defun org-routine-windows (&optional time)
  "Return the kick, review and quiet windows for the day of TIME."
  (when-let* ((routine (org-routine-routine)))
    (org-routine-core-windows routine (org-routine--weekday time)
                              (org-routine-variant (org-routine--date time)))))

(defun org-routine-in-window-p (kind &optional time)
  "Return non-nil when TIME falls in a window of KIND (:kick :review :quiet)."
  (when-let* ((windows (org-routine-windows time)))
    (org-routine-core-in-window-p (plist-get windows kind)
                                  (org-routine--minute time))))

(defun org-routine-admin-p (&optional time)
  "Return non-nil when TIME falls in an admin block."
  (eq 'admin (plist-get (org-routine-block-at time) :kind)))


;;;; Handing the table to the queue

(defvar org-routine--queue-fallback nil
  "The bucket and capacity tables the config set by hand, kept as a fallback.")

(defun org-routine-apply-to-queue (&optional quiet)
  "Derive `org-queue-buckets' and `org-queue-capacity' from the table.

When the table is absent or malformed the hand-written tables stay in
force and the reason is reported.  Returns non-nil when the table was
applied.  With QUIET, no message."
  (interactive)
  (unless org-routine--queue-fallback
    (setq org-routine--queue-fallback
          (list (bound-and-true-p org-queue-buckets)
                (bound-and-true-p org-queue-capacity))))
  (condition-case err
      (let ((routine (org-routine-routine t)))
        (if (not routine)
            (progn
              (unless quiet
                (message "org-routine: no %s table in %s; keeping the hand-written buckets"
                         org-routine-table-name org-routine-file))
              (setq org-queue-buckets (nth 0 org-routine--queue-fallback)
                    org-queue-capacity (nth 1 org-routine--queue-fallback))
              nil)
          (setq org-queue-buckets
                (org-routine-core-buckets routine
                                          (bound-and-true-p org-queue-slack-fraction)
                                          nil org-routine-bucket-matches)
                org-queue-capacity
                (mapcar (lambda (weekday)
                          (cons weekday (org-routine-core-discretionary routine weekday)))
                        '(0 1 2 3 4 5 6)))
          (unless quiet
            (message "org-routine: %d buckets derived from %s"
                     (length org-queue-buckets)
                     (file-name-nondirectory org-routine-file)))
          t))
    (error
     (setq org-queue-buckets (nth 0 org-routine--queue-fallback)
           org-queue-capacity (nth 1 org-routine--queue-fallback))
     (message "org-routine: %s; keeping the hand-written buckets"
              (error-message-string err))
     nil)))


;;;; The generated habits file

(defconst org-routine-generated-marker "#+GENERATED:"
  "The first line of a file this package may overwrite.")

(defun org-routine--habits-file ()
  "Return the path of the habits file."
  (expand-file-name
   (or org-routine-habits-file
       (expand-file-name "(todo) routine.org"
                         (if (and (boundp 'org-agenda-files) org-agenda-files
                                  (stringp (car org-agenda-files)))
                             (file-name-directory (car org-agenda-files))
                           "~/kb/todo/")))))

(defun org-routine--existing-ids (file)
  "Return an alist of (TITLE . ID) for the entries in FILE, if it exists."
  (when (file-readable-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (org-mode)
      (let (ids)
        (org-map-entries
         (lambda ()
           (when-let* ((id (org-entry-get (point) "ID")))
             (push (cons (org-get-heading t t t t) id) ids)))
         nil 'file)
        ids))))

(defun org-routine--weekday-names (days)
  "Return DAYS, weekday numbers, as HABIT_DAYS text."
  (mapconcat (lambda (day) (nth day '("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat")))
             days " "))

(defun org-routine-habits-text (routine &optional ids today category)
  "Return the text of the habits file for ROUTINE.
IDS is an alist of (TITLE . ID) to keep; TODAY the date the repeater
starts from; CATEGORY the file's category."
  (let ((today (or today (org-routine--date)))
        (stamp (format-time-string "[%Y-%m-%d %a %H:%M]")))
    (concat
     (format "%s by org-routine from %s, %s -- do not edit; edit the table\n"
             org-routine-generated-marker
             (file-name-nondirectory org-routine-file) stamp)
     "#+TITLE: Routine\n"
     (format "#+CATEGORY: %s\n" (or category "routine"))
     "#+FILETAGS: :routine:\n\n"
     (mapconcat
      (lambda (habit)
        (let* ((title (plist-get habit :title))
               (id (or (alist-get title ids nil nil #'equal)
                       (org-id-new)))
               (bucket (plist-get habit :bucket)))
          (concat
           (format "* TODO %s%s\n" title
                   (if bucket (format "  :%s:" bucket) ""))
           (format "SCHEDULED: <%d-%02d-%02d %s .+1d>\n"
                   (/ today 10000) (% (/ today 100) 100) (% today 100)
                   (nth (org-routine--weekday-of-date today)
                        '("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat")))
           ":PROPERTIES:\n"
           (format ":ID:       %s\n" id)
           ":STYLE:    habit\n"
           (format ":Effort:   %d:%02d\n" (/ (plist-get habit :minutes) 60)
                   (% (plist-get habit :minutes) 60))
           (format ":ROUTINE_AT: %s\n"
                   (org-routine-core-format-range
                    (cons (plist-get habit :start) (plist-get habit :end))))
           (if (plist-get habit :days)
               (format ":HABIT_DAYS: %s\n" (org-routine--weekday-names (plist-get habit :days)))
             "")
           ":END:\n")))
      (org-routine-core-habit-entries routine)
      "\n"))))

(defun org-routine--weekday-of-date (date)
  "Return the weekday of DATE, a YYYYMMDD integer, Sunday 0."
  (let* ((y (/ date 10000)) (m (% (/ date 100) 100)) (d (% date 100)))
    (nth 6 (decode-time (encode-time 0 0 12 d m y)))))

;;;###autoload
(defun org-routine-generate-habits (&optional file)
  "Write the habits file from the routine table's habit rows.

Refuses to overwrite FILE unless its first line is the generated
marker, so a hand-written routine file is never clobbered.  IDs are
kept by title across regenerations."
  (interactive)
  (let* ((routine (or (org-routine-routine t)
                      (user-error "No %s table in %s" org-routine-table-name org-routine-file)))
         (file (or file (org-routine--habits-file))))
    (when (and (file-exists-p file)
               (not (with-temp-buffer
                      (insert-file-contents file nil 0 200)
                      (goto-char (point-min))
                      (looking-at-p (regexp-quote org-routine-generated-marker)))))
      (user-error "%s exists and was not generated; move it aside first" file))
    (when-let* ((buffer (find-buffer-visiting file)))
      (when (buffer-modified-p buffer)
        (user-error "%s has unsaved changes" (buffer-name buffer))))
    (let ((text (org-routine-habits-text routine (org-routine--existing-ids file))))
      (with-temp-file file (insert text))
      (when-let* ((buffer (find-buffer-visiting file)))
        (with-current-buffer buffer (revert-buffer t t t)))
      (message "Wrote %d habits to %s"
               (length (org-routine-core-habits routine))
               (file-name-nondirectory file))
      file)))


;;;; The report

;;;###autoload
(defun org-routine-report (&optional time)
  "Show the routine's shape for the day of TIME (default today)."
  (interactive)
  (let* ((routine (or (org-routine-routine t)
                      (user-error "No %s table in %s" org-routine-table-name org-routine-file)))
         (weekday (org-routine--weekday time))
         (variant (org-routine-variant (org-routine--date time)))
         (buffer (get-buffer-create "*org-routine*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (special-mode)
        (insert (propertize (format "%s%s\n"
                                    (format-time-string "%A" (or time (current-time)))
                                    (if variant (format " (%s)" variant) ""))
                            'face 'bold))
        (dolist (line (org-routine-core-report
                       routine weekday (bound-and-true-p org-queue-slack-fraction) variant))
          (insert line "\n"))
        (let ((windows (org-routine-core-windows routine weekday variant)))
          (insert (propertize "\nwindows\n" 'face 'bold))
          (dolist (kind '(:kick :review :quiet))
            (insert (format "  %-7s %s\n" (substring (symbol-name kind) 1)
                            (mapconcat #'org-routine-core-format-range
                                       (plist-get windows kind) "  ")))))
        (insert (propertize "\ndip\n" 'face 'bold))
        (insert (format "  %s\n" (mapconcat #'org-routine-core-format-range
                                            (org-routine-core-dip routine weekday variant)
                                            "  ")))
        (goto-char (point-min))))
    (pop-to-buffer buffer)))

(provide 'org-routine)
;;; org-routine.el ends here
