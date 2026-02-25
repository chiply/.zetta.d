;;; bootstrap-brushup.el --- Configure brushup -*- lexical-binding: t; -*-
;; Upstream: https://github.com/chiply/brushup

(use-package brushup
  :ensure (:host github :repo "chiply/brushup")
  :demand t
  :config
  (brushup-mode 1))

;; Block until brushup is installed — downstream modules use brushup
;; palette variables and the :brushup use-package keyword synchronously.
(elpaca-wait)

;; Fallback when package is unavailable (e.g., CI with stale/missing cache)
(unless (fboundp 'brushup)
  (defvar brushup-styles '())
  (defvar brushup-fg "#ffffff")
  (defvar brushup-bg "#000000")
  (defvar brushup-bg-1 "#1a1a1a")
  (defvar brushup-bg-1_0 "#0d0d0d")
  (defvar brushup-bg-2 "#333333")
  (defvar brushup-bg-3 "#4d4d4d")
  (defvar brushup-bg-4 "#666666")
  (defvar brushup-bg-5 "#808080")
  (defvar brushup-bg-6 "#999999")
  (defvar brushup-fg-1 "#e6e6e6")
  (defvar brushup-fg-2 "#cccccc")
  (defvar brushup-fg-3 "#b3b3b3")
  (defvar brushup-fg-4 "#999999")
  (defvar brushup-fg-5 "#808080")
  (defvar brushup-fg-6 "#666666")
  (defvar brushup-dark-p t)
  (defun brushup () nil))

(provide 'bootstrap-brushup)
;;; bootstrap-brushup.el ends here
