;;; apheleia.el --- Configure apheleia -*- lexical-binding: t; -*-

(use-package apheleia
  :config
  ;; disabling as it conflicts with what is setup in the repo, need to address this
  (apheleia-global-mode -1)
  :general
  (
   :keymaps 'override
   "s-i" 'apheleia-format-buffer
   )
  )
;;; apheleia.el ends here
