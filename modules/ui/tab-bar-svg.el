;;; tab-bar-svg.el --- SVG multi-line tab bar (svg-line config) -*- lexical-binding: t; -*-

;; Configures the `svg-line' engine (github.com/chiply/svg-line) to render
;; the tab bar as a multi-line SVG image: per-line left/right alignment,
;; arbitrary height, no `:align-to' redisplay-freeze.  This file supplies
;; only CONTENT + styling + activation policy; the rendering lives in
;; `svg-line'.
;;
;; Switch at runtime:
;;   M-x zetta-tab-bar-use-svg       ; activate the SVG renderer
;;   M-x zetta-tab-bar-use-default   ; restore the stock tab-bar.el tabs
;;   M-x zetta-tab-bar-use-builtin   ; restore the custom multi-line text format
;;   M-x zetta-tab-bar-toggle        ; flip SVG <-> default
;;
;; CAVEAT: single-font SVG text -- all-the-icons / image segments tofu,
;; so the icon-rich built-in (text) format defined below is the fallback.

(require 'svg-line)
(require 'svg-lib nil t)   ; for the svg-lib-date calendar page (optional)

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
  "When non-nil, draw a full-height major-mode-icon masthead at the left of the tab bar."
  :type 'boolean :group 'zetta)

(defcustom zetta-tab-bar-svg-icon-color "#6c4dab"
  "Fill colour for the tab-bar masthead major-mode icon (a purple that fits the theme)."
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
   ;; line 1 -- file glyph + buffer (left); keycast + recursion + thing-at-point (right)
   (cons '(zetta-tab-bar-file-icon " "
                                   zetta-tab-bar-svg--buffer
                                   zmc-modeline-indicator
                                   zetta-pyvenv-activate-poetry-modeline)
         '(zetta-tab-bar-svg--keycast " "
           zetta-tab-bar-recursion-icon " " zetta-tab-bar-recursion-level " "
           recursion-indicator--string))
   ;; line 2 -- modal etc left; <analog clock spans the centre>; mail right
   (list :left '(zetta-tab-bar-svg--modal " "
                 zetta-tab-bar-current-thing
                 zetta-gptel-processes
                 blinker-tab-bar)
         :center nil
         :right '(zetta-tab-bar-svg--elfeed "  " zetta-tab-bar-svg--mu4e))
   ;; line 3 -- Spotify left; clock centre (it spans all 3 rows); battery/prefix/space-tree right
   (list :left '(zetta-tab-bar-svg--spotify)
         :center nil
         :right '(zetta-tab-bar-svg--battery " "
                  zetta-current-prefix "  "
                  zetta-tab-bar-svg--workspace))))

(defcustom zetta-tab-bar-calendar-color "#9aa0aa"
  "Gray colour for the tab-bar clock and the minimalist date widget (kept uniform)."
  :type 'color :group 'zetta)

(defun zetta-tab-bar-svg-spans ()
  "Analog clock spanning all three rows in the centre.
The sunrise/sunset flank and the date/moon-phase widget were removed."
  (let ((gray zetta-tab-bar-calendar-color))
    (list (list :clock '(0 . 2) gray gray))))

(defvar zetta-tab-bar-svg--clock-timer nil
  "Periodic timer that re-renders the SVG tab bar so the analog clock ticks.")
(unless zetta-tab-bar-svg--clock-timer
  (setq zetta-tab-bar-svg--clock-timer
        (run-at-time t 30 (lambda ()
                            (when (and (fboundp 'zetta-tab-bar-using-svg-p)
                                       (zetta-tab-bar-using-svg-p))
                              (force-mode-line-update t))))))

;; Pin the tab bar's buffer-dependent segments (buffer name, file icon,
;; modal state, thing-at-point, ...) to the buffer the user came FROM
;; while a minibuffer is active.  Completion previews flip the selected
;; window's buffer on every candidate (original <-> previewed buffer),
;; and without pinning each flip re-rendered the bar with different
;; content -- alternating images repainting ~90px of frame top, a
;; visible flash -- while keycast should (and does) stay live.
(defvar zetta-tab-bar--minibuffer-entry-buffer nil
  "The buffer current when the (outermost) minibuffer session began.")

(defun zetta-tab-bar--note-minibuffer-entry ()
  (when (= (minibuffer-depth) 1)
    (setq zetta-tab-bar--minibuffer-entry-buffer
          (window-buffer (minibuffer-selected-window)))))

(add-hook 'minibuffer-setup-hook #'zetta-tab-bar--note-minibuffer-entry)

(defun zetta-tab-bar--context-buffer ()
  "The stable content context: the entry buffer during minibuffer sessions."
  (and (> (minibuffer-depth) 0)
       (buffer-live-p zetta-tab-bar--minibuffer-entry-buffer)
       zetta-tab-bar--minibuffer-entry-buffer))

(svg-line-define 'zetta-tab-bar
                 :target 'tab-bar
                 :layout 'lines
                 :width 'frame
                 :context-buffer #'zetta-tab-bar--context-buffer
                 :content #'zetta-tab-bar-svg-lines
                 :spans #'zetta-tab-bar-svg-spans
                 :font (lambda () zetta-svg-line-font)
                 :font-size (lambda () zetta-tab-bar-svg-font-size)
                 :line-pad (lambda () zetta-tab-bar-svg-line-pad)
                 :char-advance (lambda () zetta-tab-bar-svg-char-advance)
                 :icon (lambda () (and zetta-tab-bar-svg-icon
                                       (fboundp 'zetta-tab-bar-mode-icon)
                                       (zetta-tab-bar-mode-icon)))
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
          ;; svg-line segment wrapper (spacetree.el) — colors the
          ;; selected spaces purple; text properties don't survive
          ;; svg-line's flattening, so the bare lighter can't.
          zetta-tab-bar-space-tree
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

(defcustom zetta-tab-bar-default-format
  '(tab-bar-format-history tab-bar-format-tabs tab-bar-separator
                           tab-bar-format-add-tab)
  "Stock `tab-bar.el' format restored by `zetta-tab-bar-use-default'.
This is the ordinary Emacs default (history, tabs, separator, add-tab
button), so toggling the SVG tab bar off shows the plain text tab bar with
real tabs -- rather than the custom multi-line text reproduction that
`zetta-tab-bar-use-builtin' installs."
  :type 'sexp :group 'zetta)

;;;###autoload
(defun zetta-tab-bar-use-default ()
  "Restore the stock (non-SVG) `tab-bar.el' format with real tabs.
Deactivates the SVG renderer, installs `zetta-tab-bar-default-format', and
restores the image-cache eviction window."
  (interactive)
  (when (zetta-tab-bar-using-svg-p)
    (svg-line-deactivate 'zetta-tab-bar))
  (setq tab-bar-format zetta-tab-bar-default-format)
  (when zetta-tab-bar--saved-eviction-delay
    (setq image-cache-eviction-delay zetta-tab-bar--saved-eviction-delay
          zetta-tab-bar--saved-eviction-delay nil))
  (force-mode-line-update t)
  (message "tab-bar: default tab-bar active (M-x zetta-tab-bar-toggle to switch)"))

;;;###autoload
(defun zetta-tab-bar-use-builtin ()
  "Restore the custom built-in (multi-line text) tab-bar format.
This reproduces the zetta status content (buffer name, modal indicator,
keycast, ...) as a plain-text tab bar.  For the stock `tab-bar.el' tabs use
`zetta-tab-bar-use-default' instead."
  (interactive)
  (svg-line-deactivate 'zetta-tab-bar)
  (when zetta-tab-bar--saved-eviction-delay
    (setq image-cache-eviction-delay zetta-tab-bar--saved-eviction-delay
          zetta-tab-bar--saved-eviction-delay nil))
  (message "tab-bar: built-in renderer active"))

;;;###autoload
(defun zetta-tab-bar-toggle ()
  "Toggle between the SVG tab bar and the default `tab-bar.el' format."
  (interactive)
  (if (zetta-tab-bar-using-svg-p)
      (zetta-tab-bar-use-default)
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
