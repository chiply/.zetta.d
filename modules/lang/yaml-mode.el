;;; yaml-mode.el --- Configure yaml-mode -*- lexical-binding: t; -*-

(use-package yaml-mode
  :hook (yaml-mode . (lambda () (auto-fill-mode -1)))
  )
;;; yaml-mode.el ends here
