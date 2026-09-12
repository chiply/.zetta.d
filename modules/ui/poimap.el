;;; poimap.el --- Buffer map in the SVG mode line -*- lexical-binding: t; -*-

;; Loads the `poimap' package (https://github.com/florommel/poimap) and draws
;; its buffer map INSIDE the svg-line mode line rather than beside it, fed by
;; the svg-margin providers this config already has.
;;
;; The pairing is the point.  svg-margin (modules/ui/svg-margin.el) marks up
;; the lines that are ON SCREEN -- VC hunks, diagnostics, TODOs, marks, Org
;; structure, hygiene, symbol occurrences.  poimap draws the WHOLE buffer as
;; one strip.  Registering the same providers against both means the two
;; surfaces speak one vocabulary: the same colour and the same rough shape
;; means the same thing near the text and out at the end of the file, and the
;; map is the part of it you cannot otherwise see.
;;
;; Two things make this cheap rather than a second implementation:
;;
;;   - poimap splits into `poimap-string' (its own mode-line construct, which
;;     we do NOT want) and `poimap--svg', which returns raw SVG markup at an
;;     explicit width and height.  svg-line's `:image' span takes exactly
;;     that and splices it as vectors.  So the map is one more span on a bar
;;     that already draws one (the progress pie).
;;
;;   - both packages model the same thing -- buffer position to indicator --
;;     so `zetta-poimap--marks' replays an svg-margin provider's output
;;     through poimap's shape functions.  No provider is written twice, and
;;     the colours stay on the theme's ink ladder because they are the ones
;;     `zetta-svg-margin--color' already chose.
;;
;; What is deliberately NOT here: clicking.  `poimap-string' hangs a keymap
;; off its own propertized space; inside svg-line the whole bar is one image
;; and spans register no hot-spots, so the map draws but does not respond to
;; the mouse.  `poimap-mouse' is reusable if that is wanted later -- it needs
;; a `poimap-width' window parameter (set below) and an image-map rectangle.

;; brushup's palette (bootstrap-brushup.el), read by `zetta-poimap-apply-palette'
;; and by the `:brushup' registration below.
(defvar brushup-styles)
(defvar brushup-bg)
(defvar brushup-bg-1)
(defvar brushup-bg-2)
(defvar brushup-fg-2)
(defvar brushup-dark-p)
(defvar brushup-gradient-step)

(use-package poimap
  ;; `:files' pins the build to the core.  The repo also ships optional
  ;; provider files (poimap-bm, poimap-swiper, ...) whose Package-Requires
  ;; name bm/ivy/swiper -- none of which are wanted here, and all of which
  ;; elpaca would otherwise install to satisfy the byte-compile.  The
  ;; providers come from svg-margin instead.
  :ensure (:host github :repo "florommel/poimap" :files ("poimap.el") :wait t)
  :brushup
  (add-to-list 'brushup-styles '(zetta-poimap-apply-palette)))

;; `nil t' (no-error) for the same reason as in svg-margin.el: `use-package'
;; installs and loads poimap at LOAD time (`:wait t'), but compile-angel
;; byte-compiles this file as it loads, and at COMPILE time elpaca has not
;; built the package yet.  The symbols used below are declared so it
;; compiles cleanly either way.
(require 'poimap nil t)
(require 'cl-lib)
(require 'color)

(declare-function poimap--svg "poimap")
(declare-function poimap--live-window "poimap")
(declare-function poimap-map-position "poimap")
(declare-function poimap-update-pois "poimap")
(declare-function poimap-update-all "poimap")
(declare-function poimap-emacs-to-svg-color "poimap")
(declare-function poimap-ellipse "poimap")
(declare-function poimap-diamond "poimap")
(declare-function poimap-xcross "poimap")
(declare-function poimap-tick "poimap")
(declare-function poimap-mode "poimap")
(defvar poimap-mode)
(defvar poimap--pois)
(defvar poimap-add-to-mode-line)
(defvar poimap-idle-update-functions)
(defvar poimap-border-width)
(defvar poimap-point-width)
(defvar poimap-min-range-size)
(defvar poimap-background-alpha)
(defvar poimap-background-inactive-alpha)
(defvar poimap-visible-window-alpha)
(defvar poimap-visible-window-inactive-alpha)
(defvar poimap-border-alpha)
(defvar poimap-mode-line-string)

;; From svg-margin.el (the provider registry we read) and modeline-svg.el /
;; line-utils.el / svg-line (the bar we draw into).
(defvar svg-margin--providers)
(defvar zetta-modeline-svg-extra-rows)
(defvar zetta-modeline-svg-extra-spans)
(defvar zetta-modeline-svg-font-size)
(defvar zetta-modeline-svg-line-pad)
(defvar zetta-modeline-svg-left-pad)
(defvar zetta-modeline-svg-right-margin)
(declare-function zetta-modeline-svg--pie-gap "modeline-svg")
(declare-function zetta-svg-line-font-for "line-utils")
(declare-function zetta-svg-margin--color "svg-margin")
(declare-function svg-line--text-scale "svg-line")
(declare-function svg-line--font-size-for "svg-line")
(declare-function svg-line--window-width "svg-line")
(declare-function svg-line--parse-svg "svg-line")

;;; ------------------------------------------------------------------
;;; Customization
;;; ------------------------------------------------------------------

(defcustom zetta-poimap-placement 'row
  "Where the buffer map sits on the SVG mode line.

`row'   -- its own full-width row below the other two.  The default, and
           the one that makes the map READABLE: horizontal pixels are the
           map's entire resolution, and at a few hundred of them a busy
           file's marks pile into a smear.  Costs one row of bar height.

`right' -- an overlay on row 2, right-aligned, left of the progress pie,
           `zetta-poimap-width' wide.  Adds no height.  A span is an
           OVERLAY and reserves no room (see svg-line's `:image'), so this
           paints over row 2's left content in a buffer with enough on it
           -- several checkers plus a long branch name will reach under the
           map.  Row 2's right side (the doc position) is cleared for it.

Use `zetta-poimap-toggle-placement' to switch."
  :type '(choice (const :tag "Its own full-width row" row)
                 (const :tag "Overlay at the right of row 2" right))
  :group 'zetta)

(defcustom zetta-poimap-width 0.3
  "Width of the map under the `right' placement: pixels, or a window fraction.
Ignored under `row', which always spans the full content width."
  :type '(choice (integer :tag "Fixed pixels") (float :tag "Window fraction"))
  :group 'zetta)

(defcustom zetta-poimap-rows 1
  "How many mode-line rows tall the map is drawn."
  :type 'integer :group 'zetta)

(defcustom zetta-poimap-border-width 0
  "Stroke width, in pixels, of the box poimap draws around the map.  0 for none.

poimap defaults this to 1, and for poimap's own placement that is right: the
map is a WIDGET sitting on an opaque mode line, and the box is what says
where the widget stops and the bar resumes.

Here it is not a widget.  Under the `row' placement the map IS a row of the
bar, running edge to edge, so the box draws a boundary the window edges have
already drawn -- an outline around the full width of the line, which reads as
a frame around nothing.  The rest of this bar has no chrome of its own for
the same reason (see the header of `modeline-svg.el'), and the map should not
be the one thing that does.

Worth setting back to 1 under the `right' placement, where the map really is
a small object floating on a row and the box tells you which pixels are it."
  :type 'integer :group 'zetta
  :set (lambda (sym val)
         (set-default sym val)
         (when (boundp 'poimap-border-width) (setq poimap-border-width val))
         (force-mode-line-update t)))

(defcustom zetta-poimap-pie-gap 6
  "Pixels left between the map and the progress pie under the `right' placement."
  :type 'integer :group 'zetta)

(defcustom zetta-poimap-predicate #'zetta-poimap-default-predicate
  "Predicate deciding whether the current buffer gets a map.
Called with no arguments in the buffer being rendered."
  :type 'function :group 'zetta)

(defcustom zetta-poimap-resolution 600
  "Horizontal buckets used to drop marks that would land on the same pixel.

The git-gutter provider emits one indicator per LINE of every hunk -- a
thousand of them in a big rebase -- and svg-margin wants that, because in
the margin each one is a separate row.  On a map they collapse: at any
sane width most of a hunk's marks are the same handful of pixels drawn
over and over.  Rounding the mapped position to this many buckets and
keeping the first per (bucket, colour) makes a hunk cost what it looks
like instead of what it contains."
  :type 'integer :group 'zetta)

(defcustom zetta-poimap-range-gap 0.004
  "Largest gap, as a fraction of the buffer, that a `range' lane bridges.

Two marks closer together than this are one run.  The default is poimap's
own `poimap-min-range-size' -- the narrowest rectangle it will draw -- on
the grounds that marks nearer than that would overlap if drawn separately,
so joining them changes nothing but the byte count.  Raise it to let a
`range' lane close real gaps (a hunk either side of one unchanged line);
lower it to keep them open."
  :type 'number :group 'zetta)

(defcustom zetta-poimap-max-marks 800
  "Most marks any one provider may contribute to the map.

A safety valve, not a budget: the bucket dedupe in `zetta-poimap--marks'
already bounds a provider at `zetta-poimap-resolution' marks per colour,
and this only stops a pathological one from scanning forever.  Keep it
above the resolution, or a `range' lane will be truncated mid-hunk."
  :type 'integer :group 'zetta)

(defcustom zetta-poimap-min-interval 0.5
  "Seconds the map's marks must age before they may be recomputed.

The rate FLOOR in `zetta-poimap--stale-p'.  poimap already defers its
updates to a 0.1s idle timer and abandons them with `while-no-input' when a
key arrives, so continuous typing is cheap without this -- what this bounds
is the other case: a large buffer where a single pass over nine providers is
slow enough to be felt, updating on every pause.  Half a second of latency
on a mark appearing is not noticeable; the scan is."
  :type 'number :group 'zetta)

(defcustom zetta-poimap-max-staleness 2.0
  "Seconds after which the map's marks are recomputed even if nothing changed.

The gate in `zetta-poimap--stale-p' skips the providers when neither the
buffer text nor the symbol at point has moved, which is most of the time.
But flycheck and git-gutter publish asynchronously -- their results appear
without any edit -- so the gate needs a floor or the map would sit on stale
diagnostics until the next keystroke.  Lower is more responsive and runs
nine buffer scans more often; see the note on cost in the Commentary."
  :type 'number :group 'zetta)

(defcustom zetta-poimap-lanes
  '((org-headings :shape tick    :vert top    :size (2 . 4))
    (org-blocks   :shape tick    :vert top    :size (1 . 3))
    (flycheck     :shape diamond :vert 0.46   :size 7)
    (evil-marks   :shape xcross  :vert 0.46   :size 7)
    (todo         :shape ellipse :vert 0.46   :size 5)
    (symbol       :shape ellipse :vert 0.46   :size 3)
    (long-lines   :shape ellipse :vert 0.74   :size 3)
    (trailing-ws  :shape ellipse :vert 0.74   :size 2)
    (git-gutter   :shape range   :vert bottom :size 4))
  "Which svg-margin providers appear on the map, and how they are drawn.

Each entry is (PROVIDER-NAME . PLIST), where PROVIDER-NAME is a name
registered with `svg-margin-register-provider' -- so the provider function
is named in exactly one place, svg-margin.el, and this is only a drawing
instruction.  A name with no registered provider is skipped.

  :shape  `tick', `ellipse', `diamond' or `xcross' -- poimap's own point
          shapes -- or `range', which is the one that is not a point:
          adjacent marks of the same colour coalesce into a single
          rectangle (see `zetta-poimap--ranges').  That is what a VC hunk
          wants: svg-margin reports one indicator per changed LINE, and on
          a map those are not three hundred marks, they are one bar.
  :vert   vertical position in the strip: a number from 0 (top) to 1, or
          `top' / `bottom', which sit a `tick' or a `range' flush against
          that edge.
  :size   pixels, a number or a cons (WIDTH . HEIGHT).  `range' takes a
          number only -- its width comes from the run it covers.

The default groups the nine providers into three horizontal BANDS rather
than nine lanes, because a mode-line row is about twenty pixels tall and
nine lanes in twenty pixels is two pixels each.  Structure (Org headings
and blocks) runs along the top, attention (diagnostics, marks, TODOs, the
symbol at point) through the middle, and hygiene and VC along the bottom
-- VC as a near-continuous rule, which is what makes a diff legible at
this scale.  Within a band the shape and the theme colour separate them.

Nothing here carries a glyph: poimap's shapes are geometric, so the margin's
Nerd-Font icons do not survive the trip.  At map scale they could not be read
anyway -- the colour and the band are what identify a mark."
  :type '(alist :key-type symbol :value-type plist)
  :group 'zetta)

;;; ------------------------------------------------------------------
;;; Palette
;;; ------------------------------------------------------------------

(defun zetta-poimap--rung (n)
  "The colour N rungs off the page on brushup\='s background ladder.

`brushup-bg-1' and friends exist only at whole rungs, and the extent wants
a half one, so this runs brushup\='s own arithmetic instead -- the same
`brushup-gradient-step' in the same theme-dependent direction, so at N of
1.0 it returns exactly `brushup-bg-1'.  Computed at call time: brushup
recomputes the palette on every theme change."
  (let ((bg (or (bound-and-true-p brushup-bg) (face-background 'default nil t)))
        (step (or (bound-and-true-p brushup-gradient-step) 7))
        (dir (if (bound-and-true-p brushup-dark-p) 1 -1)))
    (if (or (null bg) (zerop n))
        bg
      (color-lighten-name bg (* n step dir)))))

(defun zetta-poimap-apply-palette ()
  "Keep the map on the page, and spend the ladder on the extent alone.

The map is three stacked fields -- the whole buffer, the part of it this
window is showing, and the point.  poimap draws all three every time, which
is why its defaults are wrong here twice over: the buffer field is a rung
off the page, so an untouched strip reads as a grey slab hanging in the bar,
and the extent is a rung further still, so a window that happens to be
showing the whole file paints that slab dark end to end -- a field that is
always the whole field, saying nothing loudly.

So the buffer field is not painted at all (alpha 0.0, not a colour): the bar
underneath it is already `mode-line', which brushup paints to the page, and
letting it through means the map inherits the frame\='s translucency instead
of punching an opaque rectangle through it.  That leaves the ladder for the
extent, which needs one rung and no more -- it is a hint about scroll
position, not a second cursor -- and for the point, which is the one mark
that has to be findable without looking for it, so it stays in ink.  An
unselected window takes half a rung rather than a hue, which is how the rest
of this bar marks focus.

`zetta-poimap-span' zeroes the extent\='s alpha when the window is showing
the whole buffer, so the rung set here is only ever spent on saying which
part of a longer file this is.

The alphas that remain are pinned to 1.0.  poimap\='s defaults blend its
fields toward whatever is behind them, which assumes something opaque is;
here the bar is transparent over a translucent frame, so a half-alpha field
composites against the desktop and drifts with the wallpaper."
  (when (and (boundp 'brushup-bg) (facep 'poimap-background-face))
    (cl-flet ((bg (face color) (set-face-attribute face nil :background color)))
      ;; Both background faces are unpainted (alpha 0.0); the colour is set
      ;; anyway so nothing inherits `default' if the alphas are ever raised.
      (bg 'poimap-background-face          brushup-bg)
      (bg 'poimap-background-inactive-face brushup-bg)
      (bg 'poimap-visible-window-face      (zetta-poimap--rung 1.0))
      (bg 'poimap-visible-window-inactive-face (zetta-poimap--rung 0.5))
      (bg 'poimap-border-face              brushup-bg-2))
    (set-face-attribute 'poimap-point-face nil :foreground brushup-fg-2)
    (setq poimap-background-alpha 0.0
          poimap-background-inactive-alpha 0.0
          poimap-visible-window-alpha 1.0
          poimap-visible-window-inactive-alpha 1.0
          poimap-border-alpha 1.0)))

;;; ------------------------------------------------------------------
;;; Adapter: svg-margin providers -> poimap POIs
;;; ------------------------------------------------------------------

(defun zetta-poimap-default-predicate ()
  "Default `zetta-poimap-predicate': a non-empty file-visiting buffer."
  (and buffer-file-name (> (buffer-size) 0)))

(defun zetta-poimap--shape-fn (shape)
  "Return the poimap shape function named by SHAPE."
  (pcase shape
    ('tick    #'poimap-tick)
    ('diamond #'poimap-diamond)
    ('xcross  #'poimap-xcross)
    (_        #'poimap-ellipse)))

(defun zetta-poimap--pos (ind)
  "Return the buffer position of svg-margin indicator IND, or nil.

An indicator carries `:pos' or a 1-based `:line'.  The line is resolved
WIDENED, because svg-margin's line numbers are absolute -- but the result
is then mapped against the live restriction, so in a narrowed buffer the
map is a map of the narrowing and marks outside it fall away (which is
`poimap-map-position's own behaviour, and the right one: the strip stands
for what the window can reach)."
  (or (plist-get ind :pos)
      (when-let* ((l (plist-get ind :line)))
        (save-restriction
          (widen)
          (save-excursion
            (goto-char (point-min))
            (forward-line (1- l))
            (point))))))

(defun zetta-poimap--raw-color (ind)
  "Emacs colour for svg-margin indicator IND, before SVG conversion."
  (or (plist-get ind :color)
      (when-let* ((f (plist-get ind :face)))
        (face-foreground f nil 'default))
      (if (fboundp 'zetta-svg-margin--color)
          (zetta-svg-margin--color 'muted)
        (face-foreground 'default nil t))))

(defun zetta-poimap--marks (name spec)
  "Return the POI SVG fragment for svg-margin provider NAME drawn per SPEC.
Nil when the provider is not registered, errors, or has nothing to say."
  (when-let* ((props (alist-get name svg-margin--providers))
              (fn (plist-get props :fn))
              (inds (condition-case nil (funcall fn (current-buffer))
                      (error nil))))
    (let* ((shape (plist-get spec :shape))
           (vert (plist-get spec :vert))
           (size (plist-get spec :size))
           (res zetta-poimap-resolution)
           (seen (make-hash-table :test 'equal))
           ;; `poimap-emacs-to-svg-color' goes through `color-values', which
           ;; is not free per indicator when a hunk has hundreds.  A provider
           ;; uses a handful of colours, so memoise on the raw one.
           (colors (make-hash-table :test 'equal))
           (n 0)
           entries)
      (dolist (ind inds)
        (when (< n zetta-poimap-max-marks)
          (when-let* ((pos (zetta-poimap--pos ind))
                      (m (poimap-map-position pos)))
            ;; A range maps to a cons; the point shapes take its start.
            ;; Bucket on the COLOUR too -- collapsing an added hunk and the
            ;; deletion marker beside it into one mark would lose which it was.
            (let* ((x (if (consp m) (car m) m))
                   (raw (zetta-poimap--raw-color ind))
                   (color (or (gethash raw colors)
                              (puthash raw (poimap-emacs-to-svg-color raw) colors)))
                   (bucket (round (* x res)))
                   (key (cons bucket color)))
              (unless (gethash key seen)
                (puthash key t seen)
                (setq n (1+ n))
                (push (list bucket x pos color) entries))))))
      (setq entries (nreverse entries))
      ;; poimap's shape functions return a LIST of string components (they
      ;; are built by `poimap--svg-template'), while a cached POI is a single
      ;; string -- so flatten, then join, the way the bundled providers do.
      (when entries
        (mapconcat
         #'identity
         (apply #'append
                (if (eq shape 'range)
                    (zetta-poimap--ranges entries vert size)
                  (let ((fn (zetta-poimap--shape-fn shape)))
                    (mapcar (lambda (e) (funcall fn (nth 1 e) vert size (nth 3 e)))
                            entries))))
         "")))))

(defun zetta-poimap--ranges (entries vert size)
  "Coalesce ENTRIES into `poimap-range' fragments, one per contiguous run.

Each entry is (BUCKET MAPPED-X BUFFER-POS COLOUR).  A run breaks on a colour
change or a gap of more than one bucket, so a 300-line VC hunk -- which
svg-margin quite rightly reports as 300 separate indicators, one per line --
becomes ONE rectangle instead of three hundred touching ticks.  That is both
what it should look like at map scale and the difference between a couple of
hundred bytes of SVG per render and thirty kilobytes of it."
  (let ((sorted (sort (copy-sequence entries)
                      (lambda (a b)
                        (if (equal (nth 3 a) (nth 3 b))
                            (< (nth 1 a) (nth 1 b))
                          (string< (nth 3 a) (nth 3 b))))))
        (tol (max zetta-poimap-range-gap
                  (if (boundp 'poimap-min-range-size) poimap-min-range-size 0)))
        start end x color out)
    (cl-flet ((flush ()
                (when-let* ((start)
                            (m (poimap-map-position (cons start end))))
                  (push (poimap-range m vert size color) out))))
      (dolist (e sorted)
        ;; Compare MAPPED positions, not buckets.  Bucket adjacency looks
        ;; like the same test and is not: a hunk covering three fifths of a
        ;; five-hundred-line file lands its lines about 1.2 buckets apart,
        ;; so every fifth pair rounds to a gap of 2 and a single hunk came
        ;; out as a hundred and thirty-eight separate rectangles.
        (if (and start (equal color (nth 3 e)) (<= (- (nth 1 e) x) tol))
            (setq end (nth 2 e) x (nth 1 e))
          (flush)
          (setq start (nth 2 e) end (nth 2 e)
                x (nth 1 e) color (nth 3 e))))
      (flush))
    (nreverse out)))

(defvar-local zetta-poimap--gate nil
  "Cons (KEY . TIME) of the last mark recomputation.  See `zetta-poimap--stale-p'.")

(defun zetta-poimap--gate-key ()
  "Cheap key naming the state the map's marks depend on."
  (list (buffer-chars-modified-tick)
        (and (derived-mode-p 'prog-mode)
             (ignore-errors (thing-at-point 'symbol t)))))

(defun zetta-poimap--stale-p (force)
  "Whether the map's marks should be recomputed now.

Every entry in `zetta-poimap-lanes' is a full-buffer scan -- `long-lines'
walks every line, `trailing-ws' and `symbol' scan the whole buffer -- and
svg-margin is already running the same nine on its own schedule.  Doing
them again on poimap's cadence is precisely how a mode line starts eating
redisplay, which is a mistake this config has made before.

Three rules, in order:

  FLOOR    never more often than `zetta-poimap-min-interval', whatever
           is happening, FORCE included.  poimap sends FORCE on every
           window and buffer change, and those arrive in bursts.
  CHANGE   otherwise recompute when the text or the symbol at point moved,
           or when poimap forces it.
  CEILING  and in any case when the last run is older than
           `zetta-poimap-max-staleness', so flycheck and git-gutter --
           which publish without any edit -- are not held out forever.

A buffer seen for the first time has no gate and is always computed, so
switching to one shows a current map immediately."
  (let ((age (and zetta-poimap--gate (- (float-time) (cdr zetta-poimap--gate)))))
    (cond
     ((null age) t)
     ((< age zetta-poimap-min-interval) nil)
     (force t)
     ((not (equal (car zetta-poimap--gate) (zetta-poimap--gate-key))) t)
     ((> age zetta-poimap-max-staleness) t))))

(defun zetta-poimap-update (force)
  "Rebuild the current buffer's POIs from the svg-margin providers.
Registered on `poimap-idle-update-functions'; FORCE is poimap's hint that
the buffer or its window changed.  Returns non-nil when anything moved."
  (when (and (boundp 'svg-margin--providers)
             (funcall zetta-poimap-predicate)
             (zetta-poimap--stale-p force))
    (setq zetta-poimap--gate (cons (zetta-poimap--gate-key) (float-time)))
    (let (updated)
      (dolist (lane zetta-poimap-lanes)
        (let* ((name (car lane))
               (svg (zetta-poimap--marks name (cdr lane))))
          (cond
           (svg
            (unless (equal svg (alist-get name poimap--pois))
              (poimap-update-pois name svg)
              (setq updated t)))
           ;; `poimap-update-pois' is a no-op for nil -- it can add a
           ;; category but never retire one -- so a provider that has just
           ;; gone quiet (the last diagnostic fixed) would leave its marks
           ;; on the map forever.  Drop it here.
           ((assq name poimap--pois)
            (setq poimap--pois (assq-delete-all name poimap--pois))
            (setq updated t)))))
      updated)))

;;; ------------------------------------------------------------------
;;; Drawing: the map as an svg-line `:image' span
;;; ------------------------------------------------------------------

(defun zetta-poimap--row-height (&optional rows)
  "Exact pixel height of a ROWS-high span on the SVG mode line.

svg-line's row height is FZ + LINE-PAD, where FZ is the nominal size after
`svg-line-normalise-font-size' has adjusted it for the family in use -- not
the nominal size itself.  Building the map at exactly this height makes the
`:image' span splice it at scale 1.0, so its hairlines land at the width
they were drawn and its marks are not resampled."
  (let* ((sc (if (fboundp 'svg-line--text-scale) (svg-line--text-scale) 1.0))
         (font (if (fboundp 'zetta-svg-line-font-for)
                   (zetta-svg-line-font-for :mode-line)
                 (face-attribute 'default :family nil t)))
         (nominal (round (* zetta-modeline-svg-font-size sc)))
         (fz (if (fboundp 'svg-line--font-size-for)
                 (svg-line--font-size-for font nominal)
               nominal))
         (lp (round (* zetta-modeline-svg-line-pad sc))))
    (max 8 (* (or rows 1) (+ fz lp)))))

(defun zetta-poimap--image-width ()
  "Pixel width of the mode-line image svg-line is about to draw."
  (if (fboundp 'svg-line--window-width)
      (svg-line--window-width)
    (max 1 (window-pixel-width))))

(defun zetta-poimap--row-index ()
  "0-based index of the map's row: after the two standard rows, and after any
extra rows contributed before this one."
  (let ((n 2))
    (catch 'done
      (dolist (f zetta-modeline-svg-extra-rows n)
        (when (eq f #'zetta-poimap--row)
          (throw 'done n))
        (setq n (+ n (length (ignore-errors (funcall f)))))))))

(defun zetta-poimap--geometry ()
  "Return (WIDTH ROWS ALIGN GAP) for the map under `zetta-poimap-placement'."
  (let* ((sc (if (fboundp 'svg-line--text-scale) (svg-line--text-scale) 1.0))
         (pad (round (* zetta-modeline-svg-left-pad sc)))
         (rm (round (* zetta-modeline-svg-right-margin sc)))
         (total (zetta-poimap--image-width)))
    (pcase zetta-poimap-placement
      ('right
       ;; Sit left of the progress pie.  The pie is a circle of radius R
       ;; whose right edge is its own gap in from the window edge, so the
       ;; map has to clear the gap, the diameter and a little air.
       (let* ((lh (zetta-poimap--row-height 1))
              (r (max 3 (round (* (/ lh 2.0) 0.86))))
              (pie-gap (if (fboundp 'zetta-modeline-svg--pie-gap)
                           (zetta-modeline-svg--pie-gap)
                         rm))
              (gap (+ pie-gap (* 2 r) (round (* zetta-poimap-pie-gap sc))))
              (w (if (floatp zetta-poimap-width)
                     (round (* zetta-poimap-width total))
                   (round (* zetta-poimap-width sc)))))
         (list (max 40 (min w (- total gap pad))) (cons 1 1) 'right gap)))
      (_
       ;; Own row: flush with the content on the rows above, left inset by
       ;; the bar's own PAD and stopping at its RIGHT-MARGIN.  An `:image'
       ;; span aligned `left' is placed at PAD + GAP, so GAP is zero and
       ;; the width carries the right inset.
       (let ((i (zetta-poimap--row-index)))
         (list (max 40 (- total pad rm)) (cons i i) 'left 0))))))

(defvar zetta-poimap--dom-cache (make-hash-table :test 'eq :weakness 'key)
  "Per-window (SVG-STRING . DOM) from the last parse.

poimap hands back SVG MARKUP and svg-line's `:image' span takes either
markup or a parsed DOM -- but given markup it parses it again on every
render of every window, which is an XML parse per redisplay for a picture
that mostly has not changed.  Keyed weakly on the window so dead windows
drop out.  `svg-line--splice-svg' deep-copies what it splices (it says so),
so handing it the same DOM twice is safe.")

(defun zetta-poimap--dom (win svg)
  "Return SVG parsed to a DOM, reusing WIN's last parse when unchanged."
  (let ((hit (gethash win zetta-poimap--dom-cache)))
    (if (and hit (equal (car hit) svg))
        (cdr hit)
      (let ((dom (and (fboundp 'svg-line--parse-svg) (svg-line--parse-svg svg))))
        (if dom
            (progn (puthash win (cons svg dom) zetta-poimap--dom-cache) dom)
          ;; No parser (older svg-line): hand the span the markup and let
          ;; it do the work itself.
          svg)))))

(defun zetta-poimap--active-p ()
  "Whether the map should be drawn in the buffer being rendered.
Both the row and the span ask this, so they cannot disagree and leave an
empty strip of bar."
  (and (bound-and-true-p poimap-mode)
       (funcall zetta-poimap-predicate)))

(defun zetta-poimap--row ()
  "The map's own empty row, for `zetta-modeline-svg-extra-rows'."
  (when (and (eq zetta-poimap-placement 'row) (zetta-poimap--active-p))
    (list (cons nil nil))))

(defun zetta-poimap--whole-buffer-p (win)
  "Whether WIN is showing all of the accessible buffer.

When it is, poimap\='s extent rectangle spans the strip end to end, which is
not a reading of anything -- it is the map coloured in.  The caller draws
the extent at alpha 0.0 in that case, so the rung only ever appears while
there is somewhere else in the file to be."
  (and (<= (window-start win) (point-min))
       (>= (window-end win) (point-max))))

(defun zetta-poimap-span ()
  "The map as an svg-line `:image' span, for `zetta-modeline-svg-extra-spans'."
  (when (zetta-poimap--active-p)
    (when-let* ((win (poimap--live-window)))
      ;; `poimap--svg' clamps `window-start'/`window-end', both of which can
      ;; be nil in a window redisplay has not measured yet.
      (when (and (window-live-p win) (window-start win) (window-end win))
        (pcase-let* ((`(,w ,rows ,align ,gap) (zetta-poimap--geometry))
                     (h (zetta-poimap--row-height zetta-poimap-rows))
                     (whole (zetta-poimap--whole-buffer-p win))
                     ;; Suppressed by alpha rather than by editing the SVG:
                     ;; `poimap--svg' always emits the extent rectangle, and
                     ;; a transparent fill is the one way to say "not this
                     ;; time" without reaching into its markup.  A plain
                     ;; `let' because these are special and `pcase-let*'
                     ;; makes no promise of binding them dynamically.
                     (svg (let ((poimap-visible-window-alpha
                                 (if whole 0.0 poimap-visible-window-alpha))
                                (poimap-visible-window-inactive-alpha
                                 (if whole 0.0
                                   poimap-visible-window-inactive-alpha)))
                            (poimap--svg win w h
                                         (mode-line-window-selected-p)))))
          ;; `poimap-mouse' reads this parameter to turn an x coordinate
          ;; back into a buffer position.  Nothing clicks the map yet (see
          ;; the Commentary), but keeping it correct costs one setter and is
          ;; what a hot-spot would need.
          (set-window-parameter win 'poimap-width w)
          (list (list :image rows (zetta-poimap--dom win svg) align gap)))))))

;;; ------------------------------------------------------------------
;;; Commands
;;; ------------------------------------------------------------------

(defun zetta-poimap-toggle-placement ()
  "Flip the map between its own row and the right of row 2."
  (interactive)
  (setq zetta-poimap-placement
        (if (eq zetta-poimap-placement 'row) 'right 'row))
  (force-mode-line-update t)
  (message "poimap: %s placement" zetta-poimap-placement))

(defun zetta-poimap-toggle ()
  "Turn the buffer map on or off."
  (interactive)
  (poimap-mode (if (bound-and-true-p poimap-mode) -1 1))
  (force-mode-line-update t)
  (message "poimap: %s" (if (bound-and-true-p poimap-mode) "on" "off")))

(defun zetta-poimap-refresh ()
  "Recompute the map's marks in every visible buffer, ignoring the gate."
  (interactive)
  (dolist (buf (buffer-list))
    (with-current-buffer buf (kill-local-variable 'zetta-poimap--gate)))
  (when (fboundp 'poimap-update-all) (poimap-update-all)))

;;; ------------------------------------------------------------------
;;; Guard: no idle timers for buffers nobody can see
;;; ------------------------------------------------------------------
;;
;; `poimap-mode' puts `poimap--request-idle-update-for-buffer-text-change'
;; on the GLOBAL `after-change-functions', and a request allocates one
;; buffer-local idle timer per buffer that changes.  That includes every
;; `with-temp-buffer' anywhere in Emacs -- `url-generic-parse-url' makes one
;; per call -- and a temp buffer is killed before its 0.1s timer can fire,
;; so the timer is never cancelled and sits in `timer-idle-list' until the
;; next idle moment.  Each new timer costs a walk of that list
;; (`timer--activate'), so N temp buffers in one non-idle stretch cost
;; O(N^2).  On 2026-09-12 a single elfeed-protocol fever batch parsed three
;; URLs for each of tens of thousands of entries and wedged the daemon for
;; hours; `kill -USR2' only nested debuggers that hit the same walk.
;;
;; A text change in a buffer no window shows cannot need the map: the map is
;; drawn per window, and `window-buffer-change-functions' forces a fresh
;; update the moment such a buffer is displayed.  So the hook is made a
;; no-op there.  The kill-buffer hook covers the remaining case -- a
;; displayed buffer killed inside the 0.1s window -- so nothing is left
;; behind in the timer list.

(defun zetta-poimap--displayed-p (&rest _)
  "Whether the current buffer is shown in some window, on any frame."
  (get-buffer-window (current-buffer) t))

(defun zetta-poimap--cancel-idle-timer ()
  "Drop the buffer's pending poimap idle timer, for `kill-buffer-hook'."
  (when (timerp (bound-and-true-p poimap--idle-update-timer))
    (cancel-timer poimap--idle-update-timer)
    (setq poimap--idle-update-timer nil)))

(with-eval-after-load 'poimap
  (advice-add 'poimap--request-idle-update-for-buffer-text-change
              :before-while #'zetta-poimap--displayed-p)
  (add-hook 'kill-buffer-hook #'zetta-poimap--cancel-idle-timer))

;;; ------------------------------------------------------------------
;;; Activation
;;; ------------------------------------------------------------------

(defun zetta-poimap-activate ()
  "Wire the map into the SVG mode line and start poimap's update machinery."
  (when (and (featurep 'poimap) (image-type-available-p 'svg))
    ;; poimap's own mode-line insertion is not wanted: the map is a span on
    ;; the svg-line bar, not a construct appended to `global-mode-string'.
    ;; This is the option poimap documents for exactly this case.
    (setq poimap-add-to-mode-line nil)
    (when (bound-and-true-p poimap-mode-line-string)
      (setq global-mode-string
            (delete poimap-mode-line-string global-mode-string)))
    (setq poimap-border-width zetta-poimap-border-width)
    ;; Once here as well as on every theme change: `brushup-styles' may
    ;; already have run before this package existed.
    (zetta-poimap-apply-palette)
    ;; The marks come from the svg-margin providers, not poimap's own.
    (add-hook 'poimap-idle-update-functions #'zetta-poimap-update)
    (when (boundp 'zetta-modeline-svg-extra-rows)
      (add-to-list 'zetta-modeline-svg-extra-rows #'zetta-poimap--row))
    (when (boundp 'zetta-modeline-svg-extra-spans)
      (add-to-list 'zetta-modeline-svg-extra-spans #'zetta-poimap-span))
    (poimap-mode 1)))

(if after-init-time
    (zetta-poimap-activate)               ; loaded interactively, init already done
  (add-hook 'emacs-startup-hook #'zetta-poimap-activate 90))

(provide 'zetta-poimap)
;;; poimap.el ends here
