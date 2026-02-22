;;; super-save.el --- Configure super-save -*- lexical-binding: t; -*-

(use-package super-save
  :config
  (setq super-save-auto-save-when-idle nil)
  (setq super-save-remote-files nil)
  (add-to-list 'super-save-triggers 'ace-window 'delete-window)
  (super-save-mode +1)
  )
;;; super-save.el ends here
