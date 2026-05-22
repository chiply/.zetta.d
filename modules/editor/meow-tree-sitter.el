;;; meow-tree-sitter.el --- TS things for meow -*- lexical-binding: t; -*-

;; https://github.com/skissue/meow-tree-sitter
;;
;; Registers tree-sitter-backed "things" with meow's thing system,
;; so `meow-inner-of-thing' (`,') and `meow-bounds-of-thing' (`.')
;; can address AST units -- function, class, parameter, comment,
;; call -- in any buffer with a live parser.
;;
;; Same intent as the evil counterpart `evil-textobj-tree-sitter':
;; the AST nodes embark already surfaces are now also addressable
;; from the modal editor's grammar.  Queries are bundled with the
;; upstream package.

(use-package meow-tree-sitter
  :ensure (:host github :repo "skissue/meow-tree-sitter")
  :after meow
  :demand t
  :config
  ;; `meow-tree-sitter-register-defaults' wires the standard set
  ;; (function, class, parameter, comment, call) into meow's
  ;; `meow-char-thing-table'.  After this, in any tree-sit major
  ;; mode the meow inner/bounds-of-thing motions work on AST units.
  (meow-tree-sitter-register-defaults))
;;; meow-tree-sitter.el ends here
