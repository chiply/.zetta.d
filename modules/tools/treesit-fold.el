;;; treesit-fold.el --- Configure treesit-fold -*- lexical-binding: t; -*-

;; Tree-sitter-based structural folding.  Acts as a kirigami backend in
;; ts-mode buffers; kirigami's commands automatically dispatch here when
;; treesit-fold-mode is active.

(use-package treesit-fold
  :commands (treesit-fold-mode
             treesit-fold-close
             treesit-fold-open
             treesit-fold-toggle
             treesit-fold-close-all
             treesit-fold-open-all
             treesit-fold-open-recursively)
  :custom
  (treesit-fold-line-count-show t)
  (treesit-fold-line-count-format " ▼")
  :hook ((python-ts-mode . treesit-fold-mode)
         (yaml-ts-mode . treesit-fold-mode)
         (json-ts-mode . treesit-fold-mode)
         (typescript-ts-mode . treesit-fold-mode)
         (tsx-ts-mode . treesit-fold-mode)
         (bash-ts-mode . treesit-fold-mode)
         (dockerfile-ts-mode . treesit-fold-mode)
         (toml-ts-mode . treesit-fold-mode)))
;;; treesit-fold.el ends here
