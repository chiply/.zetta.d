;;; yascroll.el --- Configure yascroll -*- lexical-binding: t; -*-

;; A scroll thumb should be findable when you look for it and invisible when
;; you are not.  The thumb faces were pinned to #ece4f6 -- a light lavender
;; from the old fixed palette -- which measures 13.65:1 against a dark
;; background: a bright bar down the window edge, and the wrong colour
;; entirely once the theme moved on.
;;
;; Derived from the brushup background gradient instead, so it stays a few
;; steps off whatever the background is and reads the same way on light and
;; dark themes.

(defcustom zetta-yascroll-thumb-step 3
  "Which `brushup-bg-N' step the scroll thumb uses.
Higher is more prominent.  Measured against a dark theme background:

  1  1.16:1   barely there
  2  1.38:1
  3  1.66:1   default -- visible when looked for, ignorable otherwise
  4  2.00:1
  5  2.6:1    starts to draw the eye"
  :type 'integer :group 'zetta)

(defun zetta-yascroll-thumb-color ()
  "The thumb colour for the current theme."
  (or (symbol-value
       (intern-soft (format "brushup-bg-%d" zetta-yascroll-thumb-step)))
      (bound-and-true-p brushup-bg-3)
      (face-foreground 'shadow nil t)))

(use-package yascroll
  :config
  (setq yascroll:delay-to-hide 0.1)
  (global-yascroll-bar-mode)

  :brushup
  (add-to-list
   'brushup-styles
   '(let ((c (zetta-yascroll-thumb-color)))
      ;; both attributes: yascroll fills the thumb with a solid block, so the
      ;; glyph and its cell have to be the same colour or it reads as striped
      (dolist (face '(yascroll:thumb-fringe yascroll:thumb-text-area))
        (when (facep face)
          (set-face-attribute face nil :foreground c :background c))))
   t))
;;; yascroll.el ends here
