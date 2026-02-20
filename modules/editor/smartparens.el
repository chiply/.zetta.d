(use-package smartparens
  :init
  (setq sp-highlight-pair-overlay nil)
  (smartparens-global-mode t)
  (show-smartparens-global-mode t)

  (setq smartparen-modes '(python-ts-mode rjsx-mode js2-mode web-mode css-mode sql-mode))

  (sp-local-pair smartparen-modes "{" nil :post-handlers '(:add ("||\n[i]" "RET")))
  (sp-local-pair smartparen-modes "(" nil :post-handlers '(:add ("||\n[i]" "RET")))
  (sp-local-pair smartparen-modes "[" nil :post-handlers '(:add ("||\n[i]" "RET")))

  (sp-local-pair '(emacs-lisp-mode) "'" "'" :actions nil)
  (sp-local-pair '(emacs-lisp-mode) "`" "`" :actions nil)
  )
