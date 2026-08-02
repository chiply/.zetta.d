;;; evil-collection.el --- Configure evil-collection -*- lexical-binding: t; -*-

(use-package evil-collection
  :after evil
  :config
  ;; app/nano-mu4e.el owns mu4e modal behavior (per-mode evil states +
  ;; an evil-overriding nano-mu4e-mode-map).  evil-collection-mu4e's
  ;; evil-define-key aux maps outrank that overriding map, hijacking
  ;; C-j/C-k/g r — so keep its mu4e module out entirely.
  (setq evil-collection-mode-list (remove 'mu4e evil-collection-mode-list))
  (evil-collection-init)
  (evil-set-initial-state 'org-agenda-mode 'normal))
;;; evil-collection.el ends here
