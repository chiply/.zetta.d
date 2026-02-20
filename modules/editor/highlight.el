(use-package highlight
  :config
  (setq hlt-use-overlays-flag t)
  (general-define-key
   :keymaps 'override
   "M-I" 'highlight-regexp
   )
  
  )

