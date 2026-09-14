;;; org-knowledge-test.el --- ERT tests for org-knowledge -*- lexical-binding: t -*-

;;; Commentary:

;; The core in batch, and the promotion over a temp directory standing in
;; for the wiki.  Run with:
;;
;;   emacs -Q --batch -L source/zettapkg/org-knowledge \
;;     -l source/zettapkg/org-knowledge/test/org-knowledge-test.el \
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
(require 'org-knowledge)


;;;; The core

(ert-deftest okt/titles-become-wikiwords ()
  (should (equal "TheRetrievalService" (org-knowledge-core-wikiword "the retrieval service")))
  (should (equal "OrderlessNotWorking" (org-knowledge-core-wikiword "orderless not working?")))
  (should (equal "Hyperbole" (org-knowledge-core-wikiword "Hyperbole")))
  (should (equal "FavouriteProblems" (org-knowledge-core-wikiword "FavouriteProblems")))
  (should (org-knowledge-core-wikiword-p "TheRetrievalService"))
  (should (org-knowledge-core-wikiword-p "Hyperbole"))     ; the config's own pages
  (should-not (org-knowledge-core-wikiword-p "hyperbole"))
  (should-not (org-knowledge-core-wikiword-p "the thing")))

(ert-deftest okt/the-page-text-has-a-title-line-once-and-appends ()
  (let ((fresh (org-knowledge-core-page-text "TheThing" "the body\n")))
    (should (string-prefix-p "#+title: TheThing\n" fresh))
    (let ((again (org-knowledge-core-page-text "TheThing" "more" fresh)))
      (should (= 1 (cl-count "#+title:" (split-string again "\n") :test #'string-prefix-p)))
      (should (string-suffix-p "the body\n\nmore\n" again)))))

(ert-deftest okt/the-source-line-is-the-link-then-the-reason-and-an-empty-reason-fails ()
  (should (equal "[[hy:TheThing]] Because it is where the argument lives."
                 (org-knowledge-core-source-line "TheThing" "Because it is where the argument lives")))
  (should (equal "[[hy:TheThing]] Already a sentence."
                 (org-knowledge-core-source-line "TheThing" "Already a sentence.")))
  (should-error (org-knowledge-core-source-line "TheThing" "  ")))

(ert-deftest okt/resurface-never-returns-a-page-touched-within-n-days ()
  (let* ((org-knowledge-resurface-days 30)
         (pages (list (list :word "Old" :touched 20260601)
                      (list :word "Older" :touched 20260301)
                      (list :word "Fresh" :touched 20260910)))
         (untouched (org-knowledge-core-untouched pages 20260912)))
    (should (equal '("Older" "Old") (mapcar (lambda (p) (plist-get p :word)) untouched)))))

(ert-deftest okt/on-this-day-looks-a-year-and-a-month-back ()
  (should (equal '(20250912 20260812) (org-knowledge-core-on-this-day 20260912)))
  (should (equal '(20250131 20251231) (org-knowledge-core-on-this-day 20260131)))
  (should (equal '(20250331 20260228) (org-knowledge-core-on-this-day 20260331))))


;;;; Promotion over files

(defmacro okt-with-wiki (&rest forms)
  (declare (indent 0))
  `(let* ((dir (make-temp-file "okt-" t))
          (org-knowledge-directory (expand-file-name "wiki" dir))
          (source (expand-file-name "inbox.org" dir))
          (inhibit-message t))
     (with-temp-file source
       (insert "* a note about the thing\n:PROPERTIES:\n:CREATED: [2026-09-01 Tue]\n:END:\nThe body, verbatim.\n  Indented too.\n\n* another\n"))
     (unwind-protect
         (progn ,@forms)
       (dolist (buffer (buffer-list))
         (when (and (buffer-file-name buffer) (string-prefix-p dir (buffer-file-name buffer)))
           (with-current-buffer buffer (set-buffer-modified-p nil))
           (kill-buffer buffer)))
       (delete-directory dir t))))

(ert-deftest okt/promoting-makes-a-titled-page-moves-the-body-and-leaves-one-link ()
  (okt-with-wiki
    (with-current-buffer (find-file-noselect source)
      (goto-char (point-min))
      (org-knowledge-promote "TheThing" "it is the argument")
      (save-buffer))
    (let ((page (expand-file-name "TheThing.org" org-knowledge-directory)))
      (should (file-exists-p page))
      (with-temp-buffer
        (insert-file-contents page)
        (should (string-prefix-p "#+title: TheThing\n" (buffer-string)))
        (should (string-match-p "^The body, verbatim\\.\n  Indented too\\." (buffer-string)))))
    (with-temp-buffer
      (insert-file-contents source)
      (let ((text (buffer-string)))
        (should (= 1 (cl-count "[[hy:TheThing]]" (split-string text "\n") :test #'string-prefix-p)))
        (should (string-match-p "^\\[\\[hy:TheThing\\]\\] it is the argument\\.$" text))
        (should-not (string-match-p "The body, verbatim" text))
        ;; The heading and the other entry are untouched.
        (should (string-match-p "^\\* a note about the thing" text))
        (should (string-match-p "^\\* another" text))))))

(ert-deftest okt/an-empty-reason-fails-before-anything-is-written ()
  (okt-with-wiki
    (with-current-buffer (find-file-noselect source)
      (goto-char (point-min))
      (should-error (org-knowledge-promote "TheThing" ""))
      (should-not (buffer-modified-p)))
    (should-not (file-exists-p (expand-file-name "TheThing.org" org-knowledge-directory)))))

(ert-deftest okt/a-second-promotion-appends-rather-than-overwrites ()
  (okt-with-wiki
    (with-current-buffer (find-file-noselect source)
      (goto-char (point-min))
      (org-knowledge-promote "TheThing" "first")
      (save-buffer)
      (goto-char (point-min))
      (re-search-forward "^\\* another")
      (insert "\nSecond body.")
      (org-knowledge-promote "TheThing" "second")
      (save-buffer))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "TheThing.org" org-knowledge-directory))
      (should (= 1 (cl-count "#+title:" (split-string (buffer-string) "\n") :test #'string-prefix-p)))
      (should (string-match-p "The body, verbatim" (buffer-string)))
      (should (string-match-p "Second body" (buffer-string))))))

(ert-deftest okt/the-favourite-problems-are-the-page-headings ()
  (okt-with-wiki
    (make-directory org-knowledge-directory t)
    (with-temp-file (expand-file-name "FavouriteProblems.org" org-knowledge-directory)
      (insert "#+title: FavouriteProblems\n\n* How do I make the plan honest?\n* Where does time go?\n"))
    (should (equal '("How do I make the plan honest?" "Where does time go?")
                   (org-knowledge-problems)))))

(provide 'org-knowledge-test)
;;; org-knowledge-test.el ends here
