;;; emacs.el --- Configure emacs -*- lexical-binding: t; -*-

(use-package emacs
  :ensure nil
  :init
  (setq ring-bell-function #'ignore)
  :config
  (general-define-key
   :keymaps 'override
   "M-q" 'fill-paragraph))
;;; emacs.el ends here
