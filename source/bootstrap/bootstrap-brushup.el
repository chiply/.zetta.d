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

;; Base face overrides using brushup palette
(defun zetta-brushup-base-faces ()
  "Apply base face customizations using brushup palette."
  (when window-system
    (set-face-attribute 'region nil
                        :background (if brushup-dark-p
                                        (color-lighten-name brushup-fg -60)
                                      brushup-bg-3)
                        :foreground 'unspecified)
    (set-face-attribute 'mode-line nil
                        :background brushup-bg-1_0
                        :foreground 'unspecified
                        :box nil :underline nil :overline nil)
    (when (facep 'mode-line-active)
      (set-face-attribute 'mode-line-active nil
                          :background brushup-bg-1_0
                          :foreground 'unspecified
                          :box nil :underline nil :overline nil))
    (set-face-attribute 'mode-line-inactive nil
                        :foreground (if brushup-dark-p brushup-bg-6 brushup-fg-4)
                        :background brushup-bg-1_0
                        :underline nil :box nil)
    (set-face-attribute 'header-line nil
                        :background brushup-bg
                        :underline nil :box nil :inherit nil)
    (let ((comment-color (if brushup-dark-p
                             (color-lighten-name brushup-bg 40)
                           (color-lighten-name brushup-bg -50))))
      (set-face-attribute 'font-lock-comment-face nil
                          :foreground comment-color :slant 'normal)
      (set-face-attribute 'font-lock-doc-face nil
                          :foreground comment-color :slant 'normal))
    (set-face-attribute 'font-lock-string-face nil :slant 'normal)
    (when (facep 'sh-heredoc)
      (set-face-attribute 'sh-heredoc nil :foreground brushup-fg :weight 'normal))
    (set-face-attribute 'button nil
                        :foreground brushup-fg :background brushup-bg
                        :box nil :underline t)
    (set-face-attribute 'minibuffer-prompt nil
                        :foreground brushup-fg :background brushup-bg-1_0)
    (set-face-background 'fringe brushup-bg)))

(add-to-list 'brushup-styles '(zetta-brushup-base-faces))


(provide 'bootstrap-brushup)
;;; bootstrap-brushup.el ends here
