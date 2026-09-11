;;; shell.el --- Configure shell -*- lexical-binding: t; -*-

;; `read-process-output-max' is deliberately 4MB in early-init.el, and this
;; file used to override it globally with 64MB.  That is not a buffer size
;; hint: process.c:6267 does SAFE_ALLOCA(carryover + readmax), which above
;; ~16KB becomes record_xmalloc -- so EVERY read from EVERY subprocess
;; malloc'd and freed 64MB (an mmap/munmap pair plus page faults on macOS),
;; for copilot's streaming completions, mu server and elfeed's curl alike.
;; Measured as 47 MALLOC_LARGE (empty) regions holding 52MB.  See
;; OPTIMIZATIONS.org.  A shell that genuinely needs more should set it
;; buffer-locally in a hook, not globally here.
;;
;; `process-adaptive-read-buffering' nil was global for the same reason and
;; is left off for the same one: it applies to every process, not just shells.

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
