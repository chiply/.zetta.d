;;; emacs.el --- Configure emacs -*- lexical-binding: t; -*-

(use-package emacs
  :ensure nil
  :init
  (setq ring-bell-function #'ignore)
  :config
  (set-frame-parameter nil 'alpha-background 85)
  (add-to-list 'default-frame-alist '(alpha-background . 85))

  ;; Emacs 31: adaptive split direction (horizontal on landscape, vertical on portrait)
  (setq split-window-preferred-direction 'longest)

  ;; Emacs 31: kill buffer when quitting window instead of just burying
  (setq quit-window-kill-buffer t)

  ;; Emacs 31: collapse minor mode lighters into a single button in mode-line
  (setq mode-line-collapse-minor-modes t)

  ;; Emacs 31: show project name in mode-line for local files
  (setq project-mode-line 'non-remote)

  (setq frame-inhibit-implied-resize t)

  (general-define-key
   :keymaps 'override
   "M-q" 'fill-paragraph))
;;; emacs.el ends here
