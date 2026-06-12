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
   ;; line 3 -- Spotify left; calendar centre; space-tree (+battery/prefix) right
   (list :left '(zetta-tab-bar-svg--spotify)
         :center nil
         :right '(zetta-tab-bar-svg--battery " "
                  zetta-current-prefix "  "
                  zetta-tab-bar-svg--workspace))))

(defun zetta-tab-bar-calendar ()
  "Calendar glyph + weekday/day/month/year, for the SVG tab bar's last row."
  (concat (and (featurep 'nerd-icons)
               (ignore-errors (concat (nerd-icons-mdicon "nf-md-calendar_month") " ")))
          (format-time-string "%a  %d %b %Y")))

(defcustom zetta-tab-bar-calendar-color "#9aa0aa"
  "Gray colour for the tab-bar clock and the minimalist date widget (kept uniform)."
  :type 'color :group 'zetta)

(defconst zetta-tab-bar--moon-glyph-names
  ["nf-md-moon_new" "nf-md-moon_waxing_crescent" "nf-md-moon_first_quarter"
   "nf-md-moon_waxing_gibbous" "nf-md-moon_full" "nf-md-moon_waning_gibbous"
   "nf-md-moon_last_quarter" "nf-md-moon_waning_crescent"]
  "Nerd Font moon glyphs indexed by lunar octant (0=new, 4=full).")

(defun zetta-tab-bar--moon-octant ()
  "Return the current lunar octant 0-7 (0=new, 2=first quarter, 4=full, 6=last).
Phase age is days since the 2000-01-06 18:14 UTC new moon, modulo the mean
synodic month (29.530588853 d), rounded to the nearest eighth."
  (let* ((synodic 29.530588853)
         (ref 947182440.0)                       ; 2000-01-06 18:14 UTC, epoch seconds
         (days (/ (- (float-time) ref) 86400.0))
         (cycles (/ days synodic))
         (frac (- cycles (floor cycles))))
    (mod (round (* frac 8)) 8)))

(defun zetta-tab-bar--moon-glyph ()
  "Raw (unpropertized) Nerd Font glyph for the current moon phase, or nil."
  (when (require 'nerd-icons nil t)
    (let ((g (ignore-errors
               (nerd-icons-mdicon
                (aref zetta-tab-bar--moon-glyph-names (zetta-tab-bar--moon-octant))))))
      (and g (substring-no-properties g)))))

(defun zetta-tab-bar-calendar--build ()
  "Build the minimalist date widget as an svg.el DOM (spliced as vectors, sharp):
an outlined weekday badge + an outlined date box (small month over big day) +
the current moon-phase glyph, monochrome in `zetta-tab-bar-calendar-color'."
  (let* ((col zetta-tab-bar-calendar-color)
         (h 30) (gap (round (* h 0.24))) (wd-w (round (* h 1.05))) (pw (round (* h 0.98)))
         (rx (max 2 (round (* h 0.16))))
         ;; vertical inset so the outline stroke isn't clipped at the bar edge
         (vm 2) (bh (- h (* 2 vm)))
         (svg (svg-create 600 h)) (x 0))
    ;; weekday -- outlined
    (svg-rectangle svg x vm wd-w bh :rx rx :fill "none" :stroke col :stroke-width 1.5)
    (svg-text svg (upcase (format-time-string "%a")) :x (+ x (/ wd-w 2)) :y (round (* h 0.69))
              :text-anchor "middle" :font-family "Helvetica" :font-size (round (* h 0.46)) :font-weight "bold" :fill col)
    (setq x (+ x wd-w gap))
    ;; date -- outlined box, small month over big day
    (svg-rectangle svg x vm pw bh :rx rx :fill "none" :stroke col :stroke-width 1.5)
    (svg-text svg (upcase (format-time-string "%b")) :x (+ x (/ pw 2)) :y (round (* h 0.36))
              :text-anchor "middle" :font-family "Helvetica" :font-size (round (* h 0.27)) :font-weight "bold" :fill col)
    (svg-text svg (format-time-string "%-d") :x (+ x (/ pw 2)) :y (round (* h 0.88))
              :text-anchor "middle" :font-family "Helvetica" :font-size (round (* h 0.5)) :font-weight "bold" :fill col)
    (setq x (+ x pw))
    ;; moon phase -- nerd-font glyph to the right of the date box
    (let ((moon (zetta-tab-bar--moon-glyph)))
      (when moon
        (setq x (+ x gap))
        (svg-text svg moon :x (+ x (round (* h 0.34))) :y (round (* h 0.74))
                  :text-anchor "middle" :font-family "Terminess Nerd Font Mono"
                  :font-size (round (* h 0.78)) :fill col)
        (setq x (+ x (round (* h 0.68))))))
    (dom-set-attribute svg 'width (number-to-string x))
    svg))

(defvar zetta-tab-bar-calendar--cache nil
  "Cons of (DAY-KEY . SVG-DOM) so the date widget is rebuilt at most once a day.")
(defun zetta-tab-bar-calendar-image ()
  "The date-widget SVG DOM, rebuilt only when the day changes."
  (let ((key (format-time-string "%Y%m%d")))
    (if (equal (car zetta-tab-bar-calendar--cache) key)
        (cdr zetta-tab-bar-calendar--cache)
      (cdr (setq zetta-tab-bar-calendar--cache (cons key (zetta-tab-bar-calendar--build)))))))

;;; ------------------------------------------------------------------
;;; Sunrise / sunset (flanking the clock on the first row).  Needs a
;;; location for `solar-sunrise-sunset'; set it here (only when unset, so
;;; an explicit setting elsewhere wins) so the feature works at startup.
;;; ------------------------------------------------------------------
(with-eval-after-load 'solar
  (unless (numberp (bound-and-true-p calendar-latitude))
    (setq calendar-latitude 39.95
          calendar-longitude -75.17
          calendar-location-name "Philadelphia, PA"
          calendar-time-zone -300
          calendar-standard-time-zone-name "EST"
          calendar-daylight-time-zone-name "EDT")))

(defun zetta-tab-bar--fmt-suntime (decimal)
  "Format DECIMAL hours (0-24) as a 24-hour \"HH:MM\" string."
  (let* ((h24 (floor decimal))
         (m (round (* 60 (- decimal h24)))))
    (when (= m 60) (setq m 0 h24 (1+ h24)))
    (format "%02d:%02d" (mod h24 24) m)))

(defun zetta-tab-bar--compute-sun ()
  "Compute ((SUNRISE . GLYPH) . (SUNSET . GLYPH)) for the clock flank.
Returns nil if `solar'/`nerd-icons' or a location is unavailable."
  (when (and (require 'solar nil t) (require 'nerd-icons nil t)
             (numberp (bound-and-true-p calendar-latitude))
             (numberp (bound-and-true-p calendar-longitude)))
    (let* ((ss (ignore-errors (solar-sunrise-sunset (calendar-current-date))))
           (rise (car ss)) (set (cadr ss))
           (rise-s (and (numberp (car rise)) (zetta-tab-bar--fmt-suntime (car rise))))
           (set-s  (and (numberp (car set))  (zetta-tab-bar--fmt-suntime (car set))))
           (gr (ignore-errors (substring-no-properties (nerd-icons-wicon "nf-weather-sunrise"))))
           (gs (ignore-errors (substring-no-properties (nerd-icons-wicon "nf-weather-sunset")))))
      ;; Each side is (TIME . GLYPH); the `:flank' span draws the glyph nearest
      ;; the clock at a larger size and the time on its outer side.
      (cons (and rise-s gr (cons rise-s gr))
            (and set-s gs (cons set-s gs))))))

(defvar zetta-tab-bar--sun-cache nil
  "Cons of (DAY-KEY . (LEFT . RIGHT)) so sunrise/sunset compute once a day.")
(defun zetta-tab-bar--sun-strings ()
  "The (LEFT . RIGHT) sunrise/sunset flank strings, recomputed once a day."
  (let ((key (format-time-string "%Y%m%d")))
    (if (equal (car zetta-tab-bar--sun-cache) key)
        (cdr zetta-tab-bar--sun-cache)
      (cdr (setq zetta-tab-bar--sun-cache (cons key (zetta-tab-bar--compute-sun)))))))

(defun zetta-tab-bar-svg-spans ()
  "Analog clock spanning lines 1-2 (centre), sunrise/sunset flanking it on the
first row; the date widget (with moon phase) below, on the last row."
  (let* ((gray zetta-tab-bar-calendar-color)
         (cal (zetta-tab-bar-calendar-image))
         (sun (zetta-tab-bar--sun-strings)))
    (append
     (list (list :clock '(0 . 1) gray gray))
     (and sun (or (car sun) (cdr sun))
          (list (list :flank '(0 . 1) (car sun) (cdr sun) gray)))
     (and cal (list (list :image '(2 . 2) cal 'center))))))

(defvar zetta-tab-bar-svg--clock-timer nil
  "Periodic timer that re-renders the SVG tab bar so the analog clock ticks.")
(unless zetta-tab-bar-svg--clock-timer
  (setq zetta-tab-bar-svg--clock-timer
        (run-at-time t 30 (lambda ()
                            (when (and (fboundp 'zetta-tab-bar-using-svg-p)
                                       (zetta-tab-bar-using-svg-p))
                              (force-mode-line-update t))))))

(svg-line-define 'zetta-tab-bar
                 :target 'tab-bar
                 :layout 'lines
                 :width 'frame
                 :content #'zetta-tab-bar-svg-lines
                 :spans #'zetta-tab-bar-svg-spans
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
