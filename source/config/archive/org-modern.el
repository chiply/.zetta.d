(use-package org-modern
  :config
  (setq org-modern-table nil)
  :hook (org-mode . (lambda ()
                      (org-indent-mode -1)
                      (org-modern-mode 1)))
  )
