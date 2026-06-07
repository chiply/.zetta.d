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

(defcustom zetta-tab-bar-svg-char-advance 8
  "Per-character advance (px) used to lay out rows containing pies/bars/segments.
Match it to the monospace SVG font's glyph width as librsvg renders it (~8 for
Terminess at 15px scaled) so a clickable indicator's hover box lands snugly on
its text.  Plain all-text rows use exact font anchoring and ignore this."
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
         ;; TEMP right-aligned probe (remove for an empty right side)
         '(tab-bar-keycast
           " "
           zetta-tab-bar-recursion-level
           " "
           recursion-indicator--string
           ))
   ;; line 2 -- Spotify (clickable) left; mail (clickable) right
   (cons '(zetta-tab-bar-svg--spotify)
         '(zetta-tab-bar-svg--mu4e))
   ;; line 3 -- modal (clickable) left; clock/battery/workspace (clickable) right
   (cons '(zetta-tab-bar-svg--modal
           zetta-gptel-processes
           blinker-tab-bar)
         '(
           zetta-tab-bar-current-thing
           zetta-tab-bar-svg--clock " "
           zetta-tab-bar-svg--battery " "
           zetta-current-prefix " "
           zetta-tab-bar-svg--workspace))))

(svg-line-define 'zetta-tab-bar
                 :target 'tab-bar
                 :layout 'lines
                 :width 'frame
                 :content #'zetta-tab-bar-svg-lines
                 :font (lambda () zetta-svg-line-font)
                 :font-size (lambda () zetta-tab-bar-svg-font-size)
                 :line-pad (lambda () zetta-tab-bar-svg-line-pad)
                 :char-advance (lambda () zetta-tab-bar-svg-char-advance)
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
  (zetta-tab-bar--hover-start)
  (message "tab-bar: SVG renderer active (M-x zetta-tab-bar-use-builtin to revert)"))

;;;###autoload
(defun zetta-tab-bar-use-builtin ()
  "Restore the built-in (text) tab-bar format and the image-cache window."
  (interactive)
  (svg-line-deactivate 'zetta-tab-bar)
  (zetta-tab-bar--hover-stop)
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
;;; Clickable SVG tab-bar indicators.
;;; The tab bar (unlike the mode/header/tab line) ignores a string's
;;; `keymap'/`help-echo' text properties: it routes mouse events through
;;; `tab-bar-map' -> `tab-bar-mouse-*', which read a `menu-item' property
;;; and select tabs.  So we advise those commands to first hit-test our
;;; segment placements (via the svg-line engine) and dispatch the
;;; indicator's :action (left click) or :menu (right click); off our
;;; indicators they fall through to the default tab-bar behaviour.
;;; ------------------------------------------------------------------
(declare-function svg-line--seg-at-posn "svg-line")
(declare-function svg-line--popup-menu "svg-line")

(defun zetta-tab-bar--svg-item-at (event)
  "Return the svg-line tab-bar item (LABEL . PLIST) under EVENT, or nil."
  (and (fboundp 'svg-line--seg-at-posn)
       (svg-line-active-p 'zetta-tab-bar)
       (let ((it (svg-line--seg-at-posn 'zetta-tab-bar (event-start event))))
         (and (consp it) (consp (cdr it)) it))))

(defun zetta-tab-bar--mouse-down-1-advice (orig event &rest args)
  "Run an svg-line indicator's :action on click, else the default tab-bar action."
  (let* ((it (zetta-tab-bar--svg-item-at event))
         (cmd (and it (plist-get (cdr it) :action))))
    (if cmd (call-interactively cmd)
      (apply orig event args))))

(defun zetta-tab-bar--context-menu-advice (orig event &rest args)
  "Pop an svg-line indicator's :menu on right-click, else the default context menu."
  (let* ((it (zetta-tab-bar--svg-item-at event))
         (menu (and it (plist-get (cdr it) :menu))))
    (if menu (svg-line--popup-menu (car it) menu)
      (apply orig event args))))

(with-eval-after-load 'tab-bar
  (advice-add 'tab-bar-mouse-down-1 :around #'zetta-tab-bar--mouse-down-1-advice)
  (advice-add 'tab-bar-mouse-context-menu :around #'zetta-tab-bar--context-menu-advice))

;;; ------------------------------------------------------------------
;;; Hover for the SVG tab-bar.
;;; The mode/header/tab line re-evaluate a string's `help-echo' FUNCTION
;;; as the mouse moves over their image, which both shows the echo help
;;; and drives the hover box (via `svg-line--note-help').  The tab bar
;;; does NOT -- it treats the whole image as one item and never calls our
;;; help-echo per position.  So we poll the mouse with a short timer while
;;; the SVG tab bar is active: when the pointer is over one of our
;;; indicators, feed its (tagged) help through `show-help-function' -- the
;;; same path the other bars use -- which shows the echo help AND sets the
;;; hovered id so the box is drawn.
;;; ------------------------------------------------------------------
(defvar zetta-tab-bar--hover-timer nil
  "Repeating timer that drives SVG tab-bar hover; nil when not running.")
(defvar zetta-tab-bar--hover-was-over nil
  "Non-nil if the last poll found the pointer over an SVG tab-bar indicator.")

(defun zetta-tab-bar--hover-poll ()
  "Drive hover help/highlight for the SVG tab bar from the mouse position."
  (when (and (bound-and-true-p svg-line-hover-highlight)
             (fboundp 'svg-line--seg-at-posn)
             (svg-line-active-p 'zetta-tab-bar)
             (functionp show-help-function))
    (let* ((mp (mouse-pixel-position))
           (frame (car mp)) (mx (cadr mp)) (my (cddr mp))
           (posn (and (framep frame) (integerp mx) (integerp my)
                      (ignore-errors (posn-at-x-y mx my frame))))
           (over (and posn (eq (posn-area posn) 'tab-bar)))
           (item (and over (svg-line--seg-at-posn 'zetta-tab-bar posn)))
           (help (and item (fboundp 'svg-line--tab-help) (svg-line--tab-help item))))
      ;; Only touch the help machinery while over the tab bar, or on the one
      ;; poll right after leaving it (to clear) -- so we never fight the other
      ;; bars' own help-echo for the shared hovered state.
      (cond
       (over
        (ignore-errors (funcall show-help-function help))
        (setq zetta-tab-bar--hover-was-over t))
       (zetta-tab-bar--hover-was-over
        (ignore-errors (funcall show-help-function nil))
        (setq zetta-tab-bar--hover-was-over nil))))))

(defun zetta-tab-bar--hover-start ()
  "Start the SVG tab-bar hover poll timer (idempotent)."
  (unless (timerp zetta-tab-bar--hover-timer)
    (setq zetta-tab-bar--hover-timer
          (run-with-timer 0.12 0.12 #'zetta-tab-bar--hover-poll))))

(defun zetta-tab-bar--hover-stop ()
  "Stop the SVG tab-bar hover poll timer."
  (when (timerp zetta-tab-bar--hover-timer)
    (cancel-timer zetta-tab-bar--hover-timer))
  (setq zetta-tab-bar--hover-timer nil zetta-tab-bar--hover-was-over nil))

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
