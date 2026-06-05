;;; tab-bar-svg.el --- SVG multi-line tab bar (svg-line config) -*- lexical-binding: t; -*-

;; Configures the `svg-line' engine (source/zettapkg/svg-line) to render
;; the tab bar as a multi-line SVG image: per-line left/right alignment,
;; arbitrary height, no `:align-to' redisplay-freeze.  This file supplies
;; only CONTENT + styling + activation policy; the rendering lives in
;; `svg-line'.
;;
;; Switch at runtime:
;;   M-x zetta-tab-bar-use-svg       ; activate the SVG renderer
;;   M-x zetta-tab-bar-use-builtin   ; restore the built-in (text) format
;;   M-x zetta-tab-bar-toggle        ; flip
;;
;; CAVEAT: single-font SVG text -- all-the-icons / image segments tofu,
;; so the icon-rich built-in (text) format defined below is the fallback.

(require 'svg-line)

(defcustom zetta-tab-bar-svg-font-size 15
  "Font size (px) for SVG tab-bar text."
  :type 'integer :group 'zetta)

(defcustom zetta-tab-bar-svg-line-pad 4
  "Extra vertical padding (px) added to each SVG tab-bar line."
  :type 'integer :group 'zetta)

(defcustom zetta-tab-bar-svg-char-advance 7.5
  "Per-character advance (px) used to lay out rows containing inline icons.
Match it to the monospace SVG font's glyph width (Terminus at 15px = 7.5)
so iconned rows stay as tight as the plain-text rows."
  :type 'number :group 'zetta)

(defcustom zetta-tab-bar-svg-image-cache-eviction-delay 30
  "Value for `image-cache-eviction-delay' while the SVG tab bar is active.
The SVG renderer emits a new, unique bitmap on nearly every redisplay
\(keycast changes each keystroke, the clock ticks, ...); the default 300s
keeps hundreds of these one-shot images cached for five minutes.  A lower
value reclaims them sooner.

NOTE: this knob is GLOBAL -- it also governs reuse of images in eww,
pdf-tools, image-dired, nov, org inline images, etc.  Going much below
~15s can cost when revisiting those.  Set to nil to leave the global
value untouched.  Applied only while the SVG renderer is active."
  :type '(choice (const :tag "Leave untouched" nil) integer)
  :group 'zetta)

;;; ------------------------------------------------------------------
;;; Content segment functions (zetta-buffer-name, zetta-tab-bar-modal,
;;; tab-bar-keycast, ...) live in line-utils.el now; this file only
;;; composes + binds them below.
;;; ------------------------------------------------------------------

;;; ------------------------------------------------------------------
;;; Content -- rows of (LEFT-SEGMENTS . RIGHT-SEGMENTS).
;;; Segments are functions returning strings/menu-items, or literal
;;; strings; svg-line renders each exactly once.  Edit here to change
;;; what the SVG tab bar shows.
;;; ------------------------------------------------------------------
(defun zetta-tab-bar-svg-lines ()
  "Return the tab-bar content as a list of (LEFT-SEGMENTS . RIGHT-SEGMENTS).
Icons are nerd-font glyphs (plain text in `zetta-svg-line-font'), so every
side is one font-accurate text run -- no char-advance estimation, nothing
jitters as keycast changes width."
  (list
   ;; line 1 -- file-type glyph + buffer name
   (cons '(zetta-tab-bar-file-icon " "
                                   zetta-buffer-name
                                   zmc-modeline-indicator
                                   zetta-pyvenv-activate-poetry-modeline)
         ;; TEMP right-aligned probe (remove for an empty right side)
         '(tab-bar-keycast
           " "
           zetta-tab-bar-recursion-level
           " "
           recursion-indicator--string
           ))
   ;; line 2
   (cons '(zetta-tab-bar-spotify-icon " " zetta-tab-bar-spot-mode-line-string)
         '(
           ;; mu4e / clock / battery, each with its glyph (was bundled in
           ;; tab-bar-format-global; rendered explicitly so a mail glyph
           ;; sits by the unread count and a battery glyph by the level)
           zetta-tab-bar-mu4e-icon " " zetta-tab-bar-mu4e-text
           ))
   ;; line 3
   (cons '(zetta-tab-bar-modal
           zetta-gptel-processes
           blinker-tab-bar)
         '(
           zetta-tab-bar-current-thing
           zetta-tab-bar-clock " "
           zetta-tab-bar-battery-icon " " zetta-tab-bar-battery-text " "
           zetta-current-prefix " "
           zetta-tab-bar-workspace-icon " " zetta-tab-bar-workspace-text))))

(svg-line-define 'zetta-tab-bar
                 :target 'tab-bar
                 :layout 'lines
                 :width 'frame
                 :content #'zetta-tab-bar-svg-lines
                 :font (lambda () zetta-svg-line-font)
                 :font-size (lambda () (zetta-svg-line-scaled zetta-tab-bar-svg-font-size))
                 :line-pad (lambda () zetta-tab-bar-svg-line-pad)
                 :char-advance (lambda () (* zetta-tab-bar-svg-char-advance (zetta-svg-line-text-scale)))
                 :foreground (lambda () (or (bound-and-true-p brushup-fg-3)
                                            (face-foreground 'default nil t)
                                            "#cccccc")))

;;; ------------------------------------------------------------------
;;; Built-in (fallback) tab-bar format -- the text tab bar used when the
;;; SVG renderer is toggled off (`zetta-tab-bar-use-builtin').  It reuses
;;; the same content segment functions above.  Set at load so the startup
;;; hook saves it as the restore target.  Also styles the `tab-bar' face
;;; that the SVG image sits on.
;;; ------------------------------------------------------------------
(defun new-line () "\n")
(defun zetta-insert-space () " ")

(setq tab-bar-format
      '(
        ;; line 1
        zetta-buffer-name zmc-modeline-indicator
        zetta-pyvenv-activate-poetry-modeline
        ;; line 2
        new-line zetta-tab-bar-spot-mode-line-string
        ;; line 3 left-aligned
        new-line zetta-tab-bar-modal zetta-gptel-processes
        blinker-tab-bar
        ;; line 3 right-aligned
        tab-bar-format-align-right tab-bar-keycast zetta-insert-space
        zetta-tab-bar-current-thing zetta-tab-bar-recursion-level
        recursion-indicator--string tab-bar-format-global
        internal-echo-keystrokes-prefix
        zetta-insert-space zetta-current-prefix zetta-insert-space
        space-tree-modeline-lighter
        ))

(add-to-list 'brushup-styles
             '(set-face-attribute 'tab-bar nil :box nil :inherit nil :background brushup-bg)
             )

;;; ------------------------------------------------------------------
;;; Activation -- delegate rendering to svg-line, and additionally
;;; manage the global image-cache eviction window while active.
;;; ------------------------------------------------------------------
(defvar zetta-tab-bar--saved-eviction-delay nil
  "Saved `image-cache-eviction-delay' from before switching to SVG.")

(defun zetta-tab-bar-using-svg-p ()
  "Non-nil if the SVG tab bar is currently active."
  (svg-line-active-p 'zetta-tab-bar))

;;;###autoload
(defun zetta-tab-bar-use-svg ()
  "Activate the SVG tab-bar renderer (and shrink the image-cache window)."
  (interactive)
  (unless (zetta-tab-bar-using-svg-p)
    (when zetta-tab-bar-svg-image-cache-eviction-delay
      (setq zetta-tab-bar--saved-eviction-delay image-cache-eviction-delay
            image-cache-eviction-delay zetta-tab-bar-svg-image-cache-eviction-delay)))
  (svg-line-activate 'zetta-tab-bar)
  (message "tab-bar: SVG renderer active (M-x zetta-tab-bar-use-builtin to revert)"))

;;;###autoload
(defun zetta-tab-bar-use-builtin ()
  "Restore the built-in (text) tab-bar format and the image-cache window."
  (interactive)
  (svg-line-deactivate 'zetta-tab-bar)
  (when zetta-tab-bar--saved-eviction-delay
    (setq image-cache-eviction-delay zetta-tab-bar--saved-eviction-delay
          zetta-tab-bar--saved-eviction-delay nil))
  (message "tab-bar: built-in renderer active"))

;;;###autoload
(defun zetta-tab-bar-toggle ()
  "Toggle between the SVG and built-in tab-bar renderers."
  (interactive)
  (if (zetta-tab-bar-using-svg-p)
      (zetta-tab-bar-use-builtin)
    (zetta-tab-bar-use-svg)))

;;; ------------------------------------------------------------------
;;; Startup default (opt-out).  Runs from `emacs-startup-hook' so it
;;; activates AFTER the built-in format above is set -- that value is
;;; what svg-line saves as the fallback.  Sets a variable only (no
;;; rendering at hook time), so it is safe on a frameless daemon start.
;;; ------------------------------------------------------------------
(defcustom zetta-tab-bar-svg-default t
  "When non-nil, activate the SVG tab-bar renderer at startup.
Set to nil (and restart) to default to the built-in `tab-bar.el' format;
either way you can switch at runtime with `zetta-tab-bar-toggle'."
  :type 'boolean :group 'zetta)

(when zetta-tab-bar-svg-default
  (add-hook 'emacs-startup-hook #'zetta-tab-bar-use-svg))

(provide 'tab-bar-svg)
;;; tab-bar-svg.el ends here
