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
(defcustom zetta-modeline-svg-char-advance-ratio 0.5
  "Per-character advance, as a fraction of the font size, for run layout.
Set from the bar's own font by `zetta-svg-line-derive-char-advance'; the
default only stands in before that runs.  Used to position progress pies and
bars and interactive segments (clickable indicators) and to right-align their
rows; plain all-text rows use exact font anchoring and ignore it."
  :type 'number :group 'zetta)

(define-obsolete-variable-alias 'zetta-modeline-svg-char-advance
  'zetta-modeline-svg-char-advance-ratio "2026-09-07")
(defcustom zetta-modeline-svg-seg-shape 'arrow
  "Background shape for the mode line\'s chips.

`arrow\' is a powerline chevron -- square left edge, right edge drawn to a
point.  The tab line keeps its rounded pills (`round\'), and that difference
is the point: the two bars carry different KINDS of thing.  A tab is an
object you can click and switch to, and a rounded pill is the shape
interfaces have used for a selectable token for decades.  A mode-line chip
is a reading of state -- which mode, which branch, how far down the buffer
-- and a chevron reads as a strip of readings rather than a row of buttons.

`square\' and `slant\' are the other ways to not be a pill: see
`svg-line--seg-box\'."
  :type '(choice (const :tag "Rounded pill" round)
                 (const :tag "Square" square)
                 (const :tag "Powerline chevron" arrow)
                 (const :tag "Parallelogram" slant))
  :group 'zetta)

(defcustom zetta-modeline-svg-seg-slant nil
  "How deep the chevron cuts into a mode-line chip, in pixels.
nil takes svg-line\'s default, ~0.3 of the row height.  The angle is cut
INTO the chip, eating the padding its label already carries, so raising this
eats into the label rather than into the gap after it."
  :type '(choice (const :tag "Default (~0.3 row height)" nil) integer)
  :group 'zetta)

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
   ;; line 1:  buffer | modal ....... [file] mode | line:col | percent
   ;; (no ace badge: the window key is a PROMPT, shown only while one is
   ;; being asked for, and it is asked for in the tab line -- which every
   ;; buffer has and not every buffer has one of these.  See
   ;; `zetta-tab-line-svg--ace-item'.)
   (list :left '(zetta-modeline-svg--buffer " "
                 zetta-modeline-svg--modal)
         :center nil
         :right '(zetta-modeline-svg--file-icon " "
                  zetta-modeline-svg--mode "  " zetta-modeline-svg--point))
   ;; line 2:  git:branch (clickable -> magit) | [copilot] lsp | flycheck | flags
   ;;          ......   doc-position   <progress pie, under the percent>
   ;; (the git + branch glyphs are folded into the clickable vc segment)
   (cons '(zetta-modeline-svg--vc " "
           zetta-modeline-svg--copilot-icon " " zetta-modeline-svg--checkers " "
           zetta-modeline-svg--flycheck " " zetta-modeline-svg--indicators)
         '(zetta-modeline-svg--docpos))))

(defun zetta-modeline-svg--span-height (&optional rows)
  "Pixel height of a ROWS-high mode-line span (one row by default).

Mirrors svg-line\='s own arithmetic -- `svg-line--scaled\=' is
\(round (* SIZE (svg-line--text-scale))), and a span\='s height is the row
height times the rows it covers.  Building the pie at exactly this size
makes svg-line splice it at scale 1.0, which is what keeps
`zetta-modeline-svg-pie-ring-width\=' honest: any other size would multiply
the hairline by the scale factor."
  (let ((sc (if (fboundp 'svg-line--text-scale) (svg-line--text-scale) 1.0)))
    (max 8 (* (or rows 1)
              (+ (round (* zetta-modeline-svg-font-size sc))
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

(declare-function zetta-modeline-svg--docpos "line-utils")

(defun zetta-modeline-svg--pie-gap ()
  "Pixels to inset the pie from the right window edge.

`zetta-modeline-svg-right-margin\=' -- so the pie\='s right edge lands on the
same line as the percentage above it -- plus room for anything row 2 already
right-aligns there.  That is `zetta-modeline-svg--docpos\=': empty in most
buffers, the page counter in a PDF.  A span is an OVERLAY, so it does not
push text aside the way another segment would; when there IS text there the
pie steps left of it instead of over it.

Scaled here, unlike the spec options: svg-line scales what it is given
through `svg-line-define\=', but a span is handed to it already in its own
pixel space."
  (let* ((doc (and (fboundp 'zetta-modeline-svg--docpos)
                   (zetta-modeline-svg--docpos)))
         (text (cond ((stringp doc) doc)
                     ((and (consp doc) (eq (car doc) :svg-seg)) (cadr doc))
                     (t "")))
         (sc (if (fboundp 'svg-line--text-scale) (svg-line--text-scale) 1.0)))
    (round (* sc (+ zetta-modeline-svg-right-margin
                    (if (> (length text) 0)
                        ;; the counter plus a space, at the run layout\='s advance
                        (* (1+ (length text))
                           zetta-modeline-svg-font-size
                           zetta-modeline-svg-char-advance-ratio)
                      0))))))

(defun zetta-modeline-svg-spans ()
  "Overlay for the SVG mode line: a progress pie at the right of row 2.

It sits one row high directly under the percentage in
`zetta-modeline-svg--point\=', which is the same reading in the other
notation -- a number and a shape in one column at the right edge, rather
than a disc floating in the middle of the line.

A hairline ring holds the circle and only the filled wedge is painted inside
it -- the unfilled remainder is the page (`zetta-modeline-svg-pie-track\=').
The ring is what makes that safe: with the wedge alone, a buffer at its very
top drew nothing at all and the indicator appeared to have broken.

The pie dims when the window is not the selected one -- material on a
transparent mode line is what carries the focused/unfocused distinction, and
a bright pie in every window would flatten it.  Which PART dims is decided by
`zetta-modeline-svg--mute\=' from the colours themselves, so swapping the
wedge and the ring does not need this rule rewritten to match."
  (let* ((total (max 1 (- (point-max) (point-min))))
         (frac (/ (float (- (point) (point-min))) total))
         (activep (mode-line-window-selected-p))
         (mute (lambda (c) (if activep c (zetta-modeline-svg--mute c)))))
    (list (list :image '(1 . 1)
                (zetta-modeline-svg--pie-svg
                 frac
                 (funcall mute zetta-modeline-svg-pie-fill)
                 (funcall mute zetta-modeline-svg-pie-ring)
                 zetta-modeline-svg-pie-track
                 (zetta-modeline-svg--span-height))
                'right
                (zetta-modeline-svg--pie-gap)))))

(svg-line-define 'zetta-mode-line
  :target 'mode-line
  :layout 'lines
  :width 'window
  :content #'zetta-modeline-svg-lines
  :spans #'zetta-modeline-svg-spans
  :active #'mode-line-window-selected-p
  :seg-shape (lambda () zetta-modeline-svg-seg-shape)
  :seg-slant (lambda () zetta-modeline-svg-seg-slant)
  :font (lambda () (zetta-svg-line-font-for :mode-line))
  :font-size (lambda () zetta-modeline-svg-font-size)
  :line-pad (lambda () zetta-modeline-svg-line-pad)
  :char-advance-ratio (lambda () zetta-modeline-svg-char-advance-ratio)
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
;;; A bare variant: the ace badge and nothing else.
;;; ------------------------------------------------------------------
;; For buffers you glance at and dismiss -- *Messages*, *Backtrace*,
;; *Warnings*.  Almost nothing on the full line has anything to say about
;; one of those: no file, no VC, no checkers, and a position that means
;; nothing because you are not editing.  The ace key is the exception, and
;; the reason this is a bare line rather than no line: those are precisely
;; the windows you want to jump OUT of, so the one thing worth showing is
;; how to leave.
;;
;; Defined but deliberately never `svg-line-activate\='d -- activating a
;; `mode-line\=' line makes it the DEFAULT for every buffer.  This one is
;; installed per buffer, by `zetta-window-chrome-rules\='
;; (modules/ui/window-chrome.el).

(defvar-local zetta-modeline-svg-bare-extra nil
  "Segments appended after the ace badge in the bare mode line.

A list in the same form as a side of `zetta-modeline-svg-lines': strings,
function symbols, or `svg-line-seg' tokens.  Buffer-local, so a buffer that
wants the minimal line PLUS one thing of its own -- the treemacs sidebar
and its directory -- can say so without needing a whole mode line of its
own.  See `treemacs.el'.")

(defun zetta-modeline-svg-bare-lines ()
  "Content for the bare mode line: one row of `zetta-modeline-svg-bare-extra'.

Which used to be the ace badge plus that.  The badge has moved to the tab
line and shows only while a window is being picked
\(`zetta-tab-line-svg--ace-item'), so what is left here is whatever the
buffer itself asked for -- and for most buffers that is nothing, which is
why `zetta-modeline-svg-bare-format' returns nil rather than an empty bar."
  (list (list :left zetta-modeline-svg-bare-extra
              :center nil :right nil)))

(svg-line-define 'zetta-mode-line-bare
  :target 'mode-line
  :layout 'lines
  :width 'window
  :content #'zetta-modeline-svg-bare-lines
  :active #'mode-line-window-selected-p
  :seg-shape (lambda () zetta-modeline-svg-seg-shape)
  :seg-slant (lambda () zetta-modeline-svg-seg-slant)
  ;; Same measurements and colours as the full line: this is the SAME bar
  ;; with less in it, and a badge that changed size or tone between buffers
  ;; would read as a different kind of window rather than a quieter one.
  :font (lambda () (zetta-svg-line-font-for :mode-line))
  :font-size (lambda () zetta-modeline-svg-font-size)
  :line-pad (lambda () zetta-modeline-svg-line-pad)
  :char-advance-ratio (lambda () zetta-modeline-svg-char-advance-ratio)
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

(defun zetta-modeline-svg-bare-format ()
  "Return a `mode-line-format' rendering this buffer's minimal mode line.

Nil when the buffer has nothing to put on one -- and a nil
`mode-line-format' is the only way to have NO bar: a format that renders
an empty image still occupies a row.  So a buffer that wanted the minimal
line only for the ace badge now gets no mode line at all, which is the
point: the key is in the tab line, and the tab line is the bar every
buffer has.

`svg-line-define' names each line's renderer `svg-line--render-NAME' and
wraps it in exactly this form when it installs one.  We build the same form
by hand because we want it in ONE buffer, not as the default -- which is
all `svg-line-activate' can do for a `mode-line' target."
  (and zetta-modeline-svg-bare-extra
       '((:eval (svg-line--render-zetta-mode-line-bare)))))

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
