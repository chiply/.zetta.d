;;; js2-mode.el --- Configure js2-mode -*- lexical-binding: t; -*-

(use-package js2-mode
  :config
  (add-to-list 'auto-mode-alist '("\\.js\\'" . js2-mode)) 
  )
;;; js2-mode.el ends here
