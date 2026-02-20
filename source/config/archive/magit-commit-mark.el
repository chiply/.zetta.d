(use-package magit-commit-mark
  :commands (magit-commit-mark-mode)
  :config
  (with-eval-after-load 'magit-log
    (define-key magit-log-mode-map (kbd ";") 'magit-commit-mark-toggle-read)
    (define-key magit-log-mode-map (kbd "M-;") 'magit-commit-mark-toggle-star)
    (define-key magit-log-mode-map (kbd "C-;") 'magit-commit-mark-toggle-urgent)))
