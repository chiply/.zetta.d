;;; typescript-ts-mode.el --- Configure typescript-ts-mode -*- lexical-binding: t; -*-

(use-package typescript-ts-mode
  :ensure nil ;; builtin
  :config
  (add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-ts-mode))
  )
;;; typescript-ts-mode.el ends here
