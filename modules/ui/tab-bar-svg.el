;;; tab-bar-svg.el --- SVG multi-line tab bar (svg-line config) -*- lexical-binding: t; -*-

;; Configures the `svg-line' engine (github.com/chiply/svg-line) to render
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

(defcustom zetta-tab-bar-svg-char-advance 8
  "Per-character advance (px) used to lay out rows containing pies/bars/segments.
Match it to the monospace SVG font's glyph width as librsvg renders it (~8 for
Terminess at 15px scaled) so a clickable indicator's hover box lands snugly on
its text.  Plain all-text rows use exact font anchoring and ignore this."
  :type 'number :group 'zetta)

(defcustom zetta-tab-bar-svg-icon t
  "When non-nil, draw a full-height Emacs-logo masthead at the left of the tab bar."
  :type 'boolean :group 'zetta)

(defcustom zetta-tab-bar-svg-icon-color "#6c4dab"
  "Fill colour for the tab-bar masthead icon (a purple that fits the theme)."
  :type 'color :group 'zetta)

(defcustom zetta-tab-bar-svg-icon-width 'square
  "Horizontal space reserved for the masthead icon.
`square' reserves the bar's full height (a square cell, icon centred); an
integer reserves that many pixels; nil reserves just past the glyph ink (tight,
flush-left)."
  :type '(choice (const :tag "Square (full height)" square)
                 (const :tag "Tight (ink width)" nil)
                 integer)
  :group 'zetta)

(defcustom zetta-tab-bar-svg-icon-scale 1.9
  "Masthead icon size as a fraction of the tab bar's full height.
Nerd-Font icon glyphs only ink ~half their em box, so values >1 are normal:
the glyph is scaled past the bar height (the empty em overflow is clipped) so
its visible ink fills the height."
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
   ;; line 1 -- file-type glyph + buffer name (buffer name is clickable)
   (cons '(zetta-tab-bar-file-icon " "
                                   zetta-tab-bar-svg--buffer
                                   zmc-modeline-indicator
                                   zetta-pyvenv-activate-poetry-modeline)
         ;; keycast (caps-kbd glyph, padding trimmed) + recursion depth (hierarchy glyph)
         '(zetta-tab-bar-svg--keycast
           " "
           zetta-tab-bar-recursion-icon " " zetta-tab-bar-recursion-level
           " "
           recursion-indicator--string
           ))
   ;; line 2 -- Spotify left; workspace (space-tree) centered; mail right
   (list :left '(zetta-tab-bar-svg--spotify)
         :center '(zetta-tab-bar-svg--workspace)
         :right '(zetta-tab-bar-svg--mu4e))
   ;; line 3 -- modal (clickable) left; current-thing centered;
   ;;           clock/battery (clickable) right
   (list :left '(zetta-tab-bar-svg--modal
                 zetta-gptel-processes
                 blinker-tab-bar)
         :center '(zetta-tab-bar-current-thing)
         :right '(zetta-tab-bar-svg--clock " "
                  zetta-tab-bar-svg--battery " "
                  zetta-current-prefix))))

(svg-line-define 'zetta-tab-bar
                 :target 'tab-bar
                 :layout 'lines
                 :width 'frame
                 :content #'zetta-tab-bar-svg-lines
                 :font (lambda () zetta-svg-line-font)
                 :font-size (lambda () zetta-tab-bar-svg-font-size)
                 :line-pad (lambda () zetta-tab-bar-svg-line-pad)
                 :char-advance (lambda () zetta-tab-bar-svg-char-advance)
                 :icon (lambda () (and zetta-tab-bar-svg-icon
                                       (fboundp 'zetta-tab-bar-emacs-icon)
                                       (zetta-tab-bar-emacs-icon)))
                 :icon-color (lambda () zetta-tab-bar-svg-icon-color)
                 :icon-width (lambda () zetta-tab-bar-svg-icon-width)
                 :icon-scale (lambda () zetta-tab-bar-svg-icon-scale)
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

;; Guard so RE-loading this file (with the SVG renderer already active)
;; doesn't clobber the live `tab-bar-format' the renderer is installed on --
;; svg-line saved this built-in value at activation and restores it itself.
(unless (and (fboundp 'svg-line-active-p) (svg-line-active-p 'zetta-tab-bar))
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
          )))

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

;;; Clickable + hover-aware tab-bar indicators are handled by the svg-line
;;; engine itself (it advises the tab-bar mouse commands and runs a hover poll
;;; whenever a `tab-bar'-target svg-line is active), so nothing is needed here.

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
