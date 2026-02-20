(use-package text-mode
  :ensure nil
  :hook (text-mode . (lambda () (toggle-truncate-lines 1)))
 )
