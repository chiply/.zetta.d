(use-package grep
  :ensure nil
  :after embark
  :mode ("\\.grep\\'" . grep-mode)
  :config

  ;; TODO doesn't work
  (general-unbind 'grep-mode-map "g r")
  :general
  (
   :keymaps 'grep-mode-map
   "g r" 'embark-rerun-collect-or-export
   )
  )

