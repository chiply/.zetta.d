;;; org-queue-rituals-test.el --- ERT tests for the close and the project check over files -*- lexical-binding: t -*-

;;; Commentary:

;; The Org side of wave 1: a real corpus in a temp directory, the dormant
;; check writing tags through the apply layer, the close reading the
;; history and stamping it.  Needs Org and org-ql, arranged as
;; org-queue-apply-test.el does:
;;
;;   emacs -Q --batch -L source/zettapkg/org-queue \
;;     -l source/zettapkg/org-queue/test/org-queue-rituals-test.el \
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
(require 'org-queue-close)
(require 'org-queue-dormant)

(defconst oqr-corpus
  "#+CATEGORY: test

* TODO Live project
:PROPERTIES:
:ID:       P-LIVE
:END:
** TODO A next step
:PROPERTIES:
:ID:       P-LIVE-1
:Effort:   0:30
:END:
** DONE Something finished

* TODO Dormant project
:PROPERTIES:
:ID:       P-DORMANT
:END:
** DONE All done here
** HOLD Parked child
:PROPERTIES:
:ID:       P-DORMANT-1
:END:

* TODO Finished project
:PROPERTIES:
:ID:       P-FINISHED
:END:
** DONE One
** NOPE Two

* TODO Blocked-in project
:PROPERTIES:
:ID:       P-BLOCK
:END:
<2026-09-15 Tue 10:00-12:00>
** DONE Old step

* TODO Standalone task
:PROPERTIES:
:ID:       T-1
:Effort:   0:30
:END:

* DONE Finished today
CLOSED: [2026-09-12 Sat 16:00]
:PROPERTIES:
:ID:       T-DONE
:Effort:   0:20
:END:
:LOGBOOK:
- State \"DONE\"       from \"PROG\"       [2026-09-12 Sat 16:00]
- State \"PROG\"       from \"TODO\"       [2026-09-12 Sat 15:00]
:END:

* PROG Still going
:PROPERTIES:
:ID:       T-PROG
:Effort:   1:00
:END:
:LOGBOOK:
- State \"PROG\"       from \"TODO\"       [2026-09-12 Sat 14:00]
:END:
")

(defmacro oqr-with-corpus (&rest forms)
  "Run FORMS with `file' bound to a fresh corpus and clean state files."
  (declare (indent 0))
  `(let* ((dir (make-temp-file "oqr-" t))
          (file (expand-file-name "todo.org" dir))
          (org-queue-files (list file))
          (org-queue-apply-log-file (expand-file-name "applies.el" dir))
          (org-queue-history-file (expand-file-name "history.el" dir))
          (org-queue-inbox-file nil)
          (org-id-locations-file (expand-file-name "ids" dir))
          (org-id-track-globally nil)
          (org-todo-keywords '((sequence "TODO(t!)" "NEXT(N!)" "PROG(p!)" "WAIT(w!)" "HOLD(h!)" "|" "DONE(d!)" "NOPE(n!)")))
          (org-log-reschedule nil)
          (org-log-into-drawer t)
          (org-queue-buckets nil)
          (org-queue-capacity '((0 . 300) (1 . 300) (2 . 300) (3 . 300) (4 . 300) (5 . 300) (6 . 300)))
          (org-queue-calibrate nil)
          (inhibit-message t))
     (with-temp-file file (insert oqr-corpus))
     (unwind-protect
         (progn ,@forms)
       (when-let* ((buffer (find-buffer-visiting file)))
         (with-current-buffer buffer (set-buffer-modified-p nil))
         (kill-buffer buffer))
       (delete-directory dir t))))

(defun oqr-status (file id)
  "Return the dormant status of the project ID in FILE."
  (cl-find id (org-queue-dormant-projects (list file))
           :key (lambda (project) (plist-get (plist-get project :task) :id)) :test #'equal))

(defun oqr-tags (file id)
  (with-temp-buffer
    (insert-file-contents file)
    (org-mode)
    (goto-char (point-min))
    (re-search-forward (concat ":ID:\\s-+" (regexp-quote id)))
    (org-back-to-heading t)
    (org-get-tags nil t)))


;;;; The project invariant

(ert-deftest oqr/a-project-with-an-open-child-is-live ()
  (oqr-with-corpus
    (should (eq 'live (plist-get (oqr-status file "P-LIVE") :status)))))

(ert-deftest oqr/all-children-done-or-parked-is-dormant-and-gets-the-tag ()
  (oqr-with-corpus
    (should (eq 'dormant (plist-get (oqr-status file "P-DORMANT") :status)))
    (org-queue-dormant-check (list file) t)
    (should (member "dormant" (oqr-tags file "P-DORMANT")))
    (should-not (member "dormant" (oqr-tags file "P-LIVE")))))

(ert-deftest oqr/all-children-done-is-finished ()
  (oqr-with-corpus
    (should (eq 'finished (plist-get (oqr-status file "P-FINISHED") :status)))))

(ert-deftest oqr/a-timestamp-inside-the-window-keeps-a-project-live ()
  (oqr-with-corpus
    ;; The fixture's block is on 2026-09-15; the check reads today, so
    ;; pin the window wide enough to reach it whenever this runs.
    (let ((org-queue-dormant-days 100000))
      (should (eq 'live (plist-get (oqr-status file "P-BLOCK") :status))))
    (let ((org-queue-dormant-days 0))
      (should (eq 'finished (plist-get (oqr-status file "P-BLOCK") :status))))))

(ert-deftest oqr/standalone-tasks-are-not-projects ()
  (oqr-with-corpus
    (should-not (oqr-status file "T-1"))))

(ert-deftest oqr/adding-a-todo-child-clears-the-tag-on-the-next-check ()
  (oqr-with-corpus
    (org-queue-dormant-check (list file) t)
    (should (member "dormant" (oqr-tags file "P-DORMANT")))
    (with-current-buffer (find-file-noselect file)
      (goto-char (point-min))
      (re-search-forward ":ID:\\s-+P-DORMANT-1")
      (org-end-of-subtree t t)
      (insert "** TODO A new next step\n")
      (save-buffer))
    (org-queue-dormant-check (list file) t)
    (should-not (member "dormant" (oqr-tags file "P-DORMANT")))
    ;; Two applies: the tag on, the tag off.  A third check changes nothing.
    (should (= 2 (length (org-queue-apply--log))))
    (org-queue-dormant-check (list file) t)
    (should (= 2 (length (org-queue-apply--log))))))

(ert-deftest oqr/children-of-a-dormant-project-are-dropped-by-the-packer ()
  (oqr-with-corpus
    (with-current-buffer (find-file-noselect file)
      (goto-char (point-min))
      (re-search-forward ":ID:\\s-+P-DORMANT-1")
      (org-end-of-subtree t t)
      (insert "** TODO Stale child\n:PROPERTIES:\n:ID: P-DORMANT-2\n:Effort: 0:10\n:END:\n")
      (save-buffer))
    ;; The check has not run since the child appeared: the parent still
    ;; wears its tag from an earlier check, so the child is dropped.
    (with-current-buffer (find-file-noselect file)
      (goto-char (point-min))
      (re-search-forward ":ID:\\s-+P-DORMANT$")
      (org-back-to-heading t)
      (org-set-tags '("dormant"))
      (save-buffer))
    (let* ((plan (org-queue-plan 20260912))
           (dropped (cl-find "P-DORMANT-2" (plist-get plan :dropped)
                             :key (lambda (cell) (plist-get (car cell) :id)) :test #'equal)))
      (should dropped)
      (should (eq 'dormant-project (cdr dropped))))))


;;;; The close

(ert-deftest oqr/the-close-reads-the-plan-history-and-stamps-it ()
  (oqr-with-corpus
    (org-queue-record-plan (list :date 20260912
                                 :planned (list (list :id "T-1") (list :id "T-DONE")
                                                (list :id "T-PROG"))))
    (let ((close (org-queue-close-compute 20260912)))
      (should (equal '("T-1" "T-PROG")
                     (mapcar (lambda (task) (plist-get task :id)) (plist-get close :unfinished))))
      (should (equal '("T-DONE")
                     (mapcar (lambda (task) (plist-get task :id)) (plist-get close :done))))
      (should (equal '("T-PROG")
                     (mapcar (lambda (task) (plist-get task :id)) (plist-get close :prog))))
      (should-not (plist-get close :already-closed)))
    (let ((first (org-queue-close-record 20260912 '("T-1" "T-PROG"))))
      (should first)
      ;; Closing again keeps the first stamp.
      (should (equal first (org-queue-close-record 20260912 '("T-1"))))
      (should (equal first (plist-get (org-queue-close-compute 20260912) :already-closed))))))

(ert-deftest oqr/the-close-counts-interruptions-from-the-inbox ()
  (oqr-with-corpus
    (let ((inbox (expand-file-name "inbox.org" dir)))
      (with-temp-file inbox
        (insert "* a thought\n:PROPERTIES:\n:CREATED: [2026-09-12 Sat 14:20]\n:INTERRUPTED: T-PROG\n:END:\n* another\n:PROPERTIES:\n:INTERRUPTED: T-PROG\n:END:\n* unrelated\n"))
      (let* ((org-queue-inbox-file inbox)
             (close (org-queue-close-compute 20260912)))
        (should (= 3 (plist-get close :inbox-count)))
        (should (= 2 (plist-get (car (plist-get close :prog)) :interruptions)))))))

(provide 'org-queue-rituals-test)
;;; org-queue-rituals-test.el ends here
