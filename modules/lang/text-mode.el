;;; text-mode.el --- Configure text-mode -*- lexical-binding: t; -*-

(use-package text-mode
  :ensure nil
  ;; wrap long lines in text buffers (e.g. the *L:* lsp-help buffer in
  ;; its narrow side window).  setq-local, not toggle-truncate-lines:
  ;; the toggle messages, and that jitters the minibuffer whenever a
  ;; text-mode buffer is (re)created mid-completion-session
  :hook (text-mode . (lambda () (setq-local truncate-lines nil)))
 )
;;; text-mode.el ends here
