;;; evil-textobj-tree-sitter.el --- TS text objects for evil -*- lexical-binding: t; -*-

;; https://github.com/meain/evil-textobj-tree-sitter
;;
;; Adds tree-sitter-driven text objects to evil's operator-pending
;; state.  Composes with the rest of the type-bridge system: the same
;; AST nodes that Bridge A / B / C surface as embark targets are now
;; addressable via standard vim grammar like `daf' (delete around
;; function), `vic' (visually select inner class), `cif' (change
;; inner function), etc.
;;
;; Queries are bundled in the upstream repo's `queries/' tree; no
;; extra setup beyond a live tree-sitter parser in the buffer.
;;
;; Note on the explicit calls: `evil-textobj-tree-sitter-get-textobj'
;; is a macro that expects the group as a literal string at expansion
;; time, so the pairs cannot be unfolded with a runtime loop -- each
;; binding is spelled out instead.

;; Upstream bundles queries that use `"X"? @cap' (quantifier
;; directly on a string literal) -- Emacs's `treesit-query-compile'
;; rejects this with `treesit-query-error "Syntax error at"'.
;; The standard equivalent is `("X" @cap)?'. Patch query strings at
;; load time so every language file gets the fix without editing the
;; bundled .scm files. Outside `use-package' so the advice installs
;; whenever this file loads, not just on the first package load.
(with-eval-after-load 'evil-textobj-tree-sitter
  (define-advice evil-textobj-tree-sitter--get-query-from-dir
      (:filter-return (s) zetta-fix-quantified-string)
    (when (stringp s)
      (replace-regexp-in-string
       "\\(\"[^\"]+\"\\)\\([?*+]\\)\\(\\s-+@[A-Za-z._-]+\\)"
       "(\\1\\3)\\2"
       s))))

(use-package evil-textobj-tree-sitter
  :ensure (:host github :repo "meain/evil-textobj-tree-sitter")
  :after (evil treesit)
  :demand t
  :config
  ;; function
  (define-key evil-outer-text-objects-map "f"
              (evil-textobj-tree-sitter-get-textobj "function.outer"))
  (define-key evil-inner-text-objects-map "f"
              (evil-textobj-tree-sitter-get-textobj "function.inner"))
  ;; class
  (define-key evil-outer-text-objects-map "c"
              (evil-textobj-tree-sitter-get-textobj "class.outer"))
  (define-key evil-inner-text-objects-map "c"
              (evil-textobj-tree-sitter-get-textobj "class.inner"))
  ;; parameter
  (define-key evil-outer-text-objects-map "a"
              (evil-textobj-tree-sitter-get-textobj "parameter.outer"))
  (define-key evil-inner-text-objects-map "a"
              (evil-textobj-tree-sitter-get-textobj "parameter.inner"))
  ;; loop
  (define-key evil-outer-text-objects-map "l"
              (evil-textobj-tree-sitter-get-textobj "loop.outer"))
  (define-key evil-inner-text-objects-map "l"
              (evil-textobj-tree-sitter-get-textobj "loop.inner"))
  ;; conditional
  (define-key evil-outer-text-objects-map "i"
              (evil-textobj-tree-sitter-get-textobj "conditional.outer"))
  (define-key evil-inner-text-objects-map "i"
              (evil-textobj-tree-sitter-get-textobj "conditional.inner"))
  ;; comment
  (define-key evil-outer-text-objects-map "C"
              (evil-textobj-tree-sitter-get-textobj "comment.outer"))
  (define-key evil-inner-text-objects-map "C"
              (evil-textobj-tree-sitter-get-textobj "comment.inner"))
  ;; assignment
  (define-key evil-outer-text-objects-map "v"
              (evil-textobj-tree-sitter-get-textobj "assignment.outer"))
  (define-key evil-inner-text-objects-map "v"
              (evil-textobj-tree-sitter-get-textobj "assignment.inner"))
  ;; call
  (define-key evil-outer-text-objects-map "/"
              (evil-textobj-tree-sitter-get-textobj "call.outer"))
  (define-key evil-inner-text-objects-map "/"
              (evil-textobj-tree-sitter-get-textobj "call.inner")))

;;; evil-textobj-tree-sitter.el ends here
