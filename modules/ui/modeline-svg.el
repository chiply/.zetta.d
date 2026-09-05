;;; modeline-svg.el --- SVG multi-line mode line (svg-line config) -*- lexical-binding: t; -*-

;; Configures the `svg-line' engine (github.com/chiply/svg-line) to render a
;; per-window, multi-line mode line, with active/inactive styling.  This
;; file supplies only CONTENT + styling + activation policy; rendering
;; lives in `svg-line'.
;;
;; The line has NO background of its own: it is transparent, and the
;; `mode-line' face (painted to `brushup-bg') shows through, so only the
;; material floats -- the buffer chip, the modal/ace badges, the progress
;; pie and the text.  That material therefore carries the whole
;; selected/unselected distinction: text steps from
;; `zetta-modeline-svg-fg-active' to `zetta-modeline-svg-fg-inactive', the
;; buffer chip and the accent pills step down the background ladder, and
;; the pie blends toward the background (see `zetta-modeline-svg-spans').
;;
;; Nothing on the line is coloured by hue: the modal state and the
;; ace-window key are monochrome pills whose PROMINENCE (not colour) says
;; what they are -- see `zetta-line-chip-ladder' in line-utils.el.
;;
;; Switch at runtime:
;;   M-x zetta-modeline-use-svg            ; activate this renderer
;;   M-x zetta-modeline-use-telephone-line ; restore telephone-line
;;   M-x zetta-modeline-toggle             ; flip

(require 'svg-line)

;; Colour helper from line-utils.el (modules/core), loaded before this file.
(declare-function zetta-svg-line--dim "line-utils")

;; Don't let anzu auto-cons its search count onto the mode line -- it's
;; shown via dedicated segments where relevant.  (Moved here from line.el.)
(setq anzu-cons-mode-line-p nil)

;;; ------------------------------------------------------------------
;;; Customization
;;; ------------------------------------------------------------------
(defcustom zetta-modeline-svg-font-size 15
  "Font size (px) for SVG mode-line text." :type 'integer :group 'zetta)
(defcustom zetta-modeline-svg-line-pad 4
  "Extra vertical padding (px) per SVG mode-line line." :type 'integer :group 'zetta)
(defcustom zetta-modeline-svg-char-advance 8
  "Per-character advance (px) for rows laid out by run (pies/bars/segments).
Match it to the SVG font's real glyph width as librsvg renders it (~8 for the
bitmap Terminess Nerd Font Mono at 15px scaled).  Used to position progress
pies/bars and interactive segments (clickable indicators) and to right-align
their rows; plain all-text rows use exact font anchoring and ignore it.  If a
clickable indicator's hover box sits too far left (overlapping the previous
text) raise this; if it sits too far right (a gap before the text) lower it."
  :type 'number :group 'zetta)
(defcustom zetta-modeline-svg-right-margin 8
  "Pixels of inset kept between right-aligned text and the window edge."
  :type 'integer :group 'zetta)

(defcustom zetta-modeline-svg-pie-track "none"
  "Colour of the progress pie\='s UNFILLED remainder.

\"none\" -- the default -- paints nothing there, so the unfilled part of the
disc is simply the page and only the wedge and the hairline ring are drawn.

Set a colour to get a solid disc behind the wedge.  Do NOT set it to the
page background as a way of hiding it: the frame is translucent, so an
opaque disc in the background colour shows up as a solid blob rather than
disappearing."
  :type '(choice (const :tag "Unpainted" "none") color) :group 'zetta)

(defcustom zetta-modeline-svg-pie-fill "#cacaca"
  "Colour of the progress pie\='s filled wedge.
A soft tone off the background ladder: the crisp ink outline states the
shape, and the wedge only has to say how far along it is, so it does not
need the weight.  Overridden at runtime from the theme."
  :type 'color :group 'zetta)

(defcustom zetta-modeline-svg-pie-ring "#202020"
  "Colour of the hairline ring around the progress pie.
The theme foreground -- the same ink as buffer text.  At one pixel it can
carry full ink without weighing more than the soft wedge inside it.
Overridden at runtime from the theme.

Only drawn when `zetta-modeline-svg-pie-ring-width\=' is above zero, which it
is not by default.  What the ring buys when enabled is a FOOTPRINT: at the
very top of a buffer the fraction is zero, so with no ring the pie paints
nothing at all and the indicator appears to have gone missing.  The line
still reports position as text either way."
  :type 'color :group 'zetta)

(defcustom zetta-modeline-svg-pie-ring-width 0
  "Stroke width, in pixels, of the pie\='s hairline ring.

The pie is built at exactly the span\='s pixel height (see
`zetta-modeline-svg--span-height\='), so svg-line splices it at scale 1.0 and
this lands as the width asked for rather than being multiplied by a scale
factor.

Zero -- the default -- draws NO ring at all: only the filled wedge is
painted.  `zetta-modeline-svg-pie-ring\=' keeps its colour so the ring is one
value away, and see the caveat there about what an empty buffer looks like
without it.

Sub-pixel values behave differently by display, and 0.5 is the value to use
on a HiDPI one: svg-line splices as vectors, so the stroke rasterises at
DEVICE resolution and 0.5 logical px is a true one-device-pixel hairline.
On a 1x screen there is no such pixel to land on, so the same value
antialiases to a paler line instead -- thinner-looking, but by fading rather
than by narrowing.  Use 1.0 there."
  :type 'number :group 'zetta)

(defcustom zetta-modeline-svg-margin-y 6
  "Pixels of inset above the first mode-line row and below the last.
Margin, not padding: it sits OUTSIDE the background, so it separates the
mode line from the buffer above rather than enlarging it.  Nor is it
`zetta-modeline-svg-line-pad\=', which grows the space below EACH ROW."
  :type 'integer :group 'zetta)

(defcustom zetta-modeline-svg-pad-y 5
  "Clear space INSIDE the mode line's background, above the first row
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

(defcustom zetta-modeline-svg-left-pad 6
  "Pixels of inset kept between left-aligned content and the window edge.
Used to be 0, which was invisible while the line had a background of its
own.  Now that the buffer chip is a distinct pill floating on the page, a
chip starting at x=0 reads as clipped by the window edge; this insets it."
  :type 'integer :group 'zetta)

(defcustom zetta-modeline-svg-bg-active nil
  "Background painted behind the SVG mode line in the SELECTED window.
nil -- the default -- paints nothing: the mode line is transparent and the
`mode-line' face background (which brushup paints to the buffer
background) shows through, so only the line\='s own material -- the buffer
chip, the badges, the progress pie, the text -- is visible.  Set a colour
to get a solid bar back."
  :type '(choice (const :tag "Transparent" nil) color) :group 'zetta)

(defcustom zetta-modeline-svg-bg-inactive nil
  "Background painted behind the SVG mode line in NON-selected windows.
nil = transparent, as for `zetta-modeline-svg-bg-active': with no bar to
tint, the unfocused window is marked by DIMMER MATERIAL instead -- see
`zetta-modeline-svg-fg-inactive', `zetta-modeline--lighter-bg' and the
pie in `zetta-modeline-svg-spans'."
  :type '(choice (const :tag "Transparent" nil) color) :group 'zetta)

(defcustom zetta-modeline-svg-fg-active "#4f4f4f"
  "Base text colour of the SVG mode line in the SELECTED window.
Overridden at runtime from the theme by
`zetta-svg-line-apply-brushup-palette\='."
  :type 'color :group 'zetta)

(defcustom zetta-modeline-svg-fg-inactive "#a5a5a5"
  "Base text colour of the SVG mode line in NON-selected windows.
Clearly fainter than `zetta-modeline-svg-fg-active\=': now that neither
line has a background of its own, text weight is a main carrier of the
focused/unfocused distinction."
  :type 'color :group 'zetta)

;;; ------------------------------------------------------------------
;;; Text segments (zetta-modeline-svg--modal/--vc/--flycheck/...) live in
;;; line-utils.el now; this file only composes + binds them below.
;;; ------------------------------------------------------------------

;;; ------------------------------------------------------------------
;;; Content -- rows of (LEFT-SEGMENTS . RIGHT-SEGMENTS)
;;; ------------------------------------------------------------------
(defun zetta-modeline-svg-lines ()
  "Return the mode line as rows (cons LEFT . RIGHT, or :left/:center/:right)."
  (list
   ;; line 1:  [file] modal | ace | buffer   <progress pie>   mode | line:col
   (list :left '(zetta-modeline-svg--buffer " "
                 zetta-modeline-svg--ace " "
                 zetta-modeline-svg--modal)
         :center nil
         :right '(zetta-modeline-svg--file-icon " "
                  zetta-modeline-svg--mode "  " zetta-modeline-svg--point))
   ;; line 2:  git:branch (clickable -> magit) | [copilot] lsp | flycheck | flags
   ;;          ......   doc-position
   ;; (the git + branch glyphs are folded into the clickable vc segment)
   (cons '(zetta-modeline-svg--vc " "
           zetta-modeline-svg--copilot-icon " " zetta-modeline-svg--checkers " "
           zetta-modeline-svg--flycheck " " zetta-modeline-svg--indicators)
         '(zetta-modeline-svg--docpos))))

(defun zetta-modeline-svg--span-height ()
  "Pixel height of a full-height (both rows) mode-line span.

Mirrors svg-line\='s own arithmetic -- `svg-line--scaled\=' is
\(round (* SIZE (svg-line--text-scale))), and a span\='s height is the row
height times the rows it covers.  Building the pie at exactly this size
makes svg-line splice it at scale 1.0, which is what keeps
`zetta-modeline-svg-pie-ring-width\=' honest: any other size would multiply
the hairline by the scale factor."
  (let ((sc (if (fboundp 'svg-line--text-scale) (svg-line--text-scale) 1.0)))
    (max 8 (* 2 (+ (round (* zetta-modeline-svg-font-size sc))
                   (round (* zetta-modeline-svg-line-pad sc)))))))

(declare-function svg-line--color "svg-line")

(defun zetta-modeline-svg--css-color (c)
  "Normalise colour C to a form SVG actually accepts, passing \"none\" through.

Emacs hands out colours as 12-digit \"#RRRRGGGGBBBB\" (that is what
`face-attribute\=' and the brushup palette return under many themes) and as
names, neither of which librsvg parses -- a stroke set to one silently fails
to draw.  svg-line runs every colour it is GIVEN through `svg-line--color\=',
which is why the built-in `:pie\=' span never hit this; hand-built SVG has to
do it itself.  Falls back to converting the 12-digit form locally if that
internal ever goes away."
  (cond
   ((or (null c) (equal c "none")) "none")
   ((fboundp 'svg-line--color) (svg-line--color c))
   ((string-match "\\`#\\([0-9a-fA-F]\\{4\\}\\)\\([0-9a-fA-F]\\{4\\}\\)\\([0-9a-fA-F]\\{4\\}\\)\\'" c)
    (concat "#" (substring (match-string 1 c) 0 2)
            (substring (match-string 2 c) 0 2)
            (substring (match-string 3 c) 0 2)))
   (t c)))

(defun zetta-modeline-svg--pie-svg (frac fill ring track size)
  "Return the progress pie for FRAC as an SVG string, SIZE pixels square.

Drawn here rather than with svg-line\='s built-in `:pie\=' span because that
span has no stroke: it paints a disc and a wedge and nothing else, so there
is no way to ask it for an outline.  Splicing our own SVG through the
`:image\=' span costs nothing extra -- svg-line splices it as vectors, not as
a raster -- and buys full control of the shape.

Order matters: TRACK (usually unpainted), then the FILL wedge, then the RING
last -- when there is one -- so the outline sits cleanly on top of the
wedge\='s outer edge instead of being half-covered by it.  The radius keeps
svg-line\='s own 0.86 factor, so
the pie is exactly the size it was before, and the ring path is inset by half
its stroke width so the stroke straddles inward and the footprint is unchanged."
  (let* ((c (/ size 2.0))
         (r (- (* c 0.86) (/ zetta-modeline-svg-pie-ring-width 2.0)))
         (fill (zetta-modeline-svg--css-color fill))
         (ring (zetta-modeline-svg--css-color ring))
         (track (zetta-modeline-svg--css-color track))
         (frac (max 0.0 (min 1.0 frac)))
         (theta (* 2 float-pi frac))
         (ex (+ c (* r (sin theta))))
         (ey (- c (* r (cos theta))))
         (large (if (> frac 0.5) 1 0)))
    (concat
     (format "<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d'>" size size)
     (unless (equal track "none")
       (format "<circle cx='%g' cy='%g' r='%g' fill='%s'/>" c c r track))
     (cond ((>= frac 0.999)
            (format "<circle cx='%g' cy='%g' r='%g' fill='%s'/>" c c r fill))
           ((> frac 0.001)
            (format "<path d='M %g %g L %g %g A %g %g 0 %d 1 %g %g Z' fill='%s'/>"
                    c c c (- c r) r r large ex ey fill)))
     (when (and (> zetta-modeline-svg-pie-ring-width 0)
                (not (equal ring "none")))
       (format "<circle cx='%g' cy='%g' r='%g' fill='none' stroke='%s' stroke-width='%g'/>"
               c c r ring zetta-modeline-svg-pie-ring-width))
     "</svg>")))

(declare-function zetta-contrast-ratio "line-utils")

(defcustom zetta-modeline-svg-mute-floor 3.0
  "Contrast ratio below which a pie colour is left alone instead of dimmed.
See `zetta-modeline-svg--mute\='."
  :type 'number :group 'zetta)

(defun zetta-modeline-svg--mute (color)
  "Blend COLOR toward the page for an unselected window -- if it can afford it.

Dimming only means something for a colour that has contrast to give away.
Applied to one already close to the page it does not soften it, it erases
it, and the unfocused window loses that part of the indicator altogether --
which is what happened when the pie\='s faint hairline was dimmed at the same
rate as its ink wedge.  So the blend is skipped below
`zetta-modeline-svg-mute-floor\='.

That makes the rule follow PROMINENCE rather than which field a colour
happens to sit in: whichever of the wedge and the ring is currently carrying
the ink is the one that recedes, and inverting the two needs no change here."
  (if (and (fboundp 'zetta-contrast-ratio)
           (< (zetta-contrast-ratio
               color (or (bound-and-true-p brushup-bg)
                         (face-background 'default nil t) "#ffffff"))
              zetta-modeline-svg-mute-floor))
      color
    (zetta-svg-line--dim color 0.55)))

(defun zetta-modeline-svg-spans ()
  "Centred overlay for the SVG mode line: a progress pie spanning both rows.

A hairline ring holds the circle and only the filled wedge is painted inside
it -- the unfilled remainder is the page (`zetta-modeline-svg-pie-track\=').
The ring is what makes that safe: with the wedge alone, a buffer at its very
top drew nothing at all and the indicator appeared to have broken.

The pie dims when the window is not the selected one -- it is the largest
piece of material left on a transparent mode line, and a bright one in every
window would flatten the very distinction the bar backgrounds used to make.
Which PART dims is decided by `zetta-modeline-svg--mute\=' from the colours
themselves, so swapping the wedge and the ring does not need this rule
rewritten to match."
  (let* ((total (max 1 (- (point-max) (point-min))))
         (frac (/ (float (- (point) (point-min))) total))
         (activep (mode-line-window-selected-p))
         (mute (lambda (c) (if activep c (zetta-modeline-svg--mute c)))))
    (list (list :image '(0 . 1)
                (zetta-modeline-svg--pie-svg
                 frac
                 (funcall mute zetta-modeline-svg-pie-fill)
                 (funcall mute zetta-modeline-svg-pie-ring)
                 zetta-modeline-svg-pie-track
                 (zetta-modeline-svg--span-height))))))

(svg-line-define 'zetta-mode-line
  :target 'mode-line
  :layout 'lines
  :width 'window
  :content #'zetta-modeline-svg-lines
  :spans #'zetta-modeline-svg-spans
  :active #'mode-line-window-selected-p
  :font (lambda () zetta-svg-line-font)
  :font-size (lambda () zetta-modeline-svg-font-size)
  :line-pad (lambda () zetta-modeline-svg-line-pad)
  :char-advance (lambda () zetta-modeline-svg-char-advance)
  :right-margin (lambda () zetta-modeline-svg-right-margin)
  :pad (lambda () zetta-modeline-svg-left-pad)
  :pad-y (lambda () zetta-modeline-svg-pad-y)
  :margin-y (lambda () zetta-modeline-svg-margin-y)
  :foreground (lambda () (or zetta-modeline-svg-fg-active
                             (face-foreground 'mode-line nil t) "#cccccc"))
  :inactive-foreground (lambda () (or zetta-modeline-svg-fg-inactive
                                      (face-foreground 'mode-line-inactive nil t) "#777777"))
  :background (lambda () zetta-modeline-svg-bg-active)
  :inactive-background (lambda () zetta-modeline-svg-bg-inactive))

;;; ------------------------------------------------------------------
;;; Switching between SVG and telephone-line.
;;; svg-line-activate/deactivate save and restore `mode-line-format';
;;; we additionally toggle telephone-line-mode so its full config is
;;; preserved and restored.
;;; ------------------------------------------------------------------
(defun zetta-modeline-using-svg-p ()
  "Non-nil if the SVG mode line is currently active."
  (svg-line-active-p 'zetta-mode-line))

;;;###autoload
(defun zetta-modeline-use-svg ()
  "Switch the mode line to the SVG renderer (disabling telephone-line)."
  (interactive)
  (when (and (fboundp 'telephone-line-mode) (bound-and-true-p telephone-line-mode))
    (telephone-line-mode -1))
  (svg-line-activate 'zetta-mode-line)
  ;; telephone-line leaves a buffer-local `mode-line-format' in some
  ;; buffers (e.g. *Warnings* created during startup); the default we
  ;; just set won't reach those, so drop the telephone-line leftovers so
  ;; they fall back to the SVG default.
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (and (local-variable-p 'mode-line-format)
                 (string-match-p "telephone-line" (format "%S" mode-line-format)))
        (kill-local-variable 'mode-line-format))))
  (force-mode-line-update t)
  (message "modeline: SVG renderer active (M-x zetta-modeline-use-telephone-line to revert)"))

;;;###autoload
(defun zetta-modeline-use-telephone-line ()
  "Restore the telephone-line mode line."
  (interactive)
  (svg-line-deactivate 'zetta-mode-line)
  ;; svg-line installs its renderer as the DEFAULT `mode-line-format', but some
  ;; buffers carry a buffer-local copy of it (so the restored default does not
  ;; reach them and they keep showing the SVG image).  Drop those leftovers --
  ;; the mirror of the telephone-line cleanup in `zetta-modeline-use-svg' -- so
  ;; they fall back to the telephone-line default.
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (and (local-variable-p 'mode-line-format)
                 (string-match-p "svg-line--render-zetta-mode-line"
                                 (format "%S" mode-line-format)))
        (kill-local-variable 'mode-line-format))))
  (when (fboundp 'telephone-line-mode)
    (telephone-line-mode 1))
  (force-mode-line-update t)
  (message "modeline: telephone-line active"))

;;;###autoload
(defun zetta-modeline-toggle ()
  "Toggle between the SVG and telephone-line mode lines."
  (interactive)
  (if (zetta-modeline-using-svg-p)
      (zetta-modeline-use-telephone-line)
    (zetta-modeline-use-svg)))

;;; ------------------------------------------------------------------
;;; Startup default (opt-out).  Runs from `emacs-startup-hook' so it
;;; activates AFTER telephone-line.el has configured + enabled
;;; telephone-line-mode -- that config is preserved untouched.  Sets a
;;; variable only (no rendering), so it is safe on a frameless daemon start.
;;; ------------------------------------------------------------------
(defcustom zetta-modeline-svg-default t
  "When non-nil, activate the SVG mode line at startup.
Set to nil (and restart) to keep telephone-line as the default; either
way you can switch at runtime with `zetta-modeline-toggle'.  The
telephone-line configuration in `telephone-line.el' is always preserved."
  :type 'boolean :group 'zetta)

(when zetta-modeline-svg-default
  (add-hook 'emacs-startup-hook #'zetta-modeline-use-svg))

(provide 'modeline-svg)
;;; modeline-svg.el ends here
