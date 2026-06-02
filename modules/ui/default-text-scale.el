;;; default-text-scale.el --- Configure default-text-scale -*- lexical-binding: t; -*-

(use-package default-text-scale
  :after face-remap
  :general
  (
   :keymaps 'menu-window-map
   "C-+" (repeatable-wrap default-text-scale-increase)
   "C-_" (repeatable-wrap default-text-scale-decrease)
   )
  )
;;; default-text-scale.el ends here
