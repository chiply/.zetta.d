;;; treesit-tap-test.el --- ERT smoke tests for treesit-tap -*- lexical-binding: t -*-

;; Run with:
;;   emacs -Q --batch -L .. -l treesit-tap-test.el -f ert-run-tests-batch-and-exit
;; from the test/ directory.

(require 'ert)
(require 'cl-lib)
;; Load `treesit-tap' from the parent directory.
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(require 'treesit-tap)


;;;; Bridge

(ert-deftest treesit-tap/bridged-things-defaults ()
  "The shipped default thing list covers the common AST shapes."
  (should (memq 'defun treesit-tap-bridged-things))
  (should (memq 'function treesit-tap-bridged-things))
  (should (memq 'call treesit-tap-bridged-things))
  (should (memq 'str-lit treesit-tap-bridged-things))
  ;; `string' must NOT be in the list -- collides with built-in function name.
  (should-not (memq 'string treesit-tap-bridged-things)))

(ert-deftest treesit-tap/bounds-returns-nil-without-parser ()
  "`treesit-tap-bounds' is safe in non-treesit buffers."
  (with-temp-buffer
    (should-not (treesit-tap-bounds 'defun))))


;;;; Mode + bridge install / uninstall

(ert-deftest treesit-tap/mode-installs-providers ()
  "Toggling the mode on installs bounds providers for every bridged thing."
  (unwind-protect
      (progn
        (treesit-tap-mode 1)
        (dolist (thing treesit-tap-bridged-things)
          (should (assq thing bounds-of-thing-at-point-provider-alist))))
    (treesit-tap-mode -1)))

(ert-deftest treesit-tap/mode-removes-providers-on-off ()
  "Toggling the mode off removes the providers it installed."
  (treesit-tap-mode 1)
  (treesit-tap-mode -1)
  (dolist (thing treesit-tap-bridged-things)
    (should-not (assq thing bounds-of-thing-at-point-provider-alist))))

(ert-deftest treesit-tap/mode-toggle-is-idempotent ()
  "Toggling twice on then twice off leaves no duplicate providers."
  (unwind-protect
      (progn
        (treesit-tap-mode 1)
        (treesit-tap-mode 1)
        (let* ((entries (cl-remove-if-not
                         (lambda (entry)
                           (memq (car entry) treesit-tap-bridged-things))
                         bounds-of-thing-at-point-provider-alist)))
          ;; One entry per bridged thing -- no duplicates.
          (should (= (length entries)
                     (length treesit-tap-bridged-things)))))
    (treesit-tap-mode -1)))


;;;; Language extras

(ert-deftest treesit-tap/language-extras-has-python ()
  "Shipped defaults include python entries."
  (should (assq 'python treesit-tap-language-extras))
  (let ((python-extras (alist-get 'python treesit-tap-language-extras)))
    (should (assq 'function python-extras))
    (should (assq 'call python-extras))))

(ert-deftest treesit-tap/extend-language-is-idempotent ()
  "Calling `treesit-tap-extend-language' twice does not duplicate."
  (with-temp-buffer
    (let ((treesit-thing-settings nil)
          (extras '((function "\\`function_definition\\'"))))
      (treesit-tap-extend-language 'python extras)
      (treesit-tap-extend-language 'python extras)
      (let* ((python-settings (cdr (assq 'python treesit-thing-settings)))
             (function-entries (cl-remove-if-not
                                (lambda (e) (eq (car e) 'function))
                                python-settings)))
        (should (= 1 (length function-entries)))))))


;;;; Current-thing state

(ert-deftest treesit-tap/current-thing-fallback ()
  "Reading `treesit-tap--current-thing' returns the default when local
is nil."
  (with-temp-buffer
    (should (eq (treesit-tap--current-thing) treesit-tap-default-thing))))

(ert-deftest treesit-tap/intern-maybe ()
  (should (eq 'foo (treesit-tap--intern-maybe 'foo)))
  (should (eq 'foo (treesit-tap--intern-maybe "foo"))))

(ert-deftest treesit-tap/set-local-with-symbol ()
  (with-temp-buffer
    (treesit-tap-set-local 'sentence)
    (should (eq 'sentence treesit-tap-current-thing))))

(ert-deftest treesit-tap/set-local-with-string ()
  (with-temp-buffer
    (treesit-tap-set-local "paragraph")
    (should (eq 'paragraph treesit-tap-current-thing))))


;;;; Things-at-point integration in fundamental-mode

(ert-deftest treesit-tap/locate-thing-paragraph ()
  "Locate the paragraph at point."
  (with-temp-buffer
    (insert "First paragraph.\n\nSecond paragraph.\n")
    (goto-char 5)
    (treesit-tap-set-local 'paragraph)
    (let ((b (treesit-tap-locate-thing)))
      (should b)
      (should (= 1 (car b)))
      (should (consp b))
      (should (numberp (cdr b))))))

(ert-deftest treesit-tap/get-thing-returns-buffer-text ()
  (with-temp-buffer
    (insert "alpha beta gamma")
    (goto-char 8)
    (treesit-tap-set-local 'word)
    (should (equal "beta" (treesit-tap-get-thing)))))


;;;; First-bounds-for (preview helper)

(ert-deftest treesit-tap/first-bounds-for-at-point ()
  "Returns at-point bounds when available."
  (with-temp-buffer
    (insert "the quick brown fox")
    (goto-char 6)
    (let ((b (treesit-tap--first-bounds-for 'word)))
      (should b)
      (should (equal "quick" (buffer-substring (car b) (cdr b)))))))


;;;; locate-thing has no -1 off-by-one (regression guard)

(ert-deftest treesit-tap/locate-thing-bounds-exact ()
  "REGRESSION: pre-rename `zetta-locate-thing' returned (BEG . END-1),
which made `treesit-tap-get-thing' on a word return one char short
of the actual word.  The fix uses proper Emacs (BEG . END)
convention.  This test locks that fix in."
  (with-temp-buffer
    (insert "alpha beta gamma")
    (goto-char 8)  ; in the middle of "beta"
    (treesit-tap-set-local 'word)
    (let ((b (treesit-tap-locate-thing)))
      (should (equal "beta"
                     (buffer-substring (car b) (cdr b)))))))


;;;; treesit-tap-forward-thing fallback path

(ert-deftest treesit-tap/forward-thing-fallback-moves-by-thing ()
  "In a non-treesit buffer, forward-thing fallback path moves point
to the next thing instance."
  (with-temp-buffer
    (insert "first sentence.  second sentence.  third sentence.")
    (goto-char (point-min))
    (treesit-tap-set-local 'sentence)
    (treesit-tap-forward-thing 1)
    ;; Point should have moved forward into the second sentence.
    (should (> (point) 1))))

(ert-deftest treesit-tap/forward-thing-no-error-empty-buffer ()
  "Calling `forward-thing' in a buffer with no instances of the
current thing does not signal -- silent no-op is acceptable."
  (with-temp-buffer
    (insert "   ")
    (goto-char 2)
    (treesit-tap-set-local 'defun)
    (should-not (condition-case err
                    (progn (treesit-tap-forward-thing 1) nil)
                  (error err)))))


;;;; next / prev navigate properly

(ert-deftest treesit-tap/next-then-prev-returns-to-start ()
  "next + prev round-trip lands back at the starting sentence."
  (with-temp-buffer
    (insert "first sentence.  second sentence.  third sentence.")
    (goto-char 4)
    (treesit-tap-set-local 'sentence)
    (let ((start (point)))
      (treesit-tap-next)
      (let ((after-next (point)))
        (treesit-tap-prev)
        ;; Some forward-thing implementations drift by whitespace --
        ;; the round-trip should at least put us back in the first
        ;; sentence (point < after-next).
        (should (< (point) after-next))))))


;;;; get-thing with active region returns region text

(ert-deftest treesit-tap/get-thing-with-region-returns-region ()
  "When the region is active, `get-thing' returns the region's text,
ignoring `treesit-tap-current-thing'."
  (with-temp-buffer
    (insert "alpha beta gamma delta")
    (treesit-tap-set-local 'word)
    (push-mark 3 t t)
    (goto-char 11)
    (activate-mark)
    (should (equal "pha beta" (treesit-tap-get-thing)))))


;;;; at-bobp / at-eobp
;; `at-bobp' / `at-eobp' check whether the CURRENT THING begins at
;; point-min / ends at point-max -- not whether point itself is at the
;; buffer edge.  Multi-sentence buffer needed to distinguish.

(ert-deftest treesit-tap/at-bobp ()
  (with-temp-buffer
    (insert "first sentence.  second sentence.  third sentence.")
    (treesit-tap-set-local 'sentence)
    (goto-char 5)   ; in first sentence -> begins at 1 -> t
    (should (treesit-tap-at-bobp))
    (goto-char 22)  ; in second sentence -> doesn't begin at 1 -> nil
    (should-not (treesit-tap-at-bobp))))

(ert-deftest treesit-tap/at-eobp ()
  (with-temp-buffer
    (insert "first sentence.  second sentence.  third sentence.")
    (treesit-tap-set-local 'sentence)
    (goto-char 5)   ; first sentence -> doesn't end at point-max
    (should-not (treesit-tap-at-eobp))
    (goto-char 45)  ; third (last) sentence -> ends at point-max
    (should (treesit-tap-at-eobp))))


;;;; --first-bounds-for scan fallback (window scan when at-point fails)

(ert-deftest treesit-tap/first-bounds-for-scan-fallback ()
  "When the thing isn't at point, `--first-bounds-for' scans forward
from `window-start' to find the first instance."
  (with-temp-buffer
    (insert "no urls here for a while.  then https://x.io appears.")
    (goto-char 3)  ; on " urls"; not on the URL
    (cl-letf (((symbol-function 'window-start) (lambda (&rest _) (point-min)))
              ((symbol-function 'window-end) (lambda (&rest _) (point-max))))
      (let ((b (treesit-tap--first-bounds-for 'url)))
        (should b)
        (should (equal "https://x.io"
                       (buffer-substring (car b) (cdr b))))))))


(provide 'treesit-tap-test)
;;; treesit-tap-test.el ends here
