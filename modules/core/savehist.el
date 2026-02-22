;;; savehist.el --- Configure savehist -*- lexical-binding: t; -*-

(use-package savehist
  :ensure nil
  :init
  (savehist-mode 1)
  (setq savehist-file (expand-file-name
                       ".data/savehist/history"
                       user-emacs-directory)))
;;; savehist.el ends here
