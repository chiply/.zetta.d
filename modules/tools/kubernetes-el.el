;;; kubernetes-el.el --- Configure kubernetes -*- lexical-binding: t; -*-

(use-package kubernetes
  :ensure (:host github :repo "kubernetes-el/kubernetes-el")
  :commands (kubernetes-overview)
  :config
  (setq kubernetes-poll-frequency 3600
        kubernetes-redraw-frequency 3600))
;;; kubernetes-el.el ends here
