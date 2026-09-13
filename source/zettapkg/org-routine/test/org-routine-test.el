;;; org-routine-test.el --- ERT tests for the Org half of org-routine -*- lexical-binding: t -*-

;;; Commentary:

;; Reads the fixture table from a file, generates the habits file, and
;; reads it back through org-queue's harvest.  Needs Org and org-ql:
;;
;;   emacs -Q --batch -L source/zettapkg/org-routine -L source/zettapkg/org-queue \
;;     -l source/zettapkg/org-routine/test/org-routine-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'org)
(let* ((here (file-name-directory (or load-file-name buffer-file-name)))
       (root (expand-file-name "../../../../" here))
       (builds (expand-file-name "elpaca/builds" root)))
  (add-to-list 'load-path (expand-file-name ".." here))
  (add-to-list 'load-path (expand-file-name "source/zettapkg/org-queue" root))
  (when (file-directory-p builds)
    (dolist (dir (directory-files builds t "\\`[^.]"))
      (when (file-directory-p dir) (add-to-list 'load-path dir)))))
(require 'org-routine)
(require 'org-queue-harvest)

(defconst orx-fixture
  (expand-file-name "../../../../testdata/routine.org"
                    (file-name-directory (or load-file-name buffer-file-name))))

(defmacro orx-with-dir (&rest forms)
  "Run FORMS with `dir' bound to a temp directory, cleaned up afterwards."
  (declare (indent 0))
  `(let* ((dir (make-temp-file "orx-" t))
          (org-routine-file orx-fixture)
          (org-routine--cache nil)
          (org-id-locations-file (expand-file-name "ids" dir))
          (org-id-track-globally nil)
          (org-queue-history-file (expand-file-name "history.el" dir))
          (inhibit-message t))
     (unwind-protect
         (progn ,@forms)
       (dolist (buffer (buffer-list))
         (when (and (buffer-file-name buffer)
                    (string-prefix-p dir (buffer-file-name buffer)))
           (with-current-buffer buffer (set-buffer-modified-p nil))
           (kill-buffer buffer)))
       (delete-directory dir t))))

(ert-deftest orx/the-fixture-table-reads-from-the-file ()
  (orx-with-dir
    (let ((routine (org-routine-routine t)))
      (should routine)
      (should (= 570 (org-routine-core-discretionary routine 1)))
      (should (= 1 (length (plist-get routine :variants)))))))

(ert-deftest orx/a-file-without-the-table-yields-nil ()
  (orx-with-dir
    (let ((other (expand-file-name "other.org" dir)))
      (with-temp-file other (insert "* Nothing here\n"))
      (let ((org-routine-file other))
        (should-not (org-routine-routine t))))))

(ert-deftest orx/apply-to-queue-derives-buckets-and-keeps-a-fallback ()
  (orx-with-dir
    (let ((org-queue-buckets '((default :minutes 10)))
          (org-queue-capacity '((1 . 10)))
          (org-queue-slack-fraction 0.2)
          (org-routine--queue-fallback nil))
      (should (org-routine-apply-to-queue t))
      (should (alist-get 'work org-queue-buckets))
      (should (= 570 (alist-get 1 org-queue-capacity)))
      (let ((org-routine-file (expand-file-name "missing.org" dir)))
        (should-not (org-routine-apply-to-queue t))
        (should (equal '((default :minutes 10)) org-queue-buckets))))))

(ert-deftest orx/the-generated-habits-round-trip-through-the-harvest ()
  (orx-with-dir
    (let* ((file (expand-file-name "(todo) routine.org" dir))
           (org-routine-habits-file file))
      (org-routine-generate-habits)
      (let ((habits (cl-remove-if-not (lambda (task) (plist-get task :habit))
                                      (org-queue-harvest (list file) 20260912))))
        (should (= 5 (length habits)))
        (let ((lift (cl-find "Lift weights" habits
                             :key (lambda (task) (plist-get task :title)) :test #'equal)))
          (should (equal '(1 2 3 4 5 6) (plist-get lift :habit-days)))
          (should (= 60 (plist-get lift :effort)))
          (should (member "body" (plist-get lift :tags))))
        (let ((laundry (cl-find "Laundry" habits
                                :key (lambda (task) (plist-get task :title)) :test #'equal)))
          (should (equal '(6) (plist-get laundry :habit-days))))
        (should-not (plist-get (cl-find "Read" habits
                                        :key (lambda (task) (plist-get task :title))
                                        :test #'equal)
                               :habit-days))))))

(ert-deftest orx/regenerating-keeps-ids-by-title ()
  (orx-with-dir
    (let* ((file (expand-file-name "(todo) routine.org" dir))
           (org-routine-habits-file file))
      (org-routine-generate-habits)
      (let ((before (org-routine--existing-ids file)))
        (org-routine-generate-habits)
        (should (equal before (org-routine--existing-ids file)))))))

(ert-deftest orx/a-hand-written-file-is-never-overwritten ()
  (orx-with-dir
    (let* ((file (expand-file-name "(todo) routine.org" dir))
           (org-routine-habits-file file))
      (with-temp-file file (insert "* TODO My own habit\n"))
      (should-error (org-routine-generate-habits) :type 'user-error)
      (with-temp-buffer
        (insert-file-contents file)
        (should (equal "* TODO My own habit\n" (buffer-string)))))))

(provide 'org-routine-test)
;;; org-routine-test.el ends here
