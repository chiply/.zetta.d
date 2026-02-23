;;; dired-subtree.el --- Configure dired-subtree -*- lexical-binding: t; -*-

(use-package dired-hacks
  :ensure (dired-hacks :host github :repo "Fuco1/dired-hacks"
           :files ("dired-hacks-utils.el" "dired-subtree.el" "dired-ranger.el")))
(use-package dired-subtree :ensure nil :after dired-hacks)
;;; dired-subtree.el ends here
