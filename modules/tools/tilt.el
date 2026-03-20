;;; tilt.el --- Tiltfile support with LSP -*- lexical-binding: t; -*-

(define-derived-mode tiltfile-mode python-mode "Tiltfile"
  "Major mode for Tilt Dev Tiltfiles."
  (setq-local case-fold-search nil))

(add-to-list 'auto-mode-alist '("Tiltfile\\'" . tiltfile-mode))

(with-eval-after-load 'lsp-mode
  (add-to-list 'lsp-language-id-configuration
               '(tiltfile-mode . "tiltfile"))
  (lsp-register-client
   (make-lsp-client :new-connection (lsp-stdio-connection '("tilt" "lsp" "start"))
                    :activation-fn (lsp-activate-on "tiltfile")
                    :server-id 'tilt-lsp)))

;;; tilt.el ends here
