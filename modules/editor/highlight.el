;;; highlight.el --- Configure highlight -*- lexical-binding: t; -*-

(use-package highlight
  :config
  (setq hlt-use-overlays-flag t)
  (general-define-key
   :keymaps 'override
   "M-I" 'highlight-regexp
   )

  )
;;; highlight.el ends here
