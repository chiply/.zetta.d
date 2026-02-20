;; -*- lexical-binding: t; -*-

;;; bootstrap-brushup.el --- Dynamic theme-aware color palette -*- lexical-binding: t; -*-
;; Standalone version: https://github.com/chiply/brushup

;;; Commentary:
;;
;; Brushup provides a dynamic color palette that adapts to any theme.
;; It generates gradient colors from the current theme's foreground/background,
;; allowing package face customizations to work consistently across themes.
;;
;; Usage in package configs:
;;   (add-to-list 'brushup-styles
;;     '(set-face-attribute 'some-face nil :background brushup-bg-2))
;;
;; Or with use-package:
;;   :brushup
;;   (add-to-list 'brushup-styles '(...))
;;
;; The styles are re-evaluated whenever the theme changes.
;;
;; Available palette variables:
;;   brushup-fg, brushup-bg     - Theme's foreground/background
;;   brushup-fg-1 to brushup-fg-6 - Foreground gradient (toward bg)
;;   brushup-bg-1 to brushup-bg-6 - Background gradient (toward fg)
;;   brushup-bg-1_0              - Subtle bg shift (for solaire-like effects)
;;   brushup-dark-p              - t if current theme is dark

;;; Code:

(require 'color)

;;;; Configuration

(defvar brushup-gradient-step 7
  "Percentage step for each gradient level.")

;;;; Palette variables

(defvar brushup-dark-p t "Non-nil if current theme is dark.")
(defvar brushup-fg "#ffffff" "Theme foreground color.")
(defvar brushup-bg "#000000" "Theme background color.")

;; Foreground gradient (1=slight, 6=strong shift toward bg)
(defvar brushup-fg-1 "#e6e6e6")
(defvar brushup-fg-2 "#cccccc")
(defvar brushup-fg-3 "#b3b3b3")
(defvar brushup-fg-4 "#999999")
(defvar brushup-fg-5 "#808080")
(defvar brushup-fg-6 "#666666")

;; Background gradient (1=slight, 6=strong shift toward fg)
(defvar brushup-bg-1 "#1a1a1a")
(defvar brushup-bg-1_0 "#0d0d0d" "Subtle bg shift for solaire-like effects.")
(defvar brushup-bg-2 "#333333")
(defvar brushup-bg-3 "#4d4d4d")
(defvar brushup-bg-4 "#666666")
(defvar brushup-bg-5 "#808080")
(defvar brushup-bg-6 "#999999")

;;;; Core functions

(defun brushup--color-valid-p (color)
  "Return non-nil if COLOR is a valid, specified color."
  (and color
       (not (string-prefix-p "unspecified" (format "%s" color)))
       (color-name-to-rgb color)))

(defun brushup--theme-dark-p ()
  "Return non-nil if current theme appears dark."
  (let ((bg (face-background 'default)))
    (when (brushup--color-valid-p bg)
      (let ((lum (nth 2 (apply #'color-rgb-to-hsl (color-name-to-rgb bg)))))
        (< lum 0.5)))))

(defun brushup--generate-gradient (base-color steps direction)
  "Generate gradient colors from BASE-COLOR.
STEPS is the number of gradient levels.
DIRECTION is 1 for lighter, -1 for darker."
  (let ((step brushup-gradient-step))
    (cl-loop for i from 1 to steps
             collect (color-lighten-name base-color (* i step direction)))))

(defun brushup-init ()
  "Initialize brushup palette from current theme colors.
Called automatically on startup and theme changes."
  (let ((fg (face-attribute 'default :foreground))
        (bg (face-attribute 'default :background)))
    (when (and (brushup--color-valid-p fg)
               (brushup--color-valid-p bg))
      ;; Normalize color names
      (setq brushup-fg (if (equal fg "black") "#000000" fg)
            brushup-bg (if (equal bg "white") "#ffffff" bg)
            brushup-dark-p (brushup--theme-dark-p))

      ;; Generate foreground gradient (toward background)
      (let ((fg-gradient (brushup--generate-gradient
                          brushup-fg 6
                          (if brushup-dark-p -1 1))))
        (setq brushup-fg-1 (nth 0 fg-gradient)
              brushup-fg-2 (nth 1 fg-gradient)
              brushup-fg-3 (nth 2 fg-gradient)
              brushup-fg-4 (nth 3 fg-gradient)
              brushup-fg-5 (nth 4 fg-gradient)
              brushup-fg-6 (nth 5 fg-gradient)))

      ;; Generate background gradient (toward foreground)
      (let ((bg-gradient (brushup--generate-gradient
                          brushup-bg 6
                          (if brushup-dark-p 1 -1))))
        (setq brushup-bg-1 (nth 0 bg-gradient)
              brushup-bg-2 (nth 1 bg-gradient)
              brushup-bg-3 (nth 2 bg-gradient)
              brushup-bg-4 (nth 3 bg-gradient)
              brushup-bg-5 (nth 4 bg-gradient)
              brushup-bg-6 (nth 5 bg-gradient)))

      ;; Special subtle background shift
      (setq brushup-bg-1_0 (color-lighten-name brushup-bg -3)))))

;;;; Style system

(defvar brushup-styles '()
  "List of forms to evaluate when brushup runs.
Each form typically calls `set-face-attribute' using brushup palette variables.")

(defun brushup--eval-style (form)
  "Safely evaluate a brushup style FORM."
  (condition-case err
      (eval form t)
    (error (message "brushup: error in style: %s" (error-message-string err)))))

(defun brushup ()
  "Refresh all brushup styles.
Re-initializes the palette and evaluates all registered styles."
  (interactive)
  ;; Always init palette first so styles use current theme colors
  (brushup-init)
  (mapc #'brushup--eval-style brushup-styles))

;;;; Default face overrides

(defun brushup--apply-base-faces ()
  "Apply brushup's base face customizations."
  (when window-system
    ;; Region
    (set-face-attribute 'region nil
                        :background (if brushup-dark-p
                                        (color-lighten-name brushup-fg -60)
                                      brushup-bg-3)
                        :foreground 'unspecified)
    ;; Mode line
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
                        :foreground brushup-bg-6
                        :background brushup-bg
                        :underline nil :box nil)
    ;; Header line
    (set-face-attribute 'header-line nil
                        :background brushup-bg
                        :underline nil :box nil :inherit nil)
    ;; Comments and docs
    (let ((comment-color (if brushup-dark-p
                             (color-lighten-name brushup-bg 40)
                           (color-lighten-name brushup-bg -50))))
      (set-face-attribute 'font-lock-comment-face nil
                          :foreground comment-color :slant 'normal)
      (set-face-attribute 'font-lock-doc-face nil
                          :foreground comment-color :slant 'normal))
    ;; Misc
    (set-face-attribute 'font-lock-string-face nil :slant 'normal)
    (set-face-attribute 'sh-heredoc nil :foreground brushup-fg :weight 'normal)
    (set-face-attribute 'button nil
                        :foreground brushup-fg :background brushup-bg
                        :box nil :underline t)
    (set-face-attribute 'minibuffer-prompt nil
                        :foreground brushup-fg :background brushup-bg-1_0)
    (set-face-background 'fringe brushup-bg)
    ;; Cursor
    (set-face-attribute 'cursor nil :background brushup-fg)))

(add-to-list 'brushup-styles '(brushup--apply-base-faces))

;;;; Font normalization

(defun brushup--normalize-fonts ()
  "Remove italic slant from all faces.
Run after theme changes to enforce consistent typography."
  (mapc (lambda (face)
          (when (face-attribute face :slant nil t)
            (set-face-attribute face nil :slant 'normal)))
        (face-list)))

(add-to-list 'brushup-styles '(brushup--normalize-fonts))

;;;; use-package integration

;; The :brushup keyword is a convenience for adding to brushup-styles.
;; It's equivalent to putting (add-to-list 'brushup-styles ...) in :config.
(defalias 'use-package-handler/:brushup 'use-package-handle-forms)
(defalias 'use-package-normalize/:brushup 'use-package-normalize-forms)
(add-to-list 'use-package-keywords :brushup t)

;;;; Hooks

;; Initialize on startup
(add-hook 'emacs-startup-hook #'brushup)

;; Re-apply on theme change
(add-hook 'enable-theme-functions (lambda (_theme) (brushup)))

;; Re-apply when first GUI frame connects (daemon mode)
;; In daemon mode, window-system is nil at startup so face overrides
;; are skipped. This hook ensures they apply once a display is available.
(add-hook 'server-after-make-frame-hook #'brushup)

;; Alias for backward compatibility (z-brushup → zetta-brushup)
(defalias 'zetta-brushup 'brushup)

(provide 'bootstrap-brushup)

;;; bootstrap-brushup.el ends here
