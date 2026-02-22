;;; macrostep.el --- Configure macrostep -*- lexical-binding: t; -*-

(use-package macrostep
  :config
  (define-key emacs-lisp-mode-map (kbd "C-c e") 'macrostep-expand))
;;; macrostep.el ends here
