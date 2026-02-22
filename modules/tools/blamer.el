;;; blamer.el --- Configure blamer -*- lexical-binding: t; -*-

(use-package blamer
  :ensure t
  :custom
  (blamer-idle-time 0.3) ;; match lsp sidlein
  (blamer-min-offset 10)
  (blamer-max-commit-message-length 50)
  ;;:config
  ;;(global-blamer-mode 1)
)
;;; blamer.el ends here
