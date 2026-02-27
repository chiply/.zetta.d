;;; magneto.el --- Configure magneto -*- lexical-binding: t; -*-

(use-package magneto
  :ensure (:host github :repo "chiply/magneto")
  :commands (magneto-move magneto-compose)
  :custom
  (magneto-buffer-command #'consult-buffer)
  :general
  (:keymaps 'override "s-m" #'magneto-compose)
  :config
  (with-eval-after-load 'embark
    (require 'magneto-embark)
    (magneto-embark-bind-keys)))

;;; magneto.el ends here
