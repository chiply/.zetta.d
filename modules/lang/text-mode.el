;;; text-mode.el --- Configure text-mode -*- lexical-binding: t; -*-

(use-package text-mode
  :ensure nil
  :hook (text-mode . (lambda () (toggle-truncate-lines 1)))
 )
;;; text-mode.el ends here
