;;; treesit-textobj-test.el --- ERT smoke tests -*- lexical-binding: t -*-

;; Run with:
;;   emacs -Q --batch -L .. -L <evil-load-path> \
;;        -l treesit-textobj-test.el -f ert-run-tests-batch-and-exit
;;
;; Tests are unit-level only -- they avoid driving evil-define-text-object
;; or live tree-sitter parsers (those require grammars installed and an
;; active evil session).  The integration path is exercised manually in
;; real treesit buffers; CI here covers the data-layer + mode-toggle
;; surfaces that are most regression-prone.

(require 'ert)
(require 'cl-lib)
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
;; Stub evil bits the package references at load time.
(unless (boundp 'evil-inner-text-objects-map)
  (defvar evil-inner-text-objects-map (make-sparse-keymap)))
(unless (boundp 'evil-outer-text-objects-map)
  (defvar evil-outer-text-objects-map (make-sparse-keymap)))
(unless (fboundp 'evil-define-text-object)
  (defmacro evil-define-text-object (name args &rest body)
    `(defun ,name ,args ,@body)))
(unless (fboundp 'evil-range)
  (defun evil-range (beg end type) (list beg end type)))

(require 'treesit-textobj)


;;;; --node-types-for

(ert-deftest treesit-textobj/node-types-for-direct ()
  "Direct major-mode match returns its node types."
  (should (equal '("function_definition")
                 (treesit-textobj--node-types-for
                  'function 'python-ts-mode))))

(ert-deftest treesit-textobj/node-types-for-derived-mode-inherits ()
  "Derived modes inherit node types from parent via
`derived-mode-parent'.  Create a stub child mode and verify lookup
walks up."
  (define-derived-mode treesit-textobj-test--child-mode python-ts-mode
    "Child"
    "Test stub deriving from python-ts-mode.")
  (should (equal '("function_definition")
                 (treesit-textobj--node-types-for
                  'function 'treesit-textobj-test--child-mode))))

(ert-deftest treesit-textobj/node-types-for-unknown ()
  "Unknown thing or unconfigured mode returns nil."
  (should-not (treesit-textobj--node-types-for 'function 'fundamental-mode))
  (should-not (treesit-textobj--node-types-for 'nonexistent 'python-ts-mode)))


;;;; Defcustom defaults

(ert-deftest treesit-textobj/defcustoms-have-expected-shape ()
  "Defaults are valid alists of the right shape -- catches accidental
mis-typing of the table that would break code-path assumptions."
  ;; things: alist of (THING . ((MODE . LIST-OF-STRINGS) ...))
  (should (consp treesit-textobj-things))
  (dolist (entry treesit-textobj-things)
    (should (symbolp (car entry)))
    (should (consp (cdr entry)))
    (dolist (mode-entry (cdr entry))
      (should (symbolp (car mode-entry)))
      (should (listp (cdr mode-entry)))
      (dolist (type (cdr mode-entry))
        (should (stringp type)))))
  ;; keys: alist of (THING . KEY-STRING)
  (should (consp treesit-textobj-keys))
  (dolist (entry treesit-textobj-keys)
    (should (symbolp (car entry)))
    (should (stringp (cdr entry))))
  ;; inner-body-fields: alist of (THING . FIELD-NAME-STRING)
  (dolist (entry treesit-textobj-inner-body-fields)
    (should (symbolp (car entry)))
    (should (stringp (cdr entry)))))

(ert-deftest treesit-textobj/keys-are-unique ()
  "No two things share the same key -- key collisions would silently
shadow one binding by another in `evil-inner-text-objects-map'."
  (let ((keys (mapcar #'cdr treesit-textobj-keys)))
    (should (= (length keys) (length (delete-dups (copy-sequence keys)))))))


;;;; install-bindings populates the maps

(ert-deftest treesit-textobj/install-bindings-populates-maps ()
  "Running `treesit-textobj-install-bindings' on let-bound maps
populates every configured key with a command."
  (let ((evil-inner-text-objects-map (make-sparse-keymap))
        (evil-outer-text-objects-map (make-sparse-keymap))
        (treesit-textobj--installed nil))
    (treesit-textobj-install-bindings)
    (dolist (entry treesit-textobj-keys)
      (let ((key (cdr entry)))
        (should (commandp (lookup-key evil-inner-text-objects-map key)))
        (should (commandp (lookup-key evil-outer-text-objects-map key)))))))

(ert-deftest treesit-textobj/install-bindings-idempotent ()
  "Calling `install-bindings' twice leaves the same set of bindings,
not double-counted or duplicated."
  (let ((evil-inner-text-objects-map (make-sparse-keymap))
        (evil-outer-text-objects-map (make-sparse-keymap))
        (treesit-textobj--installed nil))
    (treesit-textobj-install-bindings)
    (let ((first-count (length treesit-textobj--installed)))
      (treesit-textobj-install-bindings)
      (should (= first-count (length treesit-textobj--installed))))))


;;;; install-bindings reflects current `treesit-textobj-keys'

(ert-deftest treesit-textobj/install-bindings-picks-up-rebind ()
  "After mutating `treesit-textobj-keys', re-running
`treesit-textobj-install-bindings' rebinds to the new key and clears
the old one."
  (let ((evil-inner-text-objects-map (make-sparse-keymap))
        (evil-outer-text-objects-map (make-sparse-keymap))
        (treesit-textobj-keys (copy-tree treesit-textobj-keys)))
    (unwind-protect
        (progn
          (treesit-textobj-install-bindings)
          (should (commandp (lookup-key evil-inner-text-objects-map "f")))
          ;; Move function from "f" to "F".
          (setf (alist-get 'function treesit-textobj-keys) "F")
          (treesit-textobj-install-bindings)
          (should (commandp (lookup-key evil-inner-text-objects-map "F")))
          (should-not (lookup-key evil-inner-text-objects-map "f")))
      ;; Cleanup.
      (treesit-textobj-mode -1))))


(provide 'treesit-textobj-test)
;;; treesit-textobj-test.el ends here
