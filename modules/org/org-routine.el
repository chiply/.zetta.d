;;; org-routine.el --- Configure org-routine -*- lexical-binding: t; -*-

;; Thin wrapper around the in-tree `org-routine' package (under
;; `source/zettapkg/').  The routine table in ~/kb/notes/schedule.org --
;; the prose note, given a `#+NAME: routine' line and three extra
;; columns -- is read by code from here on, and three things follow
;; from it:
;;
;;   - `org-queue-buckets' and `org-queue-capacity' are DERIVED from the
;;     table (focus and dip minutes are work, admin is housekeeping, the
;;     habits have their own buckets).  The hand-written tables in
;;     org-queue.el stay as the fallback when the table is absent or
;;     malformed, and the fallback says so in the echo area.
;;   - `(todo) routine.org' is GENERATED from the rows marked as habits
;;     (`M-x org-routine-generate-habits'); it carries a #+GENERATED line
;;     and the generator refuses to overwrite a file that lacks one.
;;   - the close reads tomorrow's fixed rows, the day log reads the
;;     blocks for its gaps, and the agenda hides @call/@errand/@meeting
;;     outside the admin block when asked (`/' RET in an agenda).
;;
;; The table follows the todo-source toggle: the fixture has its own copy
;; under testdata/routine.org, so a test session derives its buckets from
;; the fixture table rather than the real one.
;;
;; `M-x org-routine-report' shows today's shape.  Part 6 question 1 of
;; composite.org (pomodoros in the dip only, or also block one's first
;; two hours) is `org-routine-dip-first-hours', default nil: the dip only.

(require 'cl-lib)

(defvar zetta-org-todo-source)
(defvar org-queue-close-routine-function)
(defvar org-queue-daylog-blocks-function)
(defvar org-queue-review-expected-function)
(declare-function org-routine-apply-to-queue "org-routine" (&optional quiet))
(declare-function org-routine-routine "org-routine" (&optional force))
(declare-function org-routine-core-fixed "org-routine-core" (routine weekday &optional variant))
(declare-function org-routine-core-active-blocks "org-routine-core" (routine weekday &optional variant))
(declare-function org-routine-core-format-range "org-routine-core" (window))
(declare-function org-routine-variant "org-routine" (&optional date))
(declare-function org-routine-admin-p "org-routine" (&optional time))

(defcustom zetta-org-routine-real-file "~/kb/notes/schedule.org"
  "The routine note in the real kb."
  :type 'file :group 'zetta)

(defcustom zetta-org-routine-test-file
  (expand-file-name "testdata/routine.org" user-emacs-directory)
  "The fixture's copy of the routine table."
  :type 'file :group 'zetta)

(defun zetta-org-routine-file ()
  "Return the routine file for the active (todo) corpus."
  (if (eq (bound-and-true-p zetta-org-todo-source) 'test)
      zetta-org-routine-test-file
    zetta-org-routine-real-file))

(defun zetta-org-routine--weekday (date)
  "Return the weekday of DATE, a YYYYMMDD integer, Sunday 0."
  (nth 6 (decode-time (encode-time 0 0 12 (% date 100) (% (/ date 100) 100) (/ date 10000)))))

(defun zetta-org-routine-fixed-rows (date)
  "Return DATE's fixed rows as strings, for the close."
  (when-let* ((routine (org-routine-routine)))
    (mapcar (lambda (block)
              (format "%s  %s"
                      (org-routine-core-format-range
                       (cons (plist-get block :start) (plist-get block :end)))
                      (plist-get block :label)))
            (org-routine-core-fixed routine (zetta-org-routine--weekday date)
                                    (org-routine-variant date)))))

(defun zetta-org-routine-blocks (date)
  "Return DATE's blocks, for the day log."
  (when-let* ((routine (org-routine-routine)))
    (org-routine-core-active-blocks routine (zetta-org-routine--weekday date)
                                    (org-routine-variant date))))

(defvar org-routine-file)

(defun zetta-org-routine-expected (from to)
  "Return the routine's minutes per bucket over the days FROM to TO, for the pack."
  (when-let* ((routine (org-routine-routine)))
    (let ((day from) expected)
      (while (<= day to)
        (dolist (block (org-routine-core-active-blocks
                        routine (zetta-org-routine--weekday day) (org-routine-variant day)))
          (when (or (memq (plist-get block :kind) '(focus dip admin))
                    (plist-get block :habit))
            (when-let* ((bucket (org-routine-core-bucket-of block)))
              (cl-incf (alist-get bucket expected 0) (plist-get block :minutes)))))
        (setq day (org-routine--date-add day 1)))
      expected)))

(declare-function org-routine-core-bucket-of "org-routine-core" (block))

(defun org-routine--date-add (date days)
  "Return DATE, YYYYMMDD, moved by DAYS."
  (let ((time (encode-time 0 0 12 (% date 100) (% (/ date 100) 100) (/ date 10000))))
    (let ((decoded (decode-time (time-add time (* days 86400)))))
      (+ (* 10000 (nth 5 decoded)) (* 100 (nth 4 decoded)) (nth 3 decoded)))))

(defun zetta-org-routine-follow-source (&rest _)
  "Point org-routine at the active corpus's table and re-derive the buckets."
  (require 'org-routine)
  (setq org-routine-file (zetta-org-routine-file))
  (when (featurep 'org-queue)
    (org-routine-apply-to-queue t)))

(use-package org-routine
  :ensure nil
  :load-path "source/zettapkg/org-routine"
  :commands (org-routine-report org-routine-generate-habits org-routine-apply-to-queue
             org-routine-in-dip-p org-routine-blocks org-routine-windows)
  :init
  (setq org-routine-file (zetta-org-routine-file))
  ;; The queue's tables are derived at the end of org-queue.el's :config
  ;; (which calls `zetta-org-routine-follow-source' after its own `setq',
  ;; the fallback), and again whenever the corpus toggles.  Here only the
  ;; readers the close and the day log call are handed over.
  (with-eval-after-load 'org-queue
    (require 'org-routine)
    (setq org-queue-close-routine-function #'zetta-org-routine-fixed-rows
          org-queue-daylog-blocks-function #'zetta-org-routine-blocks
          org-queue-review-expected-function #'zetta-org-routine-expected))
  (advice-add 'zetta-org-toggle-todo-source :after #'zetta-org-routine-follow-source))

;; Hide the contexts that need the outside world when the routine says
;; this is not their hour.  Only when asked: `/' RET in an agenda runs
;; `org-agenda-auto-exclude-function' over the tags, so the Day view is
;; unchanged until you filter it.
(defun zetta-org-agenda-auto-exclude (tag)
  "Return the filter string for TAG when TAG cannot be done right now."
  (when (and (member tag '("@call" "@errand" "@meeting"))
             (fboundp 'org-routine-admin-p)
             (not (org-routine-admin-p)))
    (concat "-" tag)))

(with-eval-after-load 'org-agenda
  (setq org-agenda-auto-exclude-function #'zetta-org-agenda-auto-exclude))
;;; org-routine.el ends here
