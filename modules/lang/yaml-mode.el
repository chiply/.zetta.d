(use-package yaml-mode
  :hook (yaml-mode . (lambda () (auto-fill-mode -1)))
  )
