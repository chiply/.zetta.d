(use-package vc
  :ensure nil
  :commands vc-refresh-state

  :init
  (setq vc-follow-symlinks t)

  :evil
  (evil-set-initial-state 'magit-blame-mode 'emacs)
  (evil-set-initial-state 'git-commit-mode 'emacs)
  (evil-set-initial-state 'git-blame-mode 'emacs)
  (evil-set-initial-state 'git-commit-mode 'insert)
  (evil-set-initial-state 'magit-log-edit-mode 'insert))




