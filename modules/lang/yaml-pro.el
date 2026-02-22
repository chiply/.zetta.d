;;; yaml-pro.el --- Configure yaml-pro -*- lexical-binding: t; -*-

(use-package yaml-pro
  :after yaml
  :general
  (
   :keymaps '(yaml-pro-mode-map)
   "C-c C-f" 'yaml-pro-fold-at-point
   "C-c C-o" 'yaml-pro-unfold-at-point
   "C-c C-j" 'yaml-pro-jump
   )
  :hook (yaml-mode . yaml-pro-mode)
  )
;;; yaml-pro.el ends here
