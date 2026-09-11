;;; solaire-mode.el --- Configure solaire-mode -*- lexical-binding: t; -*-
;; Upstream: https://github.com/hlissner/emacs-solaire-mode

(require 'color)

;; Tints the SIDE windows -- the treemacs sidebar, popper's popups, anything
;; put on screen with `display-buffer-in-side-window' -- so the windows you
;; work in stay at page colour and the ones the editor puts around them sit
;; one rung off it.
;;
;; That is not solaire's own rule.  solaire tints every buffer NOT VISITING A
;; FILE, which is close but tints `*scratch*' in the main window too; see
;; `zetta-solaire-tint-what' for the switch between the two.
;;
;; Which DIRECTION that rung goes is the theme's business, not ours.
;; `brushup-bg-1' is one `brushup-gradient-step' toward the foreground:
;; lighter under a dark theme, darker under a light one.  So the tint
;; follows a light/dark switch with no second rule to keep in sync, and
;; brushup re-evaluates the style below on every theme change (`:brushup').
;;
;; Two things to know about the grain of it:
;;
;; - the tint is stored per BUFFER, because face remapping is buffer-local.
;;   Side-ness is a property of the WINDOW, so the two are matched up by
;;   `zetta-solaire-sync-windows' on every window-configuration change.  The
;;   one case the buffer-local store cannot express is the same buffer shown
;;   in a side window AND a normal one at once: it is tinted in both.
;;
;; - the mode line and header line are transparent SVG images (see
;;   `modeline-svg.el' and `header-line-svg.el'): nothing is painted behind
;;   them, so their FACE backgrounds are what shows through.  solaire's own
;;   `solaire-mode-remap-alist' remaps those faces along with `default',
;;   which is what keeps a tinted window one solid block rather than a
;;   tinted middle with untinted bands top and bottom.

;; Forward declarations -- the package is installed by elpaca and these are
;; touched before it loads.
;; `solaire-mode' itself must be declared special here, not merely referenced:
;; `zetta-solaire--untinted-a' LET-BINDS it, and without this the byte
;; compiler makes that a lexical binding -- a no-op that silently drops the
;; fix rather than failing.
(defvar solaire-mode)
(defvar solaire-mode-supported-themes)
(defvar solaire-mode--theme)
(defvar solaire-mode-real-buffer-fn)
(defvar solaire-mode-remap-alist)
(defvar solaire-global-mode-hook)
(declare-function solaire-mode "solaire-mode" (&optional arg))
(declare-function solaire-mode--auto-detect-theme "solaire-mode")
(declare-function solaire-mode-fix-minibuffer "solaire-mode" (&optional unset))
(declare-function turn-on-solaire-mode "solaire-mode" (&rest _))
(declare-function solaire-global-mode "solaire-mode" (&optional arg))

(defcustom zetta-solaire-tint-what 'side-window
  "Which windows get the tint.

`side-window\=' -- buffers shown in a SIDE window, i.e. one carrying a
`window-side\=' parameter because it was put there by
`display-buffer-in-side-window\=': the treemacs sidebar, popper\='s popups.
This is the literal reading of \"tint the side windows\", and it costs a
check on `window-configuration-change-hook\=', because side-ness belongs to
the window and can change under a buffer that has not changed at all.

`non-file\=' -- solaire\='s own rule: every buffer that is not visiting a
file.  Decided once, when the buffer gets its major mode, so it is cheaper
and needs no hook -- but it tints `*scratch*\=', `*Messages*\=' and every
other non-file buffer WHEREVER they are shown, main window included, which
is usually read as the tint being broken rather than as the rule being
wider than expected.

Read at load and when `zetta-solaire-sync-windows\=' runs; set it and call
that function to switch without a restart."
  :type '(choice (const :tag "Buffers in side windows" side-window)
                 (const :tag "Buffers not visiting a file" non-file))
  :group 'zetta)

(defcustom zetta-solaire-tint-rung '(0.45 . 0.25)
  "How far off the page the tint sits, in rungs of the brushup ladder.

Either a number, used under every theme, or a cons (DARK . LIGHT) setting
the two polarities separately -- which is what the default does, and why:
the SAME step does not read the same on both.  A dark page has hue and
depth for a step to sink into; a light one has neither, so a grey laid on
white reads as a different MATERIAL rather than as the same page slightly
shaded.  The light figure is therefore the smaller of the two.

1.0 is exactly `brushup-bg-1' -- one `brushup-gradient-step' (7% by
default).  FRACTIONS are the useful range here: a whole rung is a step
sized for text-on-background contrast, and a side window only has to read
as a different surface, not as a different colour.  0 means no tint at
all, which is how to see what solaire is doing without switching it off.

Stated in rungs rather than as a colour or a bare percentage so the tint
stays on the ladder brushup derives from the theme, and so it keeps
stepping the right WAY when the theme flips: the ladder runs toward the
foreground, so a positive rung is lighter than the page under a dark theme
and darker under a light one.

Worth re-checking after a transparency change -- `alpha-background' scales
the difference between two backgrounds along with the backgrounds
themselves, so a step that reads on an opaque frame can vanish on a
translucent one.

Takes effect on the next `brushup' refresh (any theme change, or
\\[brushup]); or call `zetta-solaire-apply-faces' directly."
  :type '(choice (number :tag "Same under every theme")
                 (cons :tag "Set per polarity"
                       (number :tag "Dark theme")
                       (number :tag "Light theme")))
  :group 'zetta)

(defcustom zetta-solaire-tint-minibuffer nil
  "When non-nil, let solaire tint the minibuffer and echo area too.

Off, because `mini-echo-mode' owns the echo area here: it keeps persistent
segments in \" *Echo Area 0*\" / \" *Minibuf-0*\", and solaire\\='s
`solaire-mode-fix-minibuffer' writes into those same buffers (it inserts an
invisible space so the tint reaches end-of-line, and makes them unkillable)
to get the tint to take.  Two packages editing the same scratch buffers is
a fight with no upside for a request about SIDE WINDOWS.

Vertico\\='s minibuffer is not a side window either way, so leaving it at
page colour also keeps the completion UI looking like it did.

Read once, at load: changing it needs a restart."
  :type 'boolean :group 'zetta)

(defun zetta-solaire--rung ()
  "Resolve `zetta-solaire-tint-rung' for the theme now in force.
`brushup-dark-p' is brushup\='s own reading of the page, so this asks the
same question the ladder\='s DIRECTION was built from rather than a second,
possibly disagreeing one."
  (let ((r zetta-solaire-tint-rung))
    (cond ((consp r) (or (if (bound-and-true-p brushup-dark-p) (car r) (cdr r)) 0))
          ((numberp r) r)
          (t 0))))

(defun zetta-solaire-tint-color ()
  "Return the tint: `zetta-solaire--rung' rungs off the page.

Runs brushup\='s own ladder arithmetic rather than reading `brushup-bg-N',
because those variables only exist at whole rungs and the useful tint here
is a fraction of one.  At rung 1.0 this returns exactly `brushup-bg-1'.

Computed at call time, not captured: brushup recomputes the palette on
every theme change and re-evaluates the style that calls this right after."
  (let ((bg (or (bound-and-true-p brushup-bg) (face-background 'default nil t)))
        (step (or (bound-and-true-p brushup-gradient-step) 7))
        (dir (if (bound-and-true-p brushup-dark-p) 1 -1))
        (rung (zetta-solaire--rung)))
    (if (or (null bg) (zerop rung))
        bg
      (color-lighten-name bg (* rung step dir)))))

(defface zetta-solaire-tint-face '((t nil))
  "Background-only stand-in for faces solaire\='s alist does not cover.

Sets NOTHING but `:background\='.  That is the whole point: face remapping
is relative, so remapping FOO to this face resolves as (this-face FOO) and
takes the background from here and every other attribute -- foreground,
weight, box -- from FOO itself.  One face can therefore re-seat any number
of unrelated faces onto the tint without flattening what makes each of them
distinct, which mapping them to `solaire-default-face\=' would do."
  :group 'zetta)

(defface zetta-solaire-arrow-face '((t nil))
  "Background-only tint for `modern-fringes-arrows\='.

Separate from `zetta-solaire-tint-face\=' because that face is painted a
hair darker than the page on purpose (`modern-fringes.el\=' gives it
`brushup-bg-1_0\='), so the arrow reads as a chip set INTO the fringe.
Flattening it to the tint would keep the glyph and lose the chip; this
keeps the same offset, measured from the tint instead of from the page."
  :group 'zetta)

(defun zetta-solaire-apply-faces ()
  "Paint the solaire faces from the brushup palette.

Registered as a brushup style, so it re-runs on every theme change and the
tint follows a light/dark switch by itself."
  (when (facep 'solaire-default-face)
    (let ((tint (zetta-solaire-tint-color)))
      ;; Background only -- the foreground stays whatever `default' says, so
      ;; a tinted buffer reads as the same ink on a different page.
      (set-face-attribute 'solaire-default-face nil
                          :background tint :foreground 'unspecified)
      ;; The fringe and the line numbers are part of that page.  Set
      ;; explicitly rather than left to `:inherit': the bootstrap paints
      ;; `fringe' to `brushup-bg' and themes give `line-number' a background
      ;; of its own, and an inherited attribute loses to one that is set.
      ;; Faces solaire has never heard of, re-seated onto the tint through
      ;; the two background-only faces above.  `line-number' is remapped by
      ;; solaire itself, but its current-line and tick siblings are not, so
      ;; in a tinted window they stayed at page colour and read as dark
      ;; boxes down the gutter.
      (set-face-attribute 'zetta-solaire-tint-face nil :background tint)
      (set-face-attribute 'zetta-solaire-arrow-face nil
                          :background (color-lighten-name tint -3))
      (dolist (face '(solaire-fringe-face solaire-line-number-face
                      ;; Transparent SVG bars: these face backgrounds ARE the
                      ;; bar, so they carry the tint to the window's top and
                      ;; bottom edges instead of leaving untinted bands.
                      solaire-mode-line-face solaire-mode-line-active-face
                      solaire-mode-line-inactive-face solaire-header-line-face))
        (when (facep face)
          (set-face-attribute face nil :background tint))))))

(defun zetta-solaire--side-window-p (&optional buffer)
  "Non-nil if BUFFER (default: the current one) is shown in a side window.

Asks every window displaying it, on every frame, so a buffer that is in a
side window somewhere counts as tinted everywhere -- which is the only
answer a buffer-local face remap can give."
  (catch 'side
    (dolist (w (get-buffer-window-list (or buffer (current-buffer)) 'nomini t))
      (when (window-parameter w 'window-side)
        (throw 'side t)))))

(defun zetta-solaire-sync-windows (&rest _)
  "Match `solaire-mode' to side-window-ness for the buffers now on screen.

Needed because `turn-on-solaire-mode' only ever runs when a buffer gets its
major mode -- which is BEFORE it is displayed, when there is no window to
ask about side-ness yet -- and because a window can become, or stop being,
a side window with no change to the buffer in it at all.

Only walks the windows of the selected frame: that is the frame whose
configuration just changed, and the hook runs once per frame that changes."
  (when (and (bound-and-true-p solaire-global-mode)
             (eq zetta-solaire-tint-what 'side-window))
    (dolist (w (window-list nil 'no-mini))
      (with-current-buffer (window-buffer w)
        (unless (zetta-solaire--echo-area-p)
          (let ((want (and (zetta-solaire--side-window-p) t))
                (now  (and (bound-and-true-p solaire-mode) t)))
            (unless (eq want now)
              (solaire-mode (if want 1 -1)))))))))

(defun zetta-solaire--untinted-a (fn &rest args)
  "Run FN on ARGS as if no buffer tint were in force.

solaire advises `create-image\=' to stamp the tint onto the `:background\=' of
every image built while a tinted buffer is current.  For the mode line and
the header line that is exactly right -- those bars belong to the WINDOW,
and a tinted window\='s bars should be tinted with it.

The TAB BAR belongs to the FRAME, but it is drawn with the selected
window\='s buffer current, so selecting a side window handed the whole tab
bar that buffer\='s tint -- the bar changing colour according to which
window you happened to be in.  Binding `solaire-mode\=' off for the duration
takes the stamp out of the picture; nothing else on the render path reads
it.  The bar\='s own SVG is transparent either way, so what shows through
is the `tab-bar\=' face, which is where its colour should come from."
  (let ((solaire-mode nil))
    (apply fn args)))

;; Installed unconditionally: `svg-line-define\=' builds this renderer with
;; `defalias\=', which carries existing advice across, so the order in which
;; this module and `tab-bar-svg.el\=' load does not matter.
(advice-add 'svg-line--render-zetta-tab-bar :around #'zetta-solaire--untinted-a)

(defun zetta-solaire--echo-area-p ()
  "Non-nil in the minibuffer and in the echo-area buffers.
`minibufferp' covers \" *Minibuf-N*\"; the echo areas are ordinary buffers
and have to be matched by name."
  (or (minibufferp)
      (string-match-p "\\` \\*\\(Minibuf\\|Echo Area\\)" (buffer-name))))

(defun zetta-solaire--not-echo-area-p (&rest _)
  "Veto `turn-on-solaire-mode' in the minibuffer and echo area.

Used as `:before-while' advice, so returning nil stops solaire switching
on.  Advice rather than a hook because `turn-on-solaire-mode' enables
itself in a minibuffer UNCONDITIONALLY -- its own `(or (minibufferp) ...)'
short-circuits ahead of `solaire-mode-real-buffer-fn', so that variable
cannot express this.  See `zetta-solaire-tint-minibuffer'."
  (not (zetta-solaire--echo-area-p)))

(use-package solaire-mode
  :demand t

  :init
  ;; solaire asks the theme whether it supports solaire (i.e. whether it
  ;; defines `solaire-default-face'), and switches ITSELF off when the
  ;; answer is no.  None of the themes here define it -- and none needs to,
  ;; since the `:brushup' style below paints the faces from the palette --
  ;; so force the gate open.  Set before the package loads: it caches the
  ;; answer the first time it sees a theme.
  (setq solaire-mode-supported-themes :all)

  :config
  ;; Re-ask, now that `:all' is set.  The cache is filled by a `load-theme'
  ;; advice that solaire installs from its AUTOLOADS, which elpaca may load
  ;; before `:init' above runs -- and `theme.el' has already called
  ;; `load-theme' by then.  Clearing the remembered theme makes solaire's
  ;; own detector run again on the theme that is actually enabled.
  (setq solaire-mode--theme nil)
  (solaire-mode--auto-detect-theme)

  (unless zetta-solaire-tint-minibuffer
    (remove-hook 'solaire-global-mode-hook #'solaire-mode-fix-minibuffer)
    (advice-add 'turn-on-solaire-mode :before-while #'zetta-solaire--not-echo-area-p))

  ;; Swap solaire's "is it a file?" question for "is it in a side window?".
  ;; The predicate is inverted by contract -- `turn-on-solaire-mode' tints
  ;; when this returns NIL -- so a side-window buffer must answer nil.
  (when (eq zetta-solaire-tint-what 'side-window)
    (setq solaire-mode-real-buffer-fn
          (lambda () (not (zetta-solaire--side-window-p))))
    (add-hook 'window-configuration-change-hook #'zetta-solaire-sync-windows))

  ;; Extend solaire's remap alist.  Everything here is painted from
  ;; `brushup-bg' by the theme or by another module, so without an entry it
  ;; keeps PAGE colour inside a tinted window and shows up as a patch.
  ;; Appended, so solaire's own entries keep their order.
  (dolist (entry '((line-number-current-line . zetta-solaire-tint-face)
                   (line-number-major-tick   . zetta-solaire-tint-face)
                   (line-number-minor-tick   . zetta-solaire-tint-face)
                   ;; `bootstrap-brushup.el' paints `button' to `brushup-bg',
                   ;; so links in a *Help* popup were page-coloured chips
                   (button                   . zetta-solaire-tint-face)
                   ;; owned by `modern-fringes.el'; the wrap/truncate arrows
                   (modern-fringes-arrows    . zetta-solaire-arrow-face)))
    (add-to-list 'solaire-mode-remap-alist entry t))

  (solaire-global-mode 1)
  (zetta-solaire-sync-windows)

  ;; Paint them now.  brushup ran its styles back when the theme loaded,
  ;; before these faces existed, and no further theme change is coming --
  ;; so without this the tint would not appear until the next one.
  (zetta-solaire-apply-faces)

  :brushup
  ;; APPENDED, not prepended.  `add-to-list' prepends by default, and the
  ;; installed brushup (0.1.8) evaluates `brushup-styles' in order with
  ;; `(brushup-init)' -- the form that recomputes the palette -- sitting at
  ;; the END of the list.  A prepended style therefore reads the PREVIOUS
  ;; theme's ladder and lands one theme change behind, which for this module
  ;; means a light/dark switch tinting the wrong way until the next switch.
  ;; Appending puts us after `(brushup-init)', so the ladder is current.
  ;; 0.1.9 calls `brushup-init' up front and fixes this for every style; the
  ;; append is correct either way, so it stays after the update lands.
  (add-to-list 'brushup-styles '(zetta-solaire-apply-faces) t)
  )
;;; solaire-mode.el ends here
