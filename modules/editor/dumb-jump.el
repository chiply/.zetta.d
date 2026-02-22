;;; dumb-jump.el --- Configure dumb-jump -*- lexical-binding: t; -*-

(use-package dumb-jump
  :config
  (add-hook 'xref-backend-functions #'dumb-jump-xref-activate)
  )
;;; dumb-jump.el ends here
