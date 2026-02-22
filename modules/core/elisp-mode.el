;;; elisp-mode.el --- Configure elisp-mode -*- lexical-binding: t; -*-

(use-package elisp-mode
  :ensure nil
  :commands (emacs-lisp-mode lisp-interaction-mode)

  :general
  (
   :keymaps '(emacs-lisp-mode-map
              lisp-mode-map
              evil-lispy-mode-map
              lisp-interaction-mode-map)
   "<C-return>" 'eval-defun
   "<C-S-return>" 'eval-buffer
   )

  (
   :states '(normal visual)
   :keymaps '(emacs-lisp-mode-map
              lisp-mode-map
              evil-lispy-mode-map
              lisp-interaction-mode-map)
   "==" '(lambda () (interactive)
           (save-excursion
             (evil-indent (point-min) (point-max))))
   )
  )
;;; elisp-mode.el ends here
