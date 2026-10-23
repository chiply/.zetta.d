;;; smartparens.el --- Configure smartparens -*- lexical-binding: t; -*-

(use-package smartparens
  :init
  (setq sp-highlight-pair-overlay nil)
  (smartparens-global-mode t)
  ;; Not `show-smartparens-global-mode': `show-paren-mode' is on already,
  ;; and the two ran independent match scans on every command.


  (setq smartparen-modes '(python-ts-mode rjsx-mode js2-mode web-mode css-mode sql-mode))

  (sp-local-pair smartparen-modes "{" nil :post-handlers '(:add ("||\n[i]" "RET")))
  (sp-local-pair smartparen-modes "(" nil :post-handlers '(:add ("||\n[i]" "RET")))
  (sp-local-pair smartparen-modes "[" nil :post-handlers '(:add ("||\n[i]" "RET")))

  (sp-local-pair '(emacs-lisp-mode) "'" "'" :actions nil)
  (sp-local-pair '(emacs-lisp-mode) "`" "`" :actions nil)
  )
;;; smartparens.el ends here
