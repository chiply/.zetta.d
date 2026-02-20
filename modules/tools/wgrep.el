(use-package wgrep
  :config
  (setq wgrep-auto-save-buffer t)

  :general
  (
   :keymaps 'wgrep-mode-map
   "<C-return>" 'wgrep-finish-edit
   )
  )
