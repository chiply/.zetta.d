;;; helpful.el --- Configure helpful -*- lexical-binding: t; -*-

(use-package helpful
  :commands (helpful-callable helpful-function helpful-variable helpful-key
             helpful-command helpful-at-point helpful-symbol)
  :init

  (defun zetta-helpful-at-point ()
    (interactive)
    (let ((buf (current-buffer)))
      (helpful-at-point)
      (select-window (get-buffer-window buf))
      )
    )

  (setq helpful-switch-buffer-function 'display-buffer)

  (defun zetta-soda-cap-help ()
    (interactive)
    (zetta-soda-cap "[H|h]elp*" 1))

  (general-define-key
   :keymaps 'menu-run-map
   "H" (repeatable-wrap zetta-soda-cap-help))

  :general
  (
   :keymaps 'menu-help-map
   "c" 'helpful-command
   "f" 'helpful-function
   "v" 'helpful-variable
   "h" 'zetta-jump-to-doc
   "k" 'helpful-key
   "a" 'helm-apropos
   "A" 'apropos
   "m" 'zetta-describe-mode
   "i" 'info
   )

  :hook (helpful-mode . (lambda () (text-scale-set -2)))
  )
;;; helpful.el ends here
