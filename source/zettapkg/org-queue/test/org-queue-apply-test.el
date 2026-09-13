;;; org-queue-apply-test.el --- ERT tests for the write-back atoms -*- lexical-binding: t -*-

;;; Commentary:

;; The writing half.  Each test builds a real Org file in a temp directory,
;; harvests it, applies actions, and reads the file back -- because what
;; matters is what lands on disk.  Needs Org and org-ql, arranged the same
;; way as org-queue-harvest-test.el:
;;
;;   emacs -Q --batch -L source/zettapkg/org-queue \
;;     -l source/zettapkg/org-queue/test/org-queue-apply-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'org)
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(let* ((here (file-name-directory (or load-file-name buffer-file-name)))
       (root (expand-file-name "../../../../" here))
       (builds (expand-file-name "elpaca/builds" root)))
  (when (file-directory-p builds)
    (dolist (dir (directory-files builds t "\\`[^.]"))
      (when (file-directory-p dir) (add-to-list 'load-path dir)))))
(require 'org-queue-apply)

(defconst oqa-entry
  "* TODO Write the thing  :work:
:PROPERTIES:
:ID:       OQA-1
:Effort:   1:00
:END:

* TODO Already scheduled by hand
SCHEDULED: <2026-09-20 Sun>
:PROPERTIES:
:ID:       OQA-2
:Effort:   0:30
:END:
")

(defmacro oqa-with-corpus (&rest forms)
  "Run FORMS with `file' bound to a fresh Org file and a clean apply log."
  (declare (indent 0))
  `(let* ((dir (make-temp-file "oqa-" t))
          (file (expand-file-name "todo.org" dir))
          (org-queue-apply-log-file (expand-file-name "applies.el" dir))
          (org-queue-history-file (expand-file-name "history.el" dir))
          (org-id-locations-file (expand-file-name "ids" dir))
          (org-id-track-globally nil)
          (org-todo-keywords '((sequence "TODO(t!)" "NEXT(N!)" "|" "DONE(d!)")))
          (org-log-reschedule nil)
          (org-log-into-drawer t)
          (inhibit-message t))
     (with-temp-file file (insert oqa-entry))
     (unwind-protect
         (progn ,@forms)
       (when-let* ((buffer (find-buffer-visiting file)))
         (with-current-buffer buffer (set-buffer-modified-p nil))
         (kill-buffer buffer))
       (delete-directory dir t))))

(defun oqa-task (file id)
  "Harvest FILE and return the task with ID."
  (cl-find id (org-queue-harvest (list file) 20260912)
           :key (lambda (task) (plist-get task :id)) :test #'equal))

(defun oqa-property (file id property)
  "Read PROPERTY of the entry ID straight off the file on disk."
  (with-temp-buffer
    (insert-file-contents file)
    (org-mode)
    (goto-char (point-min))
    (re-search-forward (concat ":ID:\\s-+" (regexp-quote id)))
    (org-back-to-heading t)
    (org-entry-get (point) property)))


(ert-deftest oqa/schedule-writes-date-and-placed ()
  (oqa-with-corpus
    (org-queue-apply-actions
     (list (list :action 'schedule :task (oqa-task file "OQA-1")
                 :to 20260915 :placed t)))
    (should (equal "<2026-09-15 Tue>" (oqa-property file "OQA-1" "SCHEDULED")))
    (should (oqa-property file "OQA-1" "PLACED"))
    (should (= 20260915 (plist-get (oqa-task file "OQA-1") :scheduled)))
    (should (plist-get (oqa-task file "OQA-1") :placed))))

(ert-deftest oqa/human-placement-carries-no-stamp ()
  (oqa-with-corpus
    (org-queue-apply-actions
     (list (list :action 'schedule :task (oqa-task file "OQA-1") :to 20260915)))
    (should (equal "<2026-09-15 Tue>" (oqa-property file "OQA-1" "SCHEDULED")))
    (should-not (oqa-property file "OQA-1" "PLACED"))))

(ert-deftest oqa/unschedule-removes-both ()
  (oqa-with-corpus
    (org-queue-apply-actions
     (list (list :action 'schedule :task (oqa-task file "OQA-1")
                 :to 20260915 :placed t)))
    (org-queue-apply-actions
     (list (list :action 'unschedule :task (oqa-task file "OQA-1"))))
    (should-not (oqa-property file "OQA-1" "SCHEDULED"))
    (should-not (oqa-property file "OQA-1" "PLACED"))))

(ert-deftest oqa/undo-restores-what-was-there ()
  (oqa-with-corpus
    (org-queue-apply-actions
     (list (list :action 'schedule :task (oqa-task file "OQA-1")
                 :to 20260915 :placed t)
           (list :action 'schedule :task (oqa-task file "OQA-2")
                 :to 20260916 :placed t)))
    (should (equal "<2026-09-16 Wed>" (oqa-property file "OQA-2" "SCHEDULED")))
    (org-queue-undo-apply)
    (should-not (oqa-property file "OQA-1" "SCHEDULED"))
    (should-not (oqa-property file "OQA-1" "PLACED"))
    ;; The hand-written schedule comes back exactly, and never gains a stamp.
    (should (equal "<2026-09-20 Sun>" (oqa-property file "OQA-2" "SCHEDULED")))
    (should-not (oqa-property file "OQA-2" "PLACED"))
    ;; Undo is logged, so the log has two entries and the second undoes the first.
    (should (= 2 (length (org-queue-apply--log))))))

(ert-deftest oqa/state-change-is-reversible ()
  (oqa-with-corpus
    (org-queue-apply-actions
     (list (list :action 'state :task (oqa-task file "OQA-1") :to "NEXT")))
    (should (equal "NEXT" (plist-get (oqa-task file "OQA-1") :state)))
    (org-queue-undo-apply)
    (should (equal "TODO" (plist-get (oqa-task file "OQA-1") :state)))))

(ert-deftest oqa/a-failing-action-writes-nothing ()
  (oqa-with-corpus
    (should-error
     (org-queue-apply-actions
      (list (list :action 'schedule :task (oqa-task file "OQA-1")
                  :to 20260915 :placed t)
            (list :action 'explode :task (oqa-task file "OQA-2")))))
    (should-not (oqa-property file "OQA-1" "SCHEDULED"))
    (should-not (org-queue-apply--log))))

(ert-deftest oqa/a-dirty-buffer-is-refused ()
  (oqa-with-corpus
    (let ((task (oqa-task file "OQA-1")))
      (with-current-buffer (find-file-noselect file)
        (goto-char (point-max))
        (insert "\n* TODO unsaved\n"))
      (should-error
       (org-queue-apply-actions
        (list (list :action 'schedule :task task :to 20260915 :placed t)))
       :type 'user-error)
      (should-not (oqa-property file "OQA-1" "SCHEDULED")))))

(ert-deftest oqa/harvest-reads-habits ()
  (oqa-with-corpus
    (with-temp-file file
      (insert "* TODO Lift  :body:\nSCHEDULED: <2026-09-12 Sat .+1d>\n:PROPERTIES:\n:ID: H1\n:STYLE: habit\n:Effort: 1:00\n:HABIT_DAYS: Mon Tue Wed Thu Fri Sat\n:END:\n"))
    (let ((habit (oqa-task file "H1")))
      (should (plist-get habit :habit))
      (should (equal '(1 2 3 4 5 6) (plist-get habit :habit-days)))
      (should (= 60 (plist-get habit :effort))))))

(provide 'org-queue-apply-test)
;;; org-queue-apply-test.el ends here
