;;; header-line-svg.el --- SVG breadcrumb header line (svg-line config) -*- lexical-binding: t; -*-

;; Configures the `svg-line' engine (github.com/chiply/svg-line) to render
;; the per-window `header-line' as a 2-line SVG image of breadcrumbs --
;; the successor to dual-header.el, now on the shared engine.  This file
;; supplies only CONTENT + styling + activation; rendering lives in
;; `svg-line'.
;;
;; The breadcrumb content (row 1 = file/path + position, row 2 =
;; lsp/org/imenu crumbs) is defined here as mode-line constructs.
;;
;; Switch at runtime:
;;   M-x zetta-header-line-use-svg    ; activate the SVG header line
;;   M-x zetta-header-line-use-none   ; remove the header line
;;   M-x zetta-header-line-toggle     ; flip

(require 'svg-line)

(declare-function breadcrumb--header-line "breadcrumb")
(declare-function breadcrumb-imenu-crumbs "breadcrumb")

;;; ------------------------------------------------------------------
;;; Breadcrumb content (zetta-header-line-svg-line1/2-format and the
;;; --line1/--line2 renderers) lives in line-utils.el now; this file
;;; only composes + binds it below.
;;; ------------------------------------------------------------------

(defcustom zetta-header-line-svg-font-size 15
  "Font size (px) for SVG header-line text." :type 'integer :group 'zetta)
(defcustom zetta-header-line-svg-line-pad 4
  "Extra vertical padding (px) per SVG header-line row." :type 'integer :group 'zetta)
(defcustom zetta-header-line-svg-background nil
  "Background painted behind the whole SVG header-line image, or nil for none.
nil -- the default -- paints nothing: the `header-line\=' face background shows
through (brushup paints it to `brushup-bg\='), so the bar is invisible apart
from its content.  The rect covers the FULL image, padding included, which
is what lets `zetta-svg-line-debug-backgrounds\=' show where each bar\='s
extents actually fall."
  :type '(choice (const :tag "Transparent" nil) color) :group 'zetta)

(defcustom zetta-header-line-svg-pad-y 5
  "Clear space INSIDE the header line's background, above the first row
and below the last.  Either a number for both ends or a cons (TOP . BOTTOM).

Padding, not margin: it sits within the painted background, so the content
reads as CENTRED IN a bar rather than as filling one -- the same relation
the tab line's pills have to their container.  Only visible when a
background is actually painted; see `zetta-svg-line-debug-backgrounds\='.

Symmetric is right for most content: the `lines\=' layout already leaves
`-line-pad\=' of slack below the last row and none above the first, which
roughly cancels the ascent gap over the first row's capitals.  A last row
ending in descenders can read a touch high -- that is what the cons form is
for."
  :type '(choice (integer :tag "Both ends")
                 (cons :tag "Uneven" (integer :tag "Top") (integer :tag "Bottom")))
  :group 'zetta)

(defcustom zetta-header-line-svg-pad 6
  "Pixels of inset between header-line content and the LEFT window edge.
Part of the frame-wide padding pass (see `zetta-frame-internal-border\='):
the bar draws itself, so its padding belongs to the renderer rather than to
a `:box\=' on the face around it -- a box would eat horizontal space the SVG,
sized to the full window width, does not know about."
  :type 'integer :group 'zetta)

(defcustom zetta-header-line-svg-margin-y '(0 . 8)
  "Inset above the first row and below the last, in pixels.
Either a number for both ends or a cons (TOP . BOTTOM).

Margin, not padding: it sits OUTSIDE the background, so it separates the
header line from its neighbours rather than enlarging it.  Nor is it
`zetta-header-line-svg-line-pad\=', which grows the space below EACH ROW.

Zero above: the tab line sits flush on top of this bar, the two being told
apart by the tab line's narrower background rather than by a gap.  The
bottom margin still carries the whole gap down to the buffer text, which has
no padding of its own to meet it halfway.

Bottom-heavy because the header line is the last chrome before the BUFFER
TEXT, which has no top padding of its own to meet it halfway -- unlike the
tab line above, whose own bottom inset pairs with the top one here."
  :type '(choice (integer :tag "Both ends")
                 (cons :tag "Uneven" (integer :tag "Top") (integer :tag "Bottom")))
  :group 'zetta)

(defcustom zetta-header-line-svg-right-margin 8
  "Pixels of inset between right-aligned content and the right window edge."
  :type 'integer :group 'zetta)

(defcustom zetta-header-line-svg-char-advance 8
  "Pixels per character used to lay out SVG header-line text.
Derived from the live font by `zetta-svg-line-derive-char-advance'; the
default only stands in before that runs." :type 'integer :group 'zetta)

;;; ------------------------------------------------------------------
;;; Content -- two left-aligned breadcrumb rows.
;;; ------------------------------------------------------------------
(defun zetta-header-line-svg-lines ()
  "Return the header line as a list of (LEFT-SEGMENTS . RIGHT-SEGMENTS)."
  (list (cons '(zetta-header-line-svg--line1)
              '(zetta-header-line-font-preset))
        (cons '(zetta-header-line-svg--line2) nil)))

(svg-line-define 'zetta-header-line
  :target 'header-line
  :layout 'lines
  :width 'window
  :content #'zetta-header-line-svg-lines
  :font (lambda () zetta-svg-line-font)
  :font-size (lambda () zetta-header-line-svg-font-size)
  :line-pad (lambda () zetta-header-line-svg-line-pad)
  :background (lambda () zetta-header-line-svg-background)
  :pad (lambda () zetta-header-line-svg-pad)
  :pad-y (lambda () zetta-header-line-svg-pad-y)
  :margin-y (lambda () zetta-header-line-svg-margin-y)
  :right-margin (lambda () zetta-header-line-svg-right-margin)
  ;; breadcrumb rows are laid out by run (clickable crumb segments), so match
  ;; the glyph width like the other bars (see `zetta-modeline-svg-char-advance')
  :char-advance (lambda () zetta-header-line-svg-char-advance)
  :foreground (lambda () (or (bound-and-true-p brushup-fg-3)
                             (face-foreground 'default nil t) "#cccccc")))

;;; ------------------------------------------------------------------
;;; Switching
;;; ------------------------------------------------------------------
(defun zetta-header-line-using-svg-p ()
  "Non-nil if the SVG header line is currently active."
  (svg-line-active-p 'zetta-header-line))

(defcustom zetta-header-line-native-format
  '((:eval (cond ((fboundp 'breadcrumb--header-line) (breadcrumb--header-line))
                 ((fboundp 'breadcrumb-imenu-crumbs) (breadcrumb-imenu-crumbs))
                 (t ""))))
  "Native (non-SVG) `header-line-format' used when the SVG line is toggled off.
Defaults to the `breadcrumb' package's own plain-text header line -- the same
\(:eval (breadcrumb--header-line)) element `breadcrumb-local-mode' installs --
so turning the SVG header line off falls back to the native breadcrumbs rather
than to no header line at all."
  :type 'sexp :group 'zetta)

;;;###autoload
(defun zetta-header-line-use-svg ()
  "Activate the SVG breadcrumb header line."
  (interactive)
  (svg-line-activate 'zetta-header-line)
  (message "header-line: SVG breadcrumbs active (M-x zetta-header-line-toggle to switch)"))

;;;###autoload
(defun zetta-header-line-use-native ()
  "Switch to the native (non-SVG) breadcrumb header line.
Deactivates the SVG renderer and installs `zetta-header-line-native-format'
as the default `header-line-format'."
  (interactive)
  (when (zetta-header-line-using-svg-p)
    (svg-line-deactivate 'zetta-header-line))
  (setq-default header-line-format zetta-header-line-native-format)
  (force-mode-line-update t)
  (message "header-line: native breadcrumbs active (M-x zetta-header-line-toggle to switch)"))

;;;###autoload
(defun zetta-header-line-use-none ()
  "Remove the header line entirely (neither SVG nor native breadcrumbs)."
  (interactive)
  (when (zetta-header-line-using-svg-p)
    (svg-line-deactivate 'zetta-header-line))
  (setq-default header-line-format nil)
  (force-mode-line-update t)
  (message "header-line: removed"))

;;;###autoload
(defun zetta-header-line-toggle ()
  "Toggle between the SVG header line and the native breadcrumb header line."
  (interactive)
  (if (zetta-header-line-using-svg-p)
      (zetta-header-line-use-native)
    (zetta-header-line-use-svg)))

;;; ------------------------------------------------------------------
;;; Startup default (opt-out) -- dual-header was on by default.  Runs
;;; from `emacs-startup-hook' (after line.el has defined the content);
;;; sets a variable only, so it is safe on a frameless daemon start.
;;; Colours are functions read on each render, so theme changes are
;;; picked up automatically (no brushup-styles entry needed).
;;; ------------------------------------------------------------------
(defcustom zetta-header-line-svg-default t
  "When non-nil, activate the SVG header line at startup.
Switch at runtime with `zetta-header-line-toggle'."
  :type 'boolean :group 'zetta)

(when zetta-header-line-svg-default
  (add-hook 'emacs-startup-hook #'zetta-header-line-use-svg))

(provide 'header-line-svg)
;;; header-line-svg.el ends here
