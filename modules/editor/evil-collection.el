;;; evil-collection.el --- Configure evil-collection -*- lexical-binding: t; -*-

(use-package evil-collection
  :after evil
  :config
  (evil-collection-init)
  (evil-set-initial-state 'org-agenda-mode 'normal))
;;; evil-collection.el ends here
