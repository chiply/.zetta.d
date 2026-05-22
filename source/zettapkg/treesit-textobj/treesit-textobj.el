;;; treesit-textobj.el --- Tree-sitter text objects for evil -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; URL: https://github.com/charlie-holland/treesit-textobj
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.1") (evil "1.15"))
;; Keywords: convenience, tools, languages

;;; Commentary:

;; Inner/outer evil text objects backed by Emacs's built-in tree-sitter
;; (no external query files).  Provides text objects for function,
;; class, parameter, call, string, and comment, activated via the
;; buffer-local `treesit-textobj-mode'.
;;
;; Usage:
;;
;;   (add-hook 'python-ts-mode-hook #'treesit-textobj-mode)
;;
;; Defaults bind in `evil-inner-text-objects-map' /
;; `evil-outer-text-objects-map':
;;
;;   f  function    c  class        g  parameter
;;   /  call        q  string       C  comment
;;
;; So `vaf' / `dif' / `2vaf' work as expected.  All text objects
;; self-gate on `treesit-textobj-mode': in a buffer where the mode is
;; off, they return nil and Emacs falls through to other bindings.
;;
;; Customization entry points:
;;
;;   `treesit-textobj-things'             per-language node types
;;   `treesit-textobj-keys'               per-thing key suffix
;;   `treesit-textobj-inner-body-fields'  field used for inner range
;;
;; After customizing keys, call `treesit-textobj-install-bindings' to
;; refresh.

;;; Code:

(require 'treesit)
(require 'evil)

(defgroup treesit-textobj nil
  "Tree-sitter text objects for evil."
  :group 'evil
  :prefix "treesit-textobj-")

(defcustom treesit-textobj-things
  '((function
     (python-ts-mode . ("function_definition"))
     (typescript-ts-mode . ("function_declaration" "arrow_function"
                            "method_definition" "function_expression"))
     (tsx-ts-mode . ("function_declaration" "arrow_function"
                     "method_definition" "function_expression"))
     (javascript-ts-mode . ("function_declaration" "arrow_function"
                            "method_definition" "function_expression"))
     (rust-ts-mode . ("function_item" "closure_expression"))
     (c-ts-mode . ("function_definition"))
     (c++-ts-mode . ("function_definition"))
     (go-ts-mode . ("function_declaration" "method_declaration")))
    (class
     (python-ts-mode . ("class_definition"))
     (typescript-ts-mode . ("class_declaration" "interface_declaration"))
     (tsx-ts-mode . ("class_declaration" "interface_declaration"))
     (javascript-ts-mode . ("class_declaration"))
     (rust-ts-mode . ("impl_item" "struct_item" "enum_item" "trait_item"))
     (c-ts-mode . ("struct_specifier"))
     (c++-ts-mode . ("class_specifier" "struct_specifier"))
     (go-ts-mode . ("type_declaration")))
    (parameter
     (python-ts-mode . ("parameter" "typed_parameter" "default_parameter"))
     (typescript-ts-mode . ("required_parameter" "optional_parameter"))
     (tsx-ts-mode . ("required_parameter" "optional_parameter"))
     (javascript-ts-mode . ("required_parameter" "optional_parameter"))
     (rust-ts-mode . ("parameter" "self_parameter"))
     (c-ts-mode . ("parameter_declaration"))
     (c++-ts-mode . ("parameter_declaration"))
     (go-ts-mode . ("parameter_declaration")))
    (call
     (python-ts-mode . ("call"))
     (typescript-ts-mode . ("call_expression" "new_expression"))
     (tsx-ts-mode . ("call_expression" "new_expression"))
     (javascript-ts-mode . ("call_expression" "new_expression"))
     (rust-ts-mode . ("call_expression" "macro_invocation"))
     (c-ts-mode . ("call_expression"))
     (c++-ts-mode . ("call_expression"))
     (go-ts-mode . ("call_expression")))
    (string
     (python-ts-mode . ("string"))
     (typescript-ts-mode . ("string" "template_string"))
     (tsx-ts-mode . ("string" "template_string"))
     (javascript-ts-mode . ("string" "template_string"))
     (rust-ts-mode . ("string_literal" "raw_string_literal"))
     (c-ts-mode . ("string_literal"))
     (c++-ts-mode . ("string_literal"))
     (go-ts-mode . ("interpreted_string_literal" "raw_string_literal")))
    (comment
     (python-ts-mode . ("comment"))
     (typescript-ts-mode . ("comment"))
     (tsx-ts-mode . ("comment"))
     (javascript-ts-mode . ("comment"))
     (rust-ts-mode . ("line_comment" "block_comment"))
     (c-ts-mode . ("comment"))
     (c++-ts-mode . ("comment"))
     (go-ts-mode . ("comment"))))
  "Per-thing alist of major-mode → list of tree-sitter node-type strings.
Lookups walk `derived-mode-parent' so derived modes inherit unless
they have their own entry."
  :type '(alist :key-type symbol
                :value-type (alist :key-type symbol
                                   :value-type (repeat string)))
  :group 'treesit-textobj)

(defcustom treesit-textobj-keys
  '((function  . "f")
    (class     . "c")
    (parameter . "g")
    (call      . "/")
    (string    . "q")
    (comment   . "C"))
  "Alist mapping logical thing → key string.
Each key is the suffix after `i' or `a' in evil's text-object maps,
so `(function . \"f\")' produces `vif' / `vaf'."
  :type '(alist :key-type symbol :value-type string)
  :group 'treesit-textobj)

(defcustom treesit-textobj-inner-body-fields
  '((function . "body")
    (class    . "body")
    (call     . "arguments"))
  "Alist mapping logical thing → tree-sitter field name for inner range.
When set, the inner text object uses the bounds of the child reached
by `treesit-node-child-by-field-name', with outer delimiters (braces,
parens) stripped if both first and last children are anonymous."
  :type '(alist :key-type symbol :value-type string)
  :group 'treesit-textobj)

(defun treesit-textobj--node-types-for (thing mode)
  "Return list of node-type strings for THING in MODE (or a parent of MODE).
Walks `derived-mode-parent' until a match is found in
`treesit-textobj-things' or the chain runs out."
  (when-let* ((per-thing (alist-get thing treesit-textobj-things)))
    (let ((m mode) types)
      (while (and m (not types))
        (setq types (alist-get m per-thing))
        (setq m (get m 'derived-mode-parent)))
      types)))

;;;###autoload
(defun treesit-textobj-find-ancestor (thing &optional count)
  "Return the COUNT-th tree-sitter ancestor at point matching THING.
THING is a logical name (e.g. `function') resolved through
`treesit-textobj-things'.  COUNT defaults to 1; COUNT > 1 walks past
inner matches to reach an enclosing one.  Returns nil when no parser
is active, when THING has no configured node types for the current
mode, or when no enclosing node matches."
  (when (and (fboundp 'treesit-parser-list)
             (treesit-parser-list))
    (let* ((count (max 1 (or count 1)))
           (types (treesit-textobj--node-types-for thing major-mode))
           (pred (when types (lambda (n) (member (treesit-node-type n) types))))
           (node (when pred (treesit-node-at (point))))
           result)
      (while (and (> count 0) node)
        (setq node (treesit-parent-until node pred t))
        (when node
          (setq result node
                count (1- count)
                node (treesit-node-parent node))))
      result)))

(defun treesit-textobj--strip-delimiters (node)
  "Return (BEG . END) inside NODE, skipping outer anonymous children.
If NODE's first and last children are both unnamed (e.g. braces or
parens), the returned range starts after the first and ends before the
last.  Otherwise the full NODE range is returned."
  (let* ((children (treesit-node-children node))
         (first (car children))
         (last (car (last children))))
    (if (and first last
             (not (eq first last))
             (not (treesit-node-check first 'named))
             (not (treesit-node-check last 'named)))
        (cons (treesit-node-end first)
              (treesit-node-start last))
      (cons (treesit-node-start node)
            (treesit-node-end node)))))

(defun treesit-textobj--inner-range (node thing)
  "Return (BEG . END) inner range for NODE representing logical THING."
  (let* ((field (alist-get thing treesit-textobj-inner-body-fields))
         (body (when field (treesit-node-child-by-field-name node field))))
    (if body
        (treesit-textobj--strip-delimiters body)
      (treesit-textobj--strip-delimiters node))))

(defun treesit-textobj--outer-range (node)
  "Return (BEG . END) outer range for NODE."
  (cons (treesit-node-start node) (treesit-node-end node)))

(defun treesit-textobj--make-object (thing scope)
  "Define and return text-object command for THING in SCOPE.
SCOPE is `inner' or `outer'.  Result is a symbol naming the new
command, which is itself an `evil-define-text-object'.  The body
self-gates on `treesit-textobj-mode'."
  (let ((name (intern (format "treesit-textobj-%s-%s" scope thing))))
    (eval
     `(evil-define-text-object ,name (count beg end type)
        ,(format "%s text object for tree-sitter `%s'."
                 (capitalize (symbol-name scope)) thing)
        (when treesit-textobj-mode
          (when-let* ((node (treesit-textobj-find-ancestor ',thing count))
                      (range ,(if (eq scope 'inner)
                                  `(treesit-textobj--inner-range node ',thing)
                                `(treesit-textobj--outer-range node))))
            (evil-range (car range) (cdr range) 'inclusive))))
     t)
    name))

(defvar treesit-textobj--installed nil
  "List of (KEYMAP . KEY) entries installed by
`treesit-textobj-install-bindings'.  Used to unbind cleanly when
reinstalling.")

(defun treesit-textobj-install-bindings ()
  "Install bindings into evil's inner/outer text-objects maps.
Idempotent: any prior installation is undone first.  Call this after
customizing `treesit-textobj-keys' or `treesit-textobj-things' to
refresh.  Bindings themselves are global; the text-object commands
self-gate on `treesit-textobj-mode'."
  (interactive)
  (pcase-dolist (`(,map . ,key) treesit-textobj--installed)
    (define-key map key nil))
  (setq treesit-textobj--installed nil)
  (dolist (entry treesit-textobj-things)
    (let* ((thing (car entry))
           (key (alist-get thing treesit-textobj-keys)))
      (when key
        (let ((inner-fn (treesit-textobj--make-object thing 'inner))
              (outer-fn (treesit-textobj--make-object thing 'outer)))
          (define-key evil-inner-text-objects-map key inner-fn)
          (define-key evil-outer-text-objects-map key outer-fn)
          (push (cons evil-inner-text-objects-map key)
                treesit-textobj--installed)
          (push (cons evil-outer-text-objects-map key)
                treesit-textobj--installed))))))

;;;###autoload
(define-minor-mode treesit-textobj-mode
  "Enable tree-sitter text objects for evil in this buffer.
While on, the bindings in `treesit-textobj-keys' resolve through
tree-sitter to inner/outer ranges of the matching node.  While off,
those keys fall through to whatever else owns them in evil's
inner/outer text-objects maps."
  :lighter nil
  :group 'treesit-textobj)

;; Install bindings at load time so the first mode activation works
;; without a separate setup call.
(treesit-textobj-install-bindings)

(provide 'treesit-textobj)
;;; treesit-textobj.el ends here
