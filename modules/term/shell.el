;;; shell.el --- Configure shell -*- lexical-binding: t; -*-



(setq read-process-output-max (* 64 1024 1024))
(setq process-adaptive-read-buffering nil)
;; LEAVE THIS COMMENT HERE
;;(let ((process-connection-type nil))
;;(async-shell-command command buffer))

;; remembering sudo pass
(require 'em-tramp)
(setq password-cache t)
(setq password-cache-expiry 3600)

(use-package shell
  :ensure nil
  :commands shell
  :general
  (
   :keymaps '(shell-command-mode-map)
   "C" 'zetta-highlight-phrases
   "S-<tab>" 'compilation-previous-error
   )

  :hook (shell-command-mode . (lambda () (progn
                                           (text-scale-set -2)
                                           (zetta-highlight-phrases)
                                           (when (and
                                                  (boundp 'zmc-async-shell-command-spinners-enable)
                                                  zmc-async-shell-command-spinners-enable)
                                             (zetta-spinner-compile-spin)))))
  )


(setq shell-file-name "zsh")
(setq shell-command-switch "-c")
;;; shell.el ends here
