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


(provide 'treesit-tap-test)
;;; treesit-tap-test.el ends here
