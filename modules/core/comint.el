(use-package comint
  :ensure nil
  :commands (comint-mode comint-run)
  :init
  (setq comint-input-ring-file-name "~/.zsh_history")
  :hook (shell-mode . (lambda () (comint-read-input-ring 'silent)))
  )
