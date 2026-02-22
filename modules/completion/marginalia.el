;;; marginalia.el --- Configure marginalia -*- lexical-binding: t; -*-

;; for candidate metadata
(use-package marginalia
  :init
  (marginalia-mode)
  :bind (:map minibuffer-local-map
         ("M-A" . marginalia-cycle))
  )
;;; marginalia.el ends here
