(use-package spray
  ;; NOTE doesn't work with evil, which is why I have the custom functions belowkj
  :ensure (spray :type git :host github :repo "emacsmirror/spray")
  :commands (zetta-spray-mode)
  :config
  (defun zetta-spray-mode ()
    (interactive)
    (evil-emacs-state)
    (text-scale-increase 2.0)
    (spray-mode))

  (defun zetta-spray-quit ()
    (interactive)
    (evil-normal-state)
    (spray-quit))

  :general
  (
   :keymaps 'spray-mode-map
   "q" 'zetta-spray-quit
   "C-g" 'zetta-spray-quit
   )

  )



