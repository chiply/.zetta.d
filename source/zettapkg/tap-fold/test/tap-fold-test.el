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


;;;; --ensure-spec idempotency, three branches

(ert-deftest tap-fold/ensure-spec-from-bare-t ()
  "When `buffer-invisibility-spec' starts as bare `t' (the default),
`--ensure-spec' switches it to the alist form containing our entry."
  (with-temp-buffer
    (setq buffer-invisibility-spec t)
    (tap-fold--ensure-spec)
    (should (consp buffer-invisibility-spec))
    (should (member (cons tap-fold--spec t) buffer-invisibility-spec))))

(ert-deftest tap-fold/ensure-spec-from-alist-adds-entry ()
  "When `buffer-invisibility-spec' is already an alist without our
entry, `--ensure-spec' appends the entry."
  (with-temp-buffer
    (setq buffer-invisibility-spec '((other . t)))
    (tap-fold--ensure-spec)
    (should (member (cons tap-fold--spec t) buffer-invisibility-spec))
    (should (member '(other . t) buffer-invisibility-spec))))

(ert-deftest tap-fold/ensure-spec-already-present-noop ()
  "When our entry is already in the spec, second call is a no-op
(no duplicate)."
  (with-temp-buffer
    (setq buffer-invisibility-spec '((tap-fold . t)))
    (tap-fold--ensure-spec)
    (should (= 1 (cl-count (cons tap-fold--spec t)
                           buffer-invisibility-spec
                           :test #'equal)))))


;;;; --overlay-at POS-1 (point-on-ellipsis)

(ert-deftest tap-fold/overlay-at-finds-fold-from-after-end ()
  "Point AT (not just inside) the position immediately after a fold
should still find the fold -- supports point-on-ellipsis."
  (with-temp-buffer
    (insert "alpha beta gamma")
    (tap-fold-region 7 11)  ; folds "beta"
    ;; Point at 11 (just past the fold end) should still find it.
    (should (tap-fold--overlay-at 11))))


;;;; embark-target positive path (success when capture-mode + bounds)

(ert-deftest tap-fold/embark-target-positive-path ()
  "When capture-mode is on AND last-target-bounds is set,
`tap-fold-embark-target' folds the right region.

Sets the vars with `setq' rather than `let' so `(boundp ...)' inside
the function sees them -- `let' on a forward-declared (defvar without
value) special var doesn't make boundp return t reliably."
  (with-temp-buffer
    (insert "alpha beta gamma")
    (unwind-protect
        (progn
          (setq embark-scope-capture-mode t
                embark-scope-last-target-bounds '(7 . 11))
          (tap-fold-embark-target)
          (should (tap-fold--overlay-at 8)))
      (makunbound 'embark-scope-capture-mode)
      (makunbound 'embark-scope-last-target-bounds))))


(provide 'tap-fold-test)
;;; tap-fold-test.el ends here
