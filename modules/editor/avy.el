;;; avy.el --- Configure avy -*- lexical-binding: t; -*-

(use-package avy
  :ensure t
  :commands (avy-goto-char-timer evil-avy-goto-char-timer)
  :config
  (setq avy-ignored-modes
        '(image-mode doc-view-mode pdf-view-mode))

  (general-define-key :keymaps 'override
                      "s-o" 'evil-avy-goto-char-timer)

  :hook (use-package--avy--post-config . zetta-brushup))
;;; avy.el ends here
