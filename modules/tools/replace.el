;;; replace.el --- Configure replace -*- lexical-binding: t; -*-

(use-package replace
  :ensure nil

  :evil
  (evil-set-initial-state 'occur-mode 'normal)
  (evil-set-initial-state 'occur-edit-mode 'normal)

  :general
  (
   :keymaps '(occur-mode-map)
   "e" 'occur-edit-mode
   )
  )
;;; replace.el ends here
