;;; face.el --- Configure face and frame settings -*- lexical-binding: t; -*-

(add-to-list 'default-frame-alist '(fullscreen . maximized))
(setq initial-frame-alist (quote ((fullscreen . maximized))))

;;; Frame padding -- the `spacious-padding' look, without the package.
;;
;; Prot's spacious-padding gets its spacing from three places: this frame
;; border, a wide right divider (see window.el) and a `:box' on the mode-line
;; and header-line faces.  The first two are plain frame parameters and are
;; taken here; the third is NOT usable in this config -- those bars are single
;; full-window-width SVG images, and a face box would eat horizontal space the
;; image does not know about, clipping the right-aligned segments.  Their
;; padding is done inside the renderers instead (`:pad'/`:pad-y' on each
;; svg-line spec), which is also the only way to pad the tab line at all,
;; since it draws through the `tab-line' face rather than the per-tab faces
;; spacious-padding boxes.
;;
;; Set through `default-frame-alist' rather than applied per frame: that
;; covers frames the daemon makes later (emacsclient, `make-frame') by
;; construction, which is the lifecycle a package would otherwise hand-roll
;; with `after-make-frame-functions' + `server-after-make-frame-hook'.
;; `frame-inner-width' excludes this border, so the frame-width SVG tab bar
;; still sizes correctly against it.

(defcustom zetta-frame-internal-border 15
  "Pixels of padding between the frame edge and its text area.
Emacs defaults to 2.  Also applied to existing frames when set through
`zetta-set-frame-internal-border'."
  :type 'integer :group 'zetta)

(defun zetta-set-frame-internal-border (&optional width)
  "Apply WIDTH (default `zetta-frame-internal-border') to new and live frames."
  (interactive (list (read-number "Internal border: " zetta-frame-internal-border)))
  (let ((w (or width zetta-frame-internal-border)))
    (setq zetta-frame-internal-border w)
    (setf (alist-get 'internal-border-width default-frame-alist) w)
    (dolist (f (frame-list))
      (set-frame-parameter f 'internal-border-width w))))

(zetta-set-frame-internal-border)

;; The border is painted with the `internal-border' face; unstyled it can fall
;; back to a colour that reads as a frame outline rather than as padding.
(add-to-list 'brushup-styles
             '(when (facep 'internal-border)
                (set-face-attribute 'internal-border nil :background brushup-bg))
             t)

(defun transparency (value)
  (interactive "nTransparency Value 0 - 100 opaque:")
  (set-frame-parameter (selected-frame) 'alpha value))
(transparency 93)

(defun zetta-theme-brushup ()
  (interactive)
  (setq prefix-help-command 'repeatable--versatile-C-h)
  (when debug-on-error
    (toggle-debug-on-error)
    (message "Debug-on-error is off"))
  (when (fboundp 'brushup)
    (brushup)))

(general-define-key
 :keymaps 'menu-theme-map
 "T" (** zetta-theme-brushup))

(general-define-key
 :keymaps 'menu-window-map
 "t" 'menu-theme-map
 "T" (** transparency))

(add-hook 'help-mode-hook (lambda () (text-scale-set -2)))
(add-hook 'Info-mode-hook (lambda () (text-scale-set -2)))
(add-hook 'calendar-mode-hook (lambda () (text-scale-set 2)))
;;; face.el ends here
