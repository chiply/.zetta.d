;;; define-word.el --- Configure define-word -*- lexical-binding: t; -*-

(use-package define-word
  :general
  (
   :keymaps 'menu-lookup-map
   "d" 'define-word-at-point
   "D" 'define-word
   )
  )
;;; define-word.el ends here
