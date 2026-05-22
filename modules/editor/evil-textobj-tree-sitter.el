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

(use-package evil-textobj-tree-sitter
  :ensure (:host github :repo "meain/evil-textobj-tree-sitter")
  :after (evil treesit)
  :config
  ;; Outer / inner text-object pairs. Keys mirror the conventions
  ;; established by vim plugins like nvim-treesitter-textobjects.
  (dolist (pair '(("f" "function")
                  ("c" "class")
                  ("a" "parameter")
                  ("l" "loop")
                  ("i" "conditional")
                  ("C" "comment")
                  ("v" "assignment")
                  ("/" "call")))
    (let ((key  (car  pair))
          (name (cadr pair)))
      (define-key evil-outer-text-objects-map key
                  (evil-textobj-tree-sitter-get-textobj
                   (concat name ".outer")))
      (define-key evil-inner-text-objects-map key
                  (evil-textobj-tree-sitter-get-textobj
                   (concat name ".inner"))))))
;;; evil-textobj-tree-sitter.el ends here
