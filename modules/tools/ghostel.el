;;; ghostel.el --- Configure ghostel (Ghostty terminal integration) -*- lexical-binding: t; -*-

;; Ghostel is NOT a drop-in for vterm's key API.  vterm generates a
;; `vterm-send-C-<key>' command family with the `vterm-define-key' macro;
;; ghostel has no equivalent, so `ghostel-send-C-s', `ghostel-send-escape',
;; `ghostel-send-up' and friends do not exist.
;;
;; Instead, every modified or special key goes through
;; `ghostel--send-event', which decomposes `last-command-event' into a key
;; name plus modifier list and hands them to the ghostty key encoder.
;; `ghostel--self-insert' is strictly the [remap self-insert-command] path:
;; it calls `string' on the raw event, so any modified key fails
;; `characterp' (C-, is event 67108908 -> "Wrong type argument: characterp").
;;
;; Keys whose pressed binding differs from the key to transmit (C-k -> up)
;; need a wrapper around `ghostel--send-encoded', the same primitive the
;; package's own evil layer uses.

(require 'color)
(require 'cl-lib)
(require 'seq)

(declare-function ghostel--send-encoded "ghostel" (key-name mods &optional utf8))
(declare-function ghostel--set-cursor-style "ghostel" (style visible))
(declare-function ghostel--cursor-position "ghostel-module" (term))
(defvar ghostel--term)
(declare-function evil-refresh-cursor "evil-core" (&optional state))
(defvar ghostel--copy-mode-active)
(defvar brushup-styles)
(defvar brushup-dark-p)
(defvar brushup-bg)

;; Defined ahead of the `use-package' form deliberately: general's
;; use-package handler emits an `(autoload ... "ghostel")' stub for every
;; command it binds, guarded by `fboundp'.  Defining these first keeps
;; general from pointing them at a file that does not define them.
(defun zetta-ghostel-send-event-with-text ()
  "Send the current key event, telling the encoder what text the key makes.
Ghostty's key encoder cannot encode a key with no legacy control-code
mapping -- C-, C-. C-; C-- C-= -- unless it is given the unmodified key's
text.  `ghostel--send-event' never passes it, so those keys silently send
nothing at all.  With the hint, C-, encodes as CSI-u (ESC [ 44 ; 5 u).

Use this only for such keys.  Plain `ghostel--send-event' is correct for
everything else, including meta keys: those fail in the encoder too, but
`ghostel--raw-key-sequence' catches them and builds the ESC prefix, and a
text hint would defeat that and send a bare unprefixed character."
  (interactive)
  (let ((base (event-basic-type last-command-event))
        (mods (event-modifiers last-command-event)))
    (when (characterp base)
      (ghostel--send-encoded
       (string base)
       (mapconcat (lambda (m)
                    (pcase m
                      ('shift "shift") ('control "ctrl") ('meta "meta")
                      ('hyper "hyper") ('super "super") (_ nil)))
                  mods ",")
       (string base)))))

;;; ANSI palette
;;
;; Ghostel is not Ghostty.  It embeds libghostty-vt -- the terminal
;; EMULATION core, the part that parses escape sequences and keeps the
;; grid -- and nothing else: no window, no renderer, no font stack, no
;; config file.  `~/.files/ghostty/config' is read by the Ghostty
;; application alone; ghostel never opens it, so nothing translates that
;; theme into this buffer.  Emacs draws every glyph, which means Emacs
;; also owns the colour table the grid resolves against.
;;
;; That table holds 256 entries plus a default fg/bg, and programs reach
;; it three ways: slots 0-15 (`ESC[31m'), which are NAMES rather than
;; colours -- "red" means whatever this terminal calls red -- slots
;; 16-255, a fixed RGB cube and grey ramp, and truecolor
;; (`ESC[38;2;R;G;Bm'), which names an exact colour and bypasses the table
;; entirely.  Only the first is remappable in practice, and
;; `ghostel--apply-palette' is the seam: it reads the 16 `ghostel-color-*'
;; faces and pushes their foregrounds into the terminal.
;;
;; Those faces inherit `term-color-*', which is a poor source.  Under
;; doric-earth every bright slot is byte-identical to its normal
;; counterpart and all six hues sit within a few percent of the same
;; darkness -- a near-monochrome theme was never trying to supply sixteen
;; distinguishable terminal colours.
;;
;; So take the hues from a Ghostty THEME FILE instead, which parse as
;; `palette = N=#rrggbb', and refit each one to the Emacs canvas.  The
;; light and dark halves of a pair are chosen by `brushup-dark-p', so the
;; terminal follows the theme both ways round and still reads as the same
;; palette it is in the standalone app.

(defconst zetta-ghostel--ansi-names
  '("black" "red" "green" "yellow" "blue" "magenta" "cyan" "white"
    "bright-black" "bright-red" "bright-green" "bright-yellow"
    "bright-blue" "bright-magenta" "bright-cyan" "bright-white")
  "The 16 ANSI slots ghostel exposes as `ghostel-color-NAME' faces.
Ordered by palette slot: element N names slot N.")

(defcustom zetta-ghostel-ghostty-theme-path
  (list (expand-file-name "ghostty/themes" "~/.files")
        "/Applications/Ghostty.app/Contents/Resources/ghostty/themes")
  "Directories searched for Ghostty theme files, in order.
A vendored copy under `~/.files' is consulted first, so the palette
survives Ghostty being absent, moved, or upgraded out from under it."
  :type '(repeat directory)
  :group 'ghostel)

(defcustom zetta-ghostel-ghostty-themes
  '("Zenbones Light" . "Zenbones Dark")
  "Ghostty theme files supplying the terminal hues, as (LIGHT . DARK).
Looked up along `zetta-ghostel-ghostty-theme-path'.  Pick a pair whose
two halves are the same palette in both polarities, or the terminal will
change character rather than just canvas when the Emacs theme flips."
  :type '(cons string string)
  :group 'ghostel)

(defcustom zetta-ghostel-hue-sources
  '((1 . error) (2 . success) (3 . warning)
    (4 . link) (5 . font-lock-keyword-face) (6 . font-lock-string-face))
  "The face whose hue each chromatic ANSI slot leans toward.
Slots 9-14 follow the entry for their unbright counterpart, so red and
bright-red stay the same colour at two intensities.

These are the faces a theme has to have an opinion about, which is what
makes them a fair sample of its accents even in a near-monochrome theme."
  :type '(alist :key-type integer :value-type face)
  :group 'ghostel)

(defcustom zetta-ghostel-hue-rotation 55.0
  "How far a slot may rotate toward its theme hue, in degrees.

0 pins the palette to the Ghostty file and the terminal then changes only
on a light/dark flip.  180 adopts the theme's hue outright, at the cost of
letting two slots collapse onto one angle.  The default leaves every slot
recognisably itself while moving far enough to read as a different
palette."
  :type 'float
  :group 'ghostel)

(defcustom zetta-ghostel-hue-family-width 40.0
  "How near two accent hues must be, in degrees, to count as one family.
Modus spreads its blues over 299-306 degrees; without a width like this
they would read as several hues rather than the one blue they are."
  :type 'float
  :group 'ghostel)

(defcustom zetta-ghostel-strict-gamut-families 2
  "At how few hue families a theme's restraint is taken as deliberate.
At or below this, slots follow their theme accent all the way round
instead of stopping at `zetta-ghostel-hue-rotation'.  Raise it to make
more themes authoritative over the palette, or set it to 0 to always keep
Ghostty's hue separation."
  :type 'integer
  :group 'ghostel)

(defcustom zetta-ghostel-chroma-floor 13.0
  "Least chroma a slot keeps however grey the theme is.
Set to 0 to let a monochrome theme produce a monochrome terminal, at the
cost of not being able to tell error output from success output."
  :type 'float
  :group 'ghostel)

(defcustom zetta-ghostel-page-tint 22.0
  "How far the whole palette leans toward the page's own hue, in degrees.

Per-slot accents are not enough on their own in a monochrome theme
family.  doric-plum and doric-obsidian share `error', `success' and
`warning' byte-for-byte and obsidian's keyword and string faces are flat
grey, so following those faces alone leaves half the palette identical
between the two -- which is exactly the \"nothing changes when I switch
themes\" complaint.

The page always differs, though, and leaning the palette toward it is
what blending with a theme actually means: doric-plum's violet ground
pulls the terminal violet-ward, doric-earth's warm cream pulls it warm.  A
neutral ground has no hue to lean toward and so contributes nothing, which
is correct rather than a gap.  Set to 0 to switch this off."
  :type 'float
  :group 'ghostel)

(defcustom zetta-ghostel-grey-source 'page
  "Which of the theme's own colours lends the four greys their hue.

Only hue and chroma are taken from it.  The exact contrast fit replaces
lightness wholesale, so this decides what the greys are TINTED with, never
how dark they are -- the ladder in `zetta-ghostel-contrast-targets' is
unaffected either way.

`page' takes the ground (`brushup-bg'), `ink' the foreground
(`brushup-fg'), and a face symbol takes that face's background.

The greys are chrome -- 0 is a field, 8 a border or a comment, 15 a fill --
and chrome belongs to the ground's hue family, which is why the page is the
default.  It only matters where a theme's ink and ground disagree, and then
it matters a lot: doric-earth grounds at hue 102 and inks at 342, so
ink-sourced greys came out mauve while every Emacs surface around them --
tab bar, mode line, their own inactive tabs at hue 99 -- stayed khaki.  A
tmux status bar drawn on those greys sat in that gap and read as pasted on.
Where ink and ground share a family, as doric-plum's violet pair do, the
two settings agree and this changes nothing.

Set to `ink' to restore the old behaviour."
  :type '(choice (const :tag "The theme's ground" page)
                 (const :tag "The theme's ink" ink)
                 (face :tag "That face's background"))
  :group 'ghostel)

(defcustom zetta-ghostel-contrast-targets
  '((0 . 1.5) (8 . 3.0) (15 . 5.5) (7 . 9.0) (t . 4.0))
  "WCAG contrast each palette slot should reach against the page.
Keys are slot numbers; t supplies the default for anything unlisted.

The four achromatic slots are fitted EXACTLY, and that is what holds them
apart.  Programs use them as a prominence ladder -- 0 as a background, 8
as comment text, 7 as body, 15 as emphasis -- so they need four separate
values.  Fit them to a floor instead and they collapse onto one another,
because every one of them lands on whichever grey sits at that ratio.

Chromatic slots take their number as a MINIMUM: a hue that already reads
against the page is left alone rather than dragged onto a target.

These four numbers are a CONTRACT, not a local preference: the tmux status
bar, gitmux and the fzf popups are written in slot names precisely so they
follow this fit, and they live in the .files repo rather than here.
Changing a rung restyles all of them.  See docs/ansi-palette.md."
  :type '(alist :key-type (choice integer (const t)) :value-type float)
  :group 'ghostel)

(defun zetta-ghostel--rgb (color)
  "COLOR as a list of three 0..1 floats.
Parses \"#rrggbb\" arithmetically instead of going through
`color-name-to-rgb', which needs a display: under `emacs -Q -batch' that
call quantises every colour onto a tty palette, so the fit below could not
otherwise be tested outside a live frame.  Names still take the slow path,
which the `term-color-*' fallback needs -- it yields things like
\"gray70\"."
  (if (and (stringp color)
           (string-match (concat "\\`#\\([0-9a-fA-F]\\{2\\}\\)"
                                 "\\([0-9a-fA-F]\\{2\\}\\)"
                                 "\\([0-9a-fA-F]\\{2\\}\\)\\'")
                         color))
      (mapcar (lambda (i) (/ (string-to-number (match-string i color) 16) 255.0))
              '(1 2 3))
    (color-name-to-rgb color)))

(defun zetta-ghostel--relative-luminance (rgb)
  "WCAG relative luminance for RGB, a list of three 0..1 floats."
  (apply #'+ (cl-mapcar #'*
                        '(0.2126 0.7152 0.0722)
                        (mapcar (lambda (c)
                                  (if (<= c 0.03928)
                                      (/ c 12.92)
                                    (expt (/ (+ c 0.055) 1.055) 2.4)))
                                rgb))))

(defun zetta-ghostel--contrast (a b)
  "WCAG contrast ratio between colour names A and B, or nil if unknown."
  (let ((ra (zetta-ghostel--rgb a)) (rb (zetta-ghostel--rgb b)))
    (when (and ra rb)
      (let ((la (+ 0.05 (zetta-ghostel--relative-luminance ra)))
            (lb (+ 0.05 (zetta-ghostel--relative-luminance rb))))
        (/ (max la lb) (min la lb))))))

(defun zetta-ghostel--find-theme-file (name)
  "Return the readable Ghostty theme file called NAME, or nil."
  (seq-some (lambda (dir)
              (let ((f (expand-file-name name dir)))
                (and (file-readable-p f) f)))
            zetta-ghostel-ghostty-theme-path))

(defun zetta-ghostel--parse-ghostty-theme (file)
  "Return slots 0-15 of Ghostty theme FILE as a 16-vector of \"#rrggbb\".
Nil unless all sixteen are present -- a partial palette would leave some
slots on the stale value of whatever ran last, which is worse than
falling back wholesale."
  (let ((slots (make-vector 16 nil)))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (while (re-search-forward
              "^[ \t]*palette[ \t]*=[ \t]*\\([0-9]+\\)[ \t]*=[ \t]*\\(#[0-9a-fA-F]\\{6\\}\\)"
              nil t)
        (let ((slot (string-to-number (match-string 1))))
          (when (< slot 16)
            (aset slots slot (downcase (match-string 2)))))))
    (and (not (seq-contains-p slots nil)) slots)))

(defun zetta-ghostel--source-palette ()
  "The 16 unfitted hues for the current polarity, or nil to fall back."
  (let* ((name (if (bound-and-true-p brushup-dark-p)
                   (cdr zetta-ghostel-ghostty-themes)
                 (car zetta-ghostel-ghostty-themes)))
         (file (and (stringp name) (zetta-ghostel--find-theme-file name))))
    (and file (zetta-ghostel--parse-ghostty-theme file))))

(defun zetta-ghostel--lch (color)
  "COLOR as a list (L* C h), or nil if it names nothing."
  (let ((rgb (zetta-ghostel--rgb color)))
    (and rgb (apply #'color-lab-to-lch (apply #'color-srgb-to-lab rgb)))))

(defun zetta-ghostel--render (l c h)
  "Render lightness L, chroma C and hue H as \"#rrggbb\", clamped into sRGB.
Chroma that will not fit the gamut at L is clipped, which costs a little
saturation at the extremes and never shifts the hue."
  (apply #'color-rgb-to-hex
         (append (mapcar (lambda (v) (max 0.0 (min 1.0 v)))
                         (apply #'color-lab-to-srgb (color-lch-to-lab l c h)))
                 '(2))))

(defun zetta-ghostel--relight (lch l)
  "Render LCH at lightness L, holding its chroma and hue."
  (zetta-ghostel--render l (nth 1 lch) (nth 2 lch)))

(defun zetta-ghostel--theme-accents ()
  "The (CHROMA . HUE) of every accent face the theme gives a real hue to.

Faces too close to grey are dropped.  That they are grey is itself
information -- the theme is declining to use a hue there -- but it is not
a hue, and averaging one in would invent a direction out of rounding
error."
  (delq nil
        (mapcar (lambda (cell)
                  (let ((face (cdr cell)))
                    (when (facep face)
                      (let* ((fg (face-attribute face :foreground nil 'default))
                             (lch (and (stringp fg) (zetta-ghostel--lch fg))))
                        (when (and lch (> (nth 1 lch) 5.0))
                          (cons (nth 1 lch) (nth 2 lch)))))))
                zetta-ghostel-hue-sources)))

(defun zetta-ghostel--hue-families (accents)
  "How many separate hue families ACCENTS occupy.
Angles within `zetta-ghostel-hue-family-width' of one another count as
one family, so the blues modus spreads across 299-306 degrees are read as
the single blue they are meant to be."
  (let ((width (degrees-to-radians zetta-ghostel-hue-family-width))
        (seen nil))
    (dolist (a accents (length seen))
      (let ((h (cdr a)))
        (unless (seq-some
                 (lambda (k)
                   (< (abs (- (mod (+ (- h k) float-pi) (* 2 float-pi)) float-pi))
                      width))
                 seen)
          (push h seen))))))

(defun zetta-ghostel--theme-profile ()
  "What the current theme is willing to do with colour.

Returns a plist: `:ceiling' the most chroma any accent face uses,
`:families' how many hue families they occupy, and `:strict' non-nil when
that count is small enough that the restraint is clearly deliberate.

Computed once per pass rather than per slot -- it is sixteen identical
answers otherwise."
  (let* ((accents (zetta-ghostel--theme-accents))
         (ceiling (if accents (apply #'max (mapcar #'car accents)) 0.0))
         (families (zetta-ghostel--hue-families accents)))
    (list :ceiling ceiling
          :families families
          :strict (and accents (<= families zetta-ghostel-strict-gamut-families)))))

(defun zetta-ghostel--theme-hue (slot)
  "The hue SLOT should lean toward in the current theme, or nil.

Nil when the theme names no such face or when the one it names is too
close to grey to carry a hue at all -- asking a monochrome face which way
round the wheel it points gives an answer, but a meaningless one."
  (let* ((base (if (> slot 8) (- slot 8) slot))
         (face (cdr (assq base zetta-ghostel-hue-sources))))
    (when (and face (facep face))
      (let* ((fg (face-attribute face :foreground nil 'default))
             (lch (and (stringp fg) (zetta-ghostel--lch fg))))
        (when (and lch (> (nth 1 lch) 5.0))
          (nth 2 lch))))))

(defun zetta-ghostel--follow-hue (color slot profile)
  "Rotate COLOR toward the hue the theme uses for SLOT, within PROFILE.

This is what makes the terminal answer to the theme rather than only to
its polarity.  Sourcing hues from a Ghostty file alone pins the palette to
one palette per polarity, so every dark theme yields byte-identical
terminal colours.

Normally a capped rotation rather than a substitution, because the slots
have jobs: adopting the theme's hue outright would let `link' and
`font-lock-keyword-face' drag blue and magenta onto one angle, and would
stop a diff's red reading as red.

The cap comes off for a theme whose accents occupy only a family or two,
because there the restraint is the whole point and overriding it is worse
than losing a distinction.  modus-operandi-deuteranopia is the case that
forced this: it confines itself to orange-yellow and blue, and sets
`success' to BLUE rather than green precisely so that red and green never
have to be told apart.  Under the cap our green stopped at teal -- a hue
the theme does not use, in the one theme built to avoid it."
  (let ((target (zetta-ghostel--theme-hue slot))
        (lch (zetta-ghostel--lch color)))
    (if (or (null target) (null lch) (<= zetta-ghostel-hue-rotation 0))
        color
      (let* ((cap (degrees-to-radians
                   (if (plist-get profile :strict)
                       180.0
                     (min 180.0 zetta-ghostel-hue-rotation))))
             (h (nth 2 lch))
             ;; Shortest way round the wheel, so a rotation never takes the
             ;; long path through the opposite hue.
             (delta (- (mod (+ (- target h) float-pi) (* 2 float-pi)) float-pi))
             (delta (max (- cap) (min cap delta))))
        (zetta-ghostel--render (nth 0 lch) (nth 1 lch) (+ h delta))))))

(defun zetta-ghostel--fit-chroma (color slot profile)
  "Hold COLOR to the saturation the theme is prepared to use.

Ghostty supplies the chroma, and left alone it is simply Zenbones' --
doric-obsidian caps its own accents at chroma 33 while we were emitting 47
and inventing a magenta and a cyan it never uses anywhere.  A palette more
saturated than the theme it is meant to sit inside is the visible half of
the complaint that the terminal ignores the theme.

Two rules.  A slot whose own accent face the theme paints grey is taken
down to the floor, since that face is where the theme says how much colour
belongs there.  Everything else is capped at the most any accent uses.

The floor exists because a terminal is not decoration: collapsing every
slot onto grey would leave error and success indistinguishable in output
the theme knows nothing about."
  (let ((lch (zetta-ghostel--lch color))
        (ceiling (plist-get profile :ceiling)))
    (if (or (null lch) (null ceiling) (<= ceiling 0.0))
        color
      (let* ((grey-slot (null (zetta-ghostel--theme-hue slot)))
             (want (if grey-slot
                       zetta-ghostel-chroma-floor
                     (max zetta-ghostel-chroma-floor
                          (min (nth 1 lch) ceiling)))))
        (if (>= want (nth 1 lch))
            color
          (zetta-ghostel--render (nth 0 lch) want (nth 2 lch)))))))

(defun zetta-ghostel--tint-to-page (color bg)
  "Lean COLOR toward BG's hue by `zetta-ghostel-page-tint' degrees.
A near-neutral page has no hue worth leaning toward, so it is left alone
rather than rotated onto whatever angle its rounding error implies."
  (let ((lch (zetta-ghostel--lch color))
        (bg-lch (zetta-ghostel--lch bg)))
    (if (or (null lch) (null bg-lch)
            (<= zetta-ghostel-page-tint 0)
            (< (nth 1 bg-lch) 2.0))
        color
      (let* ((cap (degrees-to-radians (min 180.0 zetta-ghostel-page-tint)))
             (h (nth 2 lch))
             (delta (- (mod (+ (- (nth 2 bg-lch) h) float-pi) (* 2 float-pi))
                       float-pi))
             (delta (max (- cap) (min cap delta))))
        (zetta-ghostel--render (nth 0 lch) (nth 1 lch) (+ h delta))))))

(defun zetta-ghostel--fit (color bg target exact)
  "Move COLOR in lightness alone until it reads at TARGET contrast on BG.

Hue and chroma are held, because terminal colours are content rather than
chrome -- a diff needs its red to still be red.  That is why this works in
LCH: repeated `color-lighten-name' cannot make the same promise, since it
runs in HSL and bleeds saturation on the way.

On the far side of BG's own lightness contrast is monotonic in L*, so the
fit is a bisection over that half of the range.  With EXACT nil TARGET is
a floor and a colour already above it comes back untouched; with EXACT
non-nil the colour is placed AT the target, which is what stops the four
greys piling onto one value."
  (let ((lch (zetta-ghostel--lch color))
        (bg-l (car (or (zetta-ghostel--lch bg) '(nil)))))
    (if (not (and lch bg-l))
        color
      (let ((now (zetta-ghostel--contrast color bg)))
        (if (and (not exact) now (>= now target))
            color
          (let* ((bg-light (> bg-l 50.0))
                 ;; The half that moves away from the page: darker on a
                 ;; light page, lighter on a dark one.
                 (lo (if bg-light 0.0 bg-l))
                 (hi (if bg-light bg-l 100.0))
                 ;; The far end always clears the target, so it is the
                 ;; answer if the bisection never finds anything better.
                 (best (zetta-ghostel--relight lch (if bg-light lo hi))))
            (dotimes (_ 20)
              (let* ((mid (/ (+ lo hi) 2.0))
                     (hex (zetta-ghostel--relight lch mid))
                     (ok (>= (or (zetta-ghostel--contrast hex bg) 0.0) target)))
                (when ok (setq best hex))
                ;; Clearing the target means we can afford to move back
                ;; toward the page; the direction of "back" flips with it.
                (if bg-light
                    (if ok (setq lo mid) (setq hi mid))
                  (if ok (setq hi mid) (setq lo mid)))))
            best))))))

(defun zetta-ghostel--grey-base (slot src)
  "The colour lending achromatic SLOT its hue and chroma.
Chosen by `zetta-ghostel-grey-source'.  Falls back to SLOT's own entry in
the Ghostty palette SRC when the theme supplies nothing usable, which is
also what happens for a face that exists but is left unstyled."
  (or (pcase zetta-ghostel-grey-source
        ('page (and (boundp 'brushup-bg) (stringp brushup-bg) brushup-bg))
        ('ink (and (boundp 'brushup-fg) (stringp brushup-fg) brushup-fg))
        ((and (pred facep) face)
         ;; A face that exists but is left unstyled answers with the
         ;; symbol-as-string `unspecified-bg', which is a string and would
         ;; sail through to `zetta-ghostel--fit', fail to parse there, and
         ;; leave the slot on the previous theme's value.  Demand something
         ;; that actually reads as a colour so the Ghostty file takes over
         ;; instead.
         (let ((c (face-attribute face :background nil t)))
           (and (stringp c) (zetta-ghostel--rgb c) c))))
      (aref src slot)))

(defun zetta-ghostel-apply-ansi-palette ()
  "Fit the 16 ANSI slots to the current theme's page colour.

Hues come from a Ghostty theme file (`zetta-ghostel-ghostty-themes'),
picked light or dark to match, and each is refitted by
`zetta-ghostel--fit'.

Sourcing from a file rather than from the faces is deliberate.
`set-face-attribute' is destructive -- it replaces the inherited value --
so a pass that read `ghostel-color-red' back would be reading its own
previous answer instead of the theme's, and the nudges would compound
across every theme switch.  They did: black, white, bright-black and
bright-white had all drifted onto the same mid-grey, one lightened on a
dark theme and never brought back.

Falls back to whatever the theme leaves in `term-color-*' when no theme
file can be found, resetting each face to `unspecified' first so that
path cannot drift either.

Registered on `brushup-styles', so it re-runs per theme change, and
pushes the result itself -- see `zetta-ghostel--push-palette'."
  (let ((bg (or (and (boundp 'brushup-bg) brushup-bg)
                (face-background 'default nil t)))
        (src (zetta-ghostel--source-palette))
        (profile (zetta-ghostel--theme-profile)))
    (when (and bg (zetta-ghostel--rgb bg))
      (dotimes (slot 16)
        (let ((face (intern (format "ghostel-color-%s"
                                    (nth slot zetta-ghostel--ansi-names)))))
          (when (facep face)
            (let ((base (cond
                         ;; The four greys take their tint from the theme
                         ;; rather than from the Ghostty file, so they carry
                         ;; its warmth instead of Zenbones' slate.  Their
                         ;; lightness is replaced wholesale by the exact fit
                         ;; below, so only hue and chroma survive from here.
                         ;; Which colour lends them is
                         ;; `zetta-ghostel-grey-source'.
                         ((and src (memq slot '(0 7 8 15)))
                          (zetta-ghostel--grey-base slot src))
                         (src (zetta-ghostel--tint-to-page
                               (zetta-ghostel--fit-chroma
                                (zetta-ghostel--follow-hue (aref src slot) slot profile)
                                slot profile)
                               bg))
                         (t
                          (set-face-attribute face nil :foreground 'unspecified)
                          (face-attribute face :foreground nil 'default)))))
              (when (and (stringp base) (zetta-ghostel--rgb base))
                (let ((target (or (cdr (or (assq slot zetta-ghostel-contrast-targets)
                                           (assq t zetta-ghostel-contrast-targets)))
                                  4.0))
                      (exact (memq slot '(0 7 8 15))))
                  (set-face-attribute face nil :foreground
                                      (zetta-ghostel--fit base bg target exact))))))))
      (zetta-ghostel--push-palette))))

(defvar zetta-ghostel--pushed-palette nil
  "The 16 foregrounds last handed to the running terminals.")

(defun zetta-ghostel--push-palette ()
  "Send the freshly fitted faces to every live terminal.

Ghostel already re-sends the palette on `enable-theme-functions', but it
gets there FIRST -- the hook holds

    (ghostel--on-theme-change ... brushup--on-theme-change)

and hooks run in order.  So on every theme change ghostel pushes the
faces as they stand BEFORE brushup has recomputed them, and the terminal
ends up displaying the previous theme's palette: change theme and nothing
moves, change it again and you get the colours you asked for last time.
That is the whole of the \"terminal ignores the theme\" symptom, and it
predates the palette work here -- it just could not be seen while every
theme was handing ghostel much the same muddy `term-color-*'.

Pushing again from here fixes the order, because this runs late in
`brushup-styles'.  Compares first so that the other styles in that list
do not each trigger a repaint.

Nothing to push until ghostel has defined its faces: the package is
autoloaded, so before the first `M-x ghostel' the sixteen
`ghostel-color-*' faces do not exist, and reading them logged \"Invalid
face: ghostel-color-black\" on every theme pass (seen on the hub, where
nothing loads ghostel early).  The faces are defined together, so one
`facep' answers for all sixteen."
  (when (facep 'ghostel-color-black)
    (let ((now (mapcar (lambda (name)
                         (face-attribute (intern (format "ghostel-color-%s" name))
                                         :foreground nil 'default))
                       zetta-ghostel--ansi-names)))
      (unless (equal now zetta-ghostel--pushed-palette)
        (let ((was zetta-ghostel--pushed-palette))
          (setq zetta-ghostel--pushed-palette now)
          (when (fboundp 'ghostel-sync-theme)
            (ghostel-sync-theme))
          (when was (zetta-ghostel--remap-scrollback was now)))))))

(defcustom zetta-ghostel-remap-scrollback-limit 2000000
  "Largest ghostel buffer whose scrollback is recoloured on a theme change.
The walk is proportional to the number of colour runs, not to the
character count, but a terminal that has been running for days can hold a
great deal of both; past this many characters the scrollback is left as
it is rather than stalling the theme switch."
  :type 'integer
  :group 'ghostel)

(defun zetta-ghostel--remap-scrollback (was now)
  "Recolour text already on screen from palette WAS to palette NOW.

Only the viewport is the terminal's to repaint.  Everything above it is
scrollback -- plain Emacs text that ghostel appended as rows fell off the
top, carrying literal `(:foreground \"#rrggbb\")' from whatever palette
was live when it was written.  No redraw reaches it, full or not, so
without this a theme change leaves most of a long-lived terminal showing
the old palette and the change reads as not having happened at all.

Matching is by exact colour against the previous palette, so only text
this code coloured is touched: truecolor output keeps its own colours,
which is right -- the program asked for those specifically."
  (let ((map (cl-mapcar #'cons was now)))
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (when (and (derived-mode-p 'ghostel-mode)
                   (< (buffer-size) zetta-ghostel-remap-scrollback-limit))
          (let ((inhibit-read-only t)
                (inhibit-modification-hooks t)
                (buffer-undo-list t)
                (pos (point-min)))
            (while (< pos (point-max))
              (let* ((end (or (next-single-property-change pos 'face) (point-max)))
                     (val (get-text-property pos 'face)))
                ;; Only the anonymous plists the renderer emits; a face name
                ;; or a list of them is not ours to rewrite.
                (when (and (consp val) (keywordp (car val)))
                  (let ((new val) (changed nil))
                    (dolist (attr '(:foreground :background))
                      (let* ((cur (plist-get new attr))
                             (hit (and (stringp cur) (assoc cur map))))
                        (when (and hit (not (equal (car hit) (cdr hit))))
                          (setq new (plist-put (copy-sequence new) attr (cdr hit))
                                changed t))))
                    (when changed
                      (put-text-property pos end 'face new))))
                (setq pos end)))))))))

(defun zetta-ghostel-refresh-palette ()
  "Recompute and re-send the terminal palette right now.
Useful after editing `zetta-ghostel-hue-rotation' or the theme files, and
as a way to check what the current theme actually produces."
  (interactive)
  (setq zetta-ghostel--pushed-palette nil)
  (zetta-ghostel-apply-ansi-palette)
  (message "ghostel palette: %s"
           (mapconcat #'identity (seq-take zetta-ghostel--pushed-palette 8) " ")))

;; Belt and braces.  The push above rides on `brushup-styles', which is the
;; right moment, but it depends on this file's style staying appended after
;; `brushup-init'.  Running again at the very end of `enable-theme-functions'
;; costs nothing when the palette already matches -- the comparison in
;; `zetta-ghostel--push-palette' makes it a no-op -- and means a reordering
;; of that list cannot quietly bring the stale-palette bug back.
(defun zetta-ghostel--on-theme-change (&rest _)
  "Re-fit the palette after every other theme handler has run."
  (zetta-ghostel-apply-ansi-palette))

(add-hook 'enable-theme-functions #'zetta-ghostel--on-theme-change 90)

;; Appended: `brushup-init' recomputes the palette late in `brushup-styles',
;; and a prepended style would read the previous theme's background.
(with-eval-after-load 'brushup
  (add-to-list 'brushup-styles '(zetta-ghostel-apply-ansi-palette) t))
(with-eval-after-load 'ghostel (zetta-ghostel-apply-ansi-palette))

;;; Truecolor clamp
;;
;; ghostel starts every shell with `COLORTERM=truecolor' (ghostel.el:2169),
;; so anything that checks it -- Claude Code, delta, bat, eza -- emits
;; `ESC[38;2;R;G;Bm' and names an exact colour.  That bypasses the palette
;; above completely: no remapping can reach it, and those are the programs
;; whose output clashes hardest with a light page.  Clamping makes them
;; fall back to the indexed slots, which Emacs does control.
;;
;; It cannot be done from Emacs directly.  ghostel PREPENDS its own
;; entries to `process-environment' and the first match for a name wins,
;; so an ambient COLORTERM never gets a look in; the shell has to drop it
;; after the fact.  Hence a variable the shell can see, read by the
;; ghostel block in ~/.files/files/.zshrc.
;;
;; Environment is fixed at exec, so this only reaches terminals started
;; afterwards -- which is what makes it a fair A/B: leave one open either
;; way and compare.

(defcustom zetta-ghostel-clamp-truecolor nil
  "Whether new ghostel terminals should suppress truecolor output.
Toggle with `zetta-ghostel-toggle-truecolor-clamp' rather than setting
this directly, so the shell-visible variable is kept in step."
  :type 'boolean
  :group 'ghostel
  :set (lambda (sym val)
         (set-default sym val)
         (when (fboundp 'zetta-ghostel--sync-truecolor-clamp)
           (zetta-ghostel--sync-truecolor-clamp))))

(defun zetta-ghostel--sync-truecolor-clamp ()
  "Publish `zetta-ghostel-clamp-truecolor' where the shell can read it."
  (setenv "ZETTA_GHOSTEL_NO_TRUECOLOR"
          (and zetta-ghostel-clamp-truecolor "1")))

(defun zetta-ghostel-toggle-truecolor-clamp ()
  "Toggle whether new ghostel terminals suppress truecolor.
Terminals already running keep whatever they were started with, so open a
new one to see the difference."
  (interactive)
  (setq zetta-ghostel-clamp-truecolor (not zetta-ghostel-clamp-truecolor))
  (zetta-ghostel--sync-truecolor-clamp)
  (message "ghostel: new terminals %s"
           (if zetta-ghostel-clamp-truecolor
               "clamped to the 16 ANSI slots"
             "free to emit truecolor")))

(zetta-ghostel--sync-truecolor-clamp)

;;; Solaire tint
;;
;; ghostel asks Emacs what colour the page is and then paints the terminal
;; grid with it: `ghostel--apply-palette' hands the terminal
;; `(face-attribute 'default :background)' as its default background.  That
;; reads the GLOBAL default -- `face-attribute' does not consult buffer-local
;; face remapping, which is the only thing solaire ever does -- so in a
;; window solaire has tinted, the terminal goes on painting page colour and
;; overwrites the tint everywhere the grid reaches.  Which is the whole
;; window, so a tinted terminal simply looks untinted.
;;
;; Answer the question with the tinted colour instead, by pointing the
;; lookup at `solaire-default-face' (which carries the tint) in exactly the
;; buffers solaire has turned on.  Advising ghostel's own accessor rather
;; than formatting a hex string here keeps that normalisation in one place,
;; and leaves the 16 ANSI slots -- which ask the same function about
;; FOREGROUNDS -- untouched.
(declare-function ghostel--face-hex-color "ghostel" (face attr))
(declare-function ghostel--apply-palette "ghostel" (term))
(declare-function ghostel--redraw "ghostel-module" (term &optional full))
(declare-function zetta-solaire-tint-color "solaire-mode")

(define-advice ghostel--face-hex-color
    (:around (fn face attr) zetta-solaire-tint)
  "Report the SOLAIRE background for `default' in a tinted ghostel buffer."
  (if (and (eq face 'default) (eq attr :background)
           (bound-and-true-p solaire-mode)
           (facep 'solaire-default-face))
      (funcall fn 'solaire-default-face :background)
    (funcall fn face attr)))

(defvar-local zetta-ghostel--applied-bg nil
  "The page colour last sent to this buffer's terminal.")

(defun zetta-ghostel-sync-tint (&optional _frame)
  "Re-send the palette to any displayed terminal whose page colour moved.

solaire tints per WINDOW here (`zetta-solaire-tint-what' is `side-window'),
so dragging a terminal into or out of a side window changes the colour it
ought to be drawn on -- and nothing in ghostel is watching: the palette is
sent when the terminal starts and when the THEME changes, and neither has
happened.  Hence this, on the same hook solaire itself syncs from.

Safe to run that often because it compares the colour first and only
repaints when it actually changed."
  (dolist (w (window-list nil 'no-mini))
    (with-current-buffer (window-buffer w)
      (when (and (derived-mode-p 'ghostel-mode)
                 (bound-and-true-p ghostel--term))
        (let ((bg (ghostel--face-hex-color 'default :background)))
          (unless (equal bg zetta-ghostel--applied-bg)
            (setq zetta-ghostel--applied-bg bg)
            (ghostel--apply-palette ghostel--term)
            ;; A repaint is what actually moves the colour already on
            ;; screen; the palette alone only governs what is drawn next.
            ;; Skipped in copy mode for the reason `ghostel-sync-theme'
            ;; skips it: that buffer is not the terminal's to rewrite.
            (unless (bound-and-true-p ghostel--copy-mode-active)
              (let ((inhibit-read-only t))
                (ghostel--redraw ghostel--term)))))))))

;; Depth 90 -- after `zetta-solaire-sync-windows', which is the thing that
;; turns solaire-mode on or off for the window that just moved.
(with-eval-after-load 'ghostel
  (add-hook 'window-configuration-change-hook #'zetta-ghostel-sync-tint 90))

(defun zetta-ghostel--restore-cursor-column (&rest _)
  "Put point at the terminal's cursor column even on a trimmed trailing blank.

The renderer trims trailing blank cells off every row so the buffer does
not carry the full-width viewport padding (src/render.zig), and then caps
point at end-of-line -- \"so we never jump past it into the next row (can
happen when cursor is on a trimmed trailing blank)\".

The consequence while typing: press space at the end of a word and the
cursor cannot advance, because the space was trimmed and there is no
column to land on.  It only springs forward once a non-blank character
arrives and the row stops being trimmed.

Point's LINE is already correct after a redraw -- only the column was
clamped -- so pad the current row out to the reported column with the
spaces the terminal grid actually holds.  Undo is suppressed: this is
rendered output, not user text."
  (when (and ghostel--term (not (bound-and-true-p ghostel--copy-mode-active)))
    (let ((col (car (ghostel--cursor-position ghostel--term))))
      (when (and col (> col (current-column)))
        (let ((inhibit-read-only t)
              (inhibit-modification-hooks t)
              (buffer-undo-list t))
          (move-to-column col t))))))

(defun zetta-ghostel--evil-owns-cursor (orig-fn style visible)
  "Keep evil's state cursor from being clobbered by the terminal.
`ghostel--set-cursor-style' assigns `cursor-type' straight from the style
the terminal reports, so anything emitting DECSCUSR -- zsh's line editor,
tmux, a full-screen TUI -- overwrites the shape evil just set.  Entering
insert state therefore flashes the narrow bar and then turns into a box on
the next repaint.

Unlike `evil-ghostel--override-cursor-style', this does NOT exempt
alt-screen mode (DEC 1049): tmux holds the alt screen for its entire
session, which is the normal working state here, so exempting it would
leave the cursor terminal-controlled essentially always.

An explicit hide request is still honoured -- only the shape is taken
over, never visibility."
  (if (and visible
           (bound-and-true-p evil-local-mode)
           (fboundp 'evil-refresh-cursor)
           (not (bound-and-true-p ghostel--copy-mode-active)))
      (evil-refresh-cursor)
    (funcall orig-fn style visible)))

(defun zetta-ghostel-send-up ()
  "Send the up-arrow key to the ghostel terminal."
  (interactive)
  (ghostel--send-encoded "up" ""))

(defun zetta-ghostel-send-down ()
  "Send the down-arrow key to the ghostel terminal."
  (interactive)
  (ghostel--send-encoded "down" ""))

(use-package ghostel
  ;; `etc' carries the shell-integration scripts (ghostel injects ZDOTDIR
  ;; pointing at etc/shell-integration/zsh).  Elpaca's default :files does
  ;; NOT link it into the build directory, so `ghostel--start-process' finds
  ;; no integration dir and silently skips it -- taking OSC 7 directory
  ;; tracking, OSC 2 title tracking and OSC 133 prompt marks with it.
  :ensure (ghostel :host github :repo "dakra/ghostel"
                   :files (:defaults "etc"))
  :commands (ghostel ghostel-project ghostel-other)

  :init
  ;; Item 1 -- clipboard from inside the terminal.
  ;; tmux is already set to `set-clipboard external', i.e. it forwards OSC 52
  ;; out to the host terminal rather than swallowing it; ghostel was dropping
  ;; it at the far end.  With this on, a copy inside tmux/Claude Code/any TUI
  ;; reaches the Emacs kill ring and the system clipboard.
  ;; Note this lets any program in the terminal write the clipboard.
  (setq ghostel-enable-osc52 t)

  :config
  ;; Item 3 -- make ghostel a first-class project terminal.
  ;; NOT by substituting `project-eshell' the way modules/term/vterm.el does:
  ;; both would be claiming the same `e' slot, so whichever module loaded
  ;; last would silently win.  Take an unused key instead, which leaves both
  ;; eshell and vterm's substitution intact.
  (with-eval-after-load 'project
    (keymap-set project-prefix-map "t" #'ghostel-project)
    (unless (assq 'ghostel-project project-switch-commands)
      ;; keep `project-any-command' ("Other") last in the menu
      (let ((tail (assq 'project-any-command project-switch-commands)))
        (setq project-switch-commands
              (if tail
                  (append (remq tail project-switch-commands)
                          (list '(ghostel-project "Ghostel") tail))
                (append project-switch-commands
                        (list '(ghostel-project "Ghostel"))))))))

  (advice-add 'ghostel--set-cursor-style :around
              #'zetta-ghostel--evil-owns-cursor)
  (advice-add 'ghostel--redraw :after
              #'zetta-ghostel--restore-cursor-column)

  ;; Item 5 -- let space-tree's navigation keys through.
  ;; `modules/ui/spacetree.el' binds M-<tab> (go-to-last-space),
  ;; M-S-<tab> (switch-space-by-name) and C-M-<tab> (go-right) globally,
  ;; but ghostel's special-keys loop binds every <tab> variant across the
  ;; mods `S- C- M- C-S- M-S- C-M-', so in a ghostel buffer they were
  ;; reaching `ghostel--send-event' instead.  That loop -- unlike the
  ;; C-<letter> and M-<letter> loops right beside it -- never consults
  ;; `ghostel-keymap-exceptions', so there is no supported opt-out.
  ;; vterm never bound these at all, which is why it worked there.
  ;;
  ;; Unbind rather than re-bind to the space-tree commands: lookup then
  ;; falls through to whatever is global, so this survives any remap in
  ;; spacetree.el.  C-M-S-<tab> (go-left) is absent from ghostel's mod
  ;; list and already reached Emacs, so it is not listed here.
  ;; To send a literal M-TAB to the program, use C-c C-q
  ;; (`ghostel-send-next-key').
  (dolist (key '("M-<tab>" "M-S-<tab>" "C-M-<tab>"))
    (keymap-unset ghostel-mode-map key t))

  :general
  (
   :states '(insert)
   :keymaps '(ghostel-mode-map)
   "C-s" 'ghostel--send-event
   ;; Item 4 -- C-x is deliberately in `ghostel-keymap-exceptions', i.e. meant
   ;; to reach Emacs.  Sending it stole C-x b / C-x o / C-x 0 inside the
   ;; terminal, which mattered less when normal state barely worked here.
   ;; To send a literal C-x to the program, use C-c C-q (ghostel-send-next-key).
   "C-," 'zetta-ghostel-send-event-with-text
   "<escape>" 'ghostel--send-event
   "C-u" 'universal-argument
   )

  (
   :states '(normal)
   :keymaps '(ghostel-mode-map)
   "C-b" 'ghostel--send-event
   "C-," 'zetta-ghostel-send-event-with-text
   "C-k" 'zetta-ghostel-send-up
   "C-j" 'zetta-ghostel-send-down
   )
  )
;;; ghostel.el ends here
