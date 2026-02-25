;;; grep.el --- Configure grep -*- lexical-binding: t; -*-

(use-package grep
  :ensure nil
  :after embark
  :mode ("\\.grep\\'" . grep-mode)
  :config

  ;; Unbind default "g r" so we can rebind to embark-rerun below
  (general-unbind 'grep-mode-map "g r")
  :general
  (
   :keymaps 'grep-mode-map
   "g r" 'embark-rerun-collect-or-export
   )
  )
;;; grep.el ends here
