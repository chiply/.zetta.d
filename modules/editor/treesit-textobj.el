;;; treesit-textobj.el --- Tree-sitter text objects for evil -*- lexical-binding: t; -*-

;; Thin wrapper around the in-tree `treesit-textobj' package (under
;; `source/zettapkg/').  When the package is factored out to its own
;; repo, swap `:ensure nil' + `:load-path' for `:ensure t'.

(use-package treesit-textobj
  :ensure nil
  :load-path "source/zettapkg/treesit-textobj"
  :after evil
  :hook ((python-ts-mode
          typescript-ts-mode
          tsx-ts-mode
          javascript-ts-mode
          rust-ts-mode
          c-ts-mode
          c++-ts-mode
          go-ts-mode)
         . treesit-textobj-mode))

;;; treesit-textobj.el ends here
