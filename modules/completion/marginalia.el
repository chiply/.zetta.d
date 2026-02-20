;; for candidate metadata
(use-package marginalia
  :init
  (marginalia-mode)
  :bind (:map minibuffer-local-map
         ("M-A" . marginalia-cycle))
  )


