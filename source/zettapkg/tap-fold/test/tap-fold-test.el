;;; tap-fold-test.el --- ERT smoke tests for tap-fold -*- lexical-binding: t -*-

(require 'ert)
(require 'cl-lib)
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(require 'tap-fold)


;;;; Core primitives

(ert-deftest tap-fold/region-creates-overlay ()
  (with-temp-buffer
    (insert "alpha beta gamma delta")
    (let ((ov (tap-fold-region 7 11)))
      (should (overlayp ov))
      (should (overlay-get ov 'tap-fold))
      (should (eq tap-fold--spec (overlay-get ov 'invisible))))))

(ert-deftest tap-fold/overlay-at-finds-fold ()
  (with-temp-buffer
    (insert "alpha beta gamma")
    (tap-fold-region 7 11)
    (should (tap-fold--overlay-at 8))
    (should-not (tap-fold--overlay-at 3))))

(ert-deftest tap-fold/unfold-at-point-removes-fold ()
  (with-temp-buffer
    (insert "alpha beta gamma")
    (tap-fold-region 7 11)
    (goto-char 8)
    (tap-fold-unfold-at-point)
    (should-not (tap-fold--overlay-at 8))))

(ert-deftest tap-fold/unfold-all ()
  (with-temp-buffer
    (insert "alpha beta gamma delta epsilon")
    (tap-fold-region 7 11)
    (tap-fold-region 17 22)
    (tap-fold-unfold-all)
    (should-not (tap-fold--overlay-at 8))
    (should-not (tap-fold--overlay-at 18))))


;;;; tap-fold-thing

(ert-deftest tap-fold/thing-folds-word ()
  (with-temp-buffer
    (insert "alpha beta gamma")
    (goto-char 8)
    (tap-fold-thing 'word)
    (should (tap-fold--overlay-at 8))))

(ert-deftest tap-fold/thing-errors-when-no-thing-at-point ()
  (with-temp-buffer
    (should-error (tap-fold-thing 'defun) :type 'user-error)))


;;;; Candidates at point

(ert-deftest tap-fold/candidates-at-point-filters ()
  (with-temp-buffer
    (insert "this is a sentence.  another sentence.")
    (goto-char 5)
    (let ((cands (tap-fold--candidates-at-point)))
      ;; word + sentence + paragraph should all have bounds here.
      (should (assoc "word" cands))
      (should (assoc "sentence" cands))
      (should (assoc "paragraph" cands)))))


;;;; Soft-dep guards

(ert-deftest tap-fold/embark-target-errors-without-embark-scope ()
  "`tap-fold-embark-target' user-errors if embark-scope isn't loaded."
  (let ((embark-scope-capture-mode nil))
    (makunbound 'embark-scope-capture-mode)
    (should-error (tap-fold-embark-target) :type 'user-error)))

(ert-deftest tap-fold/current-thing-errors-without-treesit-tap ()
  "`tap-fold-current-thing' user-errors if treesit-tap isn't loaded."
  (makunbound 'treesit-tap-current-thing)
  (should-error (tap-fold-current-thing) :type 'user-error))


;;;; Toggle

(ert-deftest tap-fold/toggle-folds-then-unfolds ()
  (with-temp-buffer
    (insert "alpha beta gamma")
    (goto-char 8)
    (tap-fold-toggle-thing-at-point 'word)
    (should (tap-fold--overlay-at 8))
    (tap-fold-toggle-thing-at-point 'word)
    (should-not (tap-fold--overlay-at 8))))


(provide 'tap-fold-test)
;;; tap-fold-test.el ends here
