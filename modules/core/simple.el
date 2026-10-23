;;; simple.el --- Configure simple -*- lexical-binding: t; -*-

(use-package simple
  :ensure nil ;; builtin
  :commands (shell-command async-shell-command)
  :init
  ;; 10000 entries, serialised whole to savehist every 300 s and marked on
  ;; every GC (770 entries / 711 KB after 26 min, OPTIMIZATIONS.org); the
  ;; Emacs default is 120.
  (setq kill-ring-max 500)
  :config

  ;; NOTE commenting out to prevent shell-command-to-string from
  ;; writing to history
  ;;(advice-add 'shell-command :after
  ;;(lambda (&rest args)
  ;;(append-to-zsh-history (car args))))
  (advice-add 'async-shell-command :after
              (lambda (&rest args)
                (append-to-zsh-history (car args))))

  (defun zetta-shell-command ()
    (interactive)
    (let ((shell-command-history (parse-zsh-history "~/.zsh_history")))
      (call-interactively 'shell-command)))

  (defun zetta-async-shell-command ()
    (interactive)
    (let ((shell-command-history (parse-zsh-history "~/.zsh_history")))
      (call-interactively 'async-shell-command)))

  :general
  (
   :keymaps 'override
   "M-&" 'zetta-async-shell-command
   "M-!" 'zetta-shell-command
   )

  )
;;; simple.el ends here
