(use-package hi-lock
  :ensure nil ;; builtin
  :commands (highlight-regexp highlight-phrase hi-lock-mode)
  :init
  ;; prevents issues with precedence over hl-line
  (setq hi-lock-use-overlays nil)
  )

