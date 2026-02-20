(use-package vundo
  :config
  (setq vundo-window-max-height 100)
  ;;(setq vundo-glyph-alist vundo-unicode-symbols)
  ;;(set-face-attribute 'vundo-default nil :family "Symbola")
  :general
  (
   :keymaps 'launch-map
   "u" 'vundo
   )
  (
   :keymaps '(evil-normal-state-map evil-visual-state-map)
   :state '(normal visual)
   "u" 'undo
   "C-r" 'undo-redo
   )

  )
