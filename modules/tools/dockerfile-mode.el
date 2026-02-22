;;; dockerfile-mode.el --- Configure dockerfile-mode -*- lexical-binding: t; -*-

(use-package dockerfile-mode
  :config
  (add-to-list 'auto-mode-alist '("Dockerfile\\'" . dockerfile-mode))
  )
;;; dockerfile-mode.el ends here
