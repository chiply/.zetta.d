(use-package typescript-ts-mode
  :ensure nil ;; builtin
  :config
  (add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-ts-mode))
  )
