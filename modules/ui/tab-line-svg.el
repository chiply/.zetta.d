;;; tab-line-svg.el --- Wrapping SVG tab line (svg-line config) -*- lexical-binding: t; -*-

;; The complete tab-line module.  It owns BOTH the tab-line system (the
;; `use-package tab-line' block below: global-tab-line-mode, the buffer
;; selector + scopes, close commands, g1-g9 / C-tab keybindings, faces,
;; built-in tab labels) AND the SVG renderer that draws the per-window
;; tab line as a single SVG image using the `wrap' layout (tabs flow
;; left-to-right and WRAP overflow onto new rows instead of truncating or
;; scrolling).  The rendering itself lives in the `svg-line' engine.
;;
;; Tab data comes from `tab-line-tabs-function'.  Labels are "N name",
;; where N is the 1-based index matching the g1..g9 jump keys.  The
;; current tab is drawn bold, in `current-foreground', over a
;; `current-background' pill.  A buffer with unsaved changes is drawn in
;; `modified-foreground' with a trailing marker, and the whole tab line
;; dims to an inactive palette when its window is not selected (the same
;; active/inactive distinction the SVG mode line makes).
;;
;; The strip has NO background of its own: the tabs are pills floating on
;; the buffer background (the `tab-line' face, painted to `brushup-bg').
;; So the focused/unfocused distinction is carried by the pills alone --
;; the selected window's current tab inverts to a near-foreground pill,
;; every unfocused element steps down the same background ladder.
;;
;; Switch at runtime:
;;   M-x zetta-tab-line-use-svg       ; activate the wrapping SVG tab line
;;   M-x zetta-tab-line-use-default   ; restore the built-in tab line
;;   M-x zetta-tab-line-toggle        ; flip
;;
;; CAVEATS: single-font SVG text (the all-the-icons file icon is dropped;
;; the number prefix carries the useful info), and KEYBOARD interaction
;; only (as one image there are no per-tab mouse click / close targets).

(require 'svg-line)

(defcustom zetta-tab-line-name-space-ok t
  "When non-nil, a DISPLAYED buffer gets a tab line even if its name starts
with a space.

That prefix is the convention for buffers the user is not meant to see, and
`tab-line-mode--turn-on' skips them on that basis.  The convention breaks
down for a buffer that is on screen anyway: treemacs names its sidebar
\" *Treemacs-Buffer-#<frame 0x...>\", and the tab line is the one piece of
chrome that would say so.  Consulted only by `zetta-tab-line-ensure', which
runs when a buffer lands in a window, so a hidden buffer stays untouched."
  :type 'boolean :group 'zetta)

;; `ct/circle-number' (defined in the `tab-line' use-package :config below)
;; wraps `zetta-circle-number' (line-utils) -- the shared source of the
;; numbered-circle glyphs also used by svg-margin's org rail.  Declared here so
;; the top-level SVG content function compiles cleanly.
(declare-function ct/circle-number "tab-line-svg")
(declare-function zetta-circle-number "line-utils")

;;; ==================================================================
;;; Tab-line SYSTEM (merged from the former tab-line.el): enables
;;; global-tab-line-mode, the buffer selector + scopes, close commands,
;;; g1-g9 / C-tab keybindings, faces, and the built-in tab labels.  The
;;; SVG renderer further below overrides only the rendering.
;;; ==================================================================
(use-package tab-line
  :ensure nil
  :hook (elpaca-after-init . global-tab-line-mode)

  :config

  (setq tab-line-switch-cycling t tab-line-close-button-show t)
  (setq tab-line-exclude-modes '(minibuffer-mode minibuffer-inactive-mode))

  (defun zetta-tab-line-ensure (&optional _frame)
    "Give newly displayed buffers a tab line when the globalized mode missed them.

`global-tab-line-mode' turns the mode on from `after-change-major-mode-hook',
plus one sweep of `buffer-list' when it is first enabled.  A buffer created
with `get-buffer-create' and left in `fundamental-mode' never SETS a major
mode, so the hook never fires -- and if it was created after startup the
sweep has already run.  That is the shape most process and log buffers take
\(`*copilot-language-server-log*' is the one that turned up here), and they
end up as the odd buffer with no tab line for no visible reason.  The
`fundamental-mode' hook below does not cover it: that fires when
`fundamental-mode' is CALLED, not when a buffer is merely born in it.

Runs from `window-buffer-change-functions', i.e. exactly when a buffer lands
in a window -- the moment you would notice.  Eligibility is left to
`tab-line-mode--turn-on', so the exclusion rules stay in one place, with the
one exception described in `zetta-tab-line-name-space-ok'."
    (when (bound-and-true-p global-tab-line-mode)
      (dolist (w (window-list nil 'no-minibuf))
        (with-current-buffer (window-buffer w)
          (unless (bound-and-true-p tab-line-mode)
            (ignore-errors (tab-line-mode--turn-on))
            ;; `tab-line-mode--turn-on' exempts any buffer whose name begins
            ;; with a space, the convention for buffers the user is not
            ;; supposed to see.  A buffer that is ON SCREEN plainly is not
            ;; one of those, whatever it called itself -- treemacs names its
            ;; sidebar \" *Treemacs-Buffer-#<frame 0x...>\" and so has never
            ;; had a tab line, which is the one place the name is worth
            ;; showing.  Every OTHER exclusion is still honoured; only the
            ;; leading space is overridden.
            (when (and (not (bound-and-true-p tab-line-mode))
                       zetta-tab-line-name-space-ok
                       (string-match-p "\\` " (buffer-name))
                       (not (minibufferp))
                       (not (memq major-mode tab-line-exclude-modes))
                       (not (buffer-match-p tab-line-exclude-buffers (buffer-name)))
                       (not (get major-mode 'tab-line-exclude))
                       (not (buffer-local-value 'tab-line-exclude (current-buffer))))
              (tab-line-mode 1)))))))

  (add-hook 'window-buffer-change-functions #'zetta-tab-line-ensure)

  (defun tab-line-close-tab-1 ()
    "Close the selected tab.
If the tab is presented in another window, close the tab by using the `bury-buffer` function.
If the tab is unique to all existing windows, kill the buffer with the `kill-buffer` function.
Lastly, if no tabs are left in the window, it is deleted with the `delete-window` function."
    (interactive)
    (let* ((window (selected-window))
           (buffer (current-buffer)))
      (with-selected-window window
        (let ((tab-list (tab-line-tabs-window-buffers))
              (buffer-list (flatten-list
                            (seq-reduce (lambda (list window)
                                          (select-window window t)
                                          (cons (tab-line-tabs-window-buffers) list))
                                        (window-list) nil))))
          (select-window window)
          (if (> (seq-count (lambda (b) (eq b buffer)) buffer-list) 1)
              (progn
                (if (eq buffer (current-buffer))
                    (bury-buffer)
                  (set-window-prev-buffers window (assq-delete-all buffer (window-prev-buffers)))
                  (set-window-next-buffers window (delq buffer (window-next-buffers))))
                (unless (cdr tab-list)
                  (ignore-errors (delete-window window))))
            (and (kill-buffer buffer)
                 (unless (cdr tab-list)
                   (ignore-errors (delete-window window)))))))
      (force-mode-line-update)))

  (defun ct/circle-number (n)
    "Circled-number glyph for tab index N (1-based), or nil.
A thin wrapper over `zetta-circle-number' (the shared glyph source).  No
trailing space -- the number sits flush against the file/mode glyph that
follows; callers add their own separator before the buffer name."
    (zetta-circle-number n))

  (defun zetta-tab-line-tab-name-buffer (buffer &optional _buffers)
    (let* ((buffer-name (buffer-name buffer))
           (bufnm buffer-name)
           (bufnm (string-replace "helpful function" "H" bufnm))
           (bufnm (string-replace "helpful command" "H" bufnm))
           (bufnm (string-replace "helpful variable" "H" bufnm))
           (bufnm (string-replace "Embark Export" "EE" bufnm))
           (bufnm (string-replace "Embark Collect" "EC" bufnm))
           (bufnm (string-replace "Embark Export Grep" "EE G" bufnm))
           (bufnm (string-replace "Embark Export Occur" "EE O" bufnm))
           (bufnm (string-replace "Embark Export Dired" "EE D" bufnm))
           (fname (buffer-file-name buffer))
           (icon (cond (fname (all-the-icons-icon-for-file fname))
                       (t (all-the-icons-icon-for-mode (with-current-buffer buffer major-mode))))))
      (concat
       (ct/circle-number (+ 1 (cl-position buffer (funcall tab-line-tabs-function))))
       icon
       (propertize (if fname
                       ;; the file name including the suffix
                          (concat (file-name-nondirectory fname))
                       ;;(file-name-base fname)
                     bufnm)
                   'face '(:height 1.0)))))

  (setq tab-line-tab-name-function 'zetta-tab-line-tab-name-buffer)

  (setq tab-line-tabs-function 'tab-line-tabs-window-buffers)

  (defun zetta-tab-line-faces ()
    "Style the built-in tab-line faces and the face the SVG image sits on."
    (set-face-attribute 'tab-line-tab-current nil :box nil :inherit nil :background brushup-bg-1_0 :foreground brushup-fg :overline nil :weight 'bold :underline brushup-bg-6)
    (set-face-attribute 'tab-line-tab-modified nil :box nil :inherit nil :background brushup-fg-4 :foreground brushup-bg :overline nil)
    ;; NOTE this applies to active tabs in other windows, counter intuitive
    (set-face-attribute 'tab-line-tab nil :box nil :inherit nil :background brushup-bg :foreground brushup-bg-5 :underline brushup-bg-6)
    (set-face-attribute 'tab-line-tab-inactive nil :box nil :inherit nil :background brushup-bg :foreground brushup-bg-5)
    ;; The `tab-line' face is what the SVG image sits on: its background is
    ;; what shows through the image's transparent margin, and its OVERLINE is
    ;; a single-sided rule along the top of the tab line -- which, the tab
    ;; line being per-window, is a rule along the top of each WINDOW.
    ;; The overline here is the FALLBACK.  A face attribute is painted
    ;; across the face's whole extent, so on a window-width image it is a
    ;; window-width rule and cannot be inset; svg-line draws an inset one
    ;; itself (`:rule' in the definition below) wherever the engine is new
    ;; enough to know the key.  Both would show as two rules, so this one
    ;; stands down when the other is available.
    (set-face-attribute 'tab-line nil :box nil :inherit nil
                        :background brushup-bg :foreground brushup-bg-3
                        :overline (and zetta-tab-line-svg-overline
                                       (not (bound-and-true-p svg-line-rule-supported))
                                       (zetta-line-blend brushup-bg brushup-fg
                                                         zetta-tab-line-svg-overline-strength))))

  ;; Appended: `brushup-init' recomputes the palette near the END of
  ;; `brushup-styles', so a prepended entry reads the PREVIOUS theme's
  ;; colours and lands one theme change behind -- the same bug that made the
  ;; window dividers reappear on every theme switch.
  (add-to-list 'brushup-styles '(zetta-tab-line-faces) t)

  ;; tab-line's switching commands wrap their work in
  ;; `with-selected-window', which restores the CURRENT BUFFER on exit --
  ;; but the window's buffer has already changed underneath it.  So the
  ;; command returns with `current-buffer' still the buffer you left while
  ;; the window shows the one you arrived at, and `post-command-hook' then
  ;; runs against the wrong buffer.  Two symptoms, one cause:
  ;;
  ;;   global-hl-line moves its overlay in the buffer you LEFT, so the new
  ;;   one has no highlight until the next command;
  ;;
  ;;   beacon's buffer-change trigger compares against the current buffer,
  ;;   sees nothing changed, and never blinks.
  ;;
  ;; Resync after the command and before the hook.  Upstream's own bug --
  ;; reproduced in `emacs -Q' -- so this rides on the commands rather than
  ;; being worked around in hl-line or beacon, which are only two of the
  ;; things a wrong `current-buffer' can mislead.
  (defun zetta-tab-line--resync-current-buffer (&rest _)
    "Make the selected window's buffer current after a tab-line switch."
    (let ((buf (window-buffer (selected-window))))
      (when (and (buffer-live-p buf) (not (eq buf (current-buffer))))
        (set-buffer buf))))

  (dolist (cmd '(tab-line-switch-to-next-tab
                 tab-line-switch-to-prev-tab
                 tab-line-select-tab
                 tab-line-select-tab-buffer
                 tab-line-close-tab))
    (advice-add cmd :after #'zetta-tab-line--resync-current-buffer))

  :general
  (
   :keymaps 'override
   "C-<tab>" 'tab-line-switch-to-next-tab
   "C-S-<tab>" 'tab-line-switch-to-prev-tab
   )

  ;; NOTE needs to be same as tab-line-tabs-function
  (
   :states '(normal visual)
   :keymaps 'override
   "g1" '(lambda () (interactive) (switch-to-buffer (nth 0 (tab-line-tabs-window-buffers))))
   "g2" '(lambda () (interactive) (switch-to-buffer (nth 1 (tab-line-tabs-window-buffers))))
   "g3" '(lambda () (interactive) (switch-to-buffer (nth 2 (tab-line-tabs-window-buffers))))
   "g4" '(lambda () (interactive) (switch-to-buffer (nth 3 (tab-line-tabs-window-buffers))))
   "g5" '(lambda () (interactive) (switch-to-buffer (nth 4 (tab-line-tabs-window-buffers))))
   "g6" '(lambda () (interactive) (switch-to-buffer (nth 5 (tab-line-tabs-window-buffers))))
   "g7" '(lambda () (interactive) (switch-to-buffer (nth 6 (tab-line-tabs-window-buffers))))
   "g8" '(lambda () (interactive) (switch-to-buffer (nth 7 (tab-line-tabs-window-buffers))))
   "g9" '(lambda () (interactive) (switch-to-buffer (nth 8 (tab-line-tabs-window-buffers))))
   )

  (
   :keymaps 'override
   "s-w" 'tab-line-close-tab-1
   )

  :hook ((fundamental-mode . tab-line-mode))
  )

;;; ------------------------------------------------------------------
;;; Customization
;;; ------------------------------------------------------------------
(defcustom zetta-tab-line-svg-font-size 15
  "Font size (px) for SVG tab-line text." :type 'integer :group 'zetta)
(defcustom zetta-tab-line-svg-line-pad 4
  "Extra vertical padding (px) per wrapped tab-line row." :type 'integer :group 'zetta)
(defcustom zetta-tab-line-svg-char-advance-ratio 0.5
  "Per-character advance, as a fraction of the font size, for tabs and rows.
Set from the bar's own font by `zetta-svg-line-derive-char-advance'; the
default only stands in before that runs.  Too high leaves whitespace inside
tab boxes; too low overlaps tabs."
  :type 'number :group 'zetta)

(define-obsolete-variable-alias 'zetta-tab-line-svg-char-advance
  'zetta-tab-line-svg-char-advance-ratio "2026-09-07")
(defcustom zetta-tab-line-svg-tab-gap 1.0
  "Gap between tabs, in character widths." :type 'number :group 'zetta)
(defcustom zetta-tab-line-svg-tab-pad 1
  "Horizontal padding INSIDE each tab, in spaces, on each side of the label.
Keeps the index number off the tab's left edge (and the name off its right),
so a per-tab background reads as a padded pill rather than text flush to the
box edges."
  :type 'integer :group 'zetta)
(defcustom zetta-tab-line-svg-pad 6
  "Pixels of inset between the tab flow and both side edges.
Only bites once the tabs wrap or overflow -- while they fit on one row
`zetta-tab-line-svg-center\=' centres them anyway."
  :type 'integer :group 'zetta)

(defcustom zetta-tab-line-svg-margin-y '(4 . 0)
  "Clear space ABOVE and BELOW the tab line's background, in pixels.
Either a number for both ends or a cons (TOP . BOTTOM).

Margin, not padding: it sits outside the background, so it separates the tab
line from its neighbours rather than enlarging it.

Zero below: the tab line sits FLUSH on the header line.  They still read
apart without a gap, because the tab line's background is inset from both
window edges (`zetta-tab-line-svg-margin\=') while the header line's runs the
full width -- the step in width does the separating.  Above is the tab bar,
spaced by its own margin."
  :type '(choice (integer :tag "Both ends")
                 (cons :tag "Uneven" (integer :tag "Top") (integer :tag "Bottom")))
  :group 'zetta)

(defcustom zetta-tab-line-svg-pad-y 0
  "Clear space INSIDE the tab line's background, above and below the pills.
Either a number for both ends or a cons (TOP . BOTTOM).

Zero while `zetta-tab-line-svg-tint\=' is off, because padding INSIDE a
background nobody paints is just dead height -- the pills have nothing to
float in, and the space reads as a taller tab line rather than as a margin
around them.  Turn the tint back on and this wants to go back to about 5:
a pill's box is drawn at the full row height, so with no padding it fills
the background exactly and the two read as one block, and raising the row
height (`zetta-tab-line-svg-line-pad\=') only makes taller pills instead of
space around them.

`zetta-tab-line-svg-margin-y\=' is the one that still does something with no
background: it is OUTSIDE the (absent) rect, so it keeps the pills clear of
the overline above them."
  :type '(choice (integer :tag "Both ends")
                 (cons :tag "Uneven" (integer :tag "Top") (integer :tag "Bottom")))
  :group 'zetta)

(defcustom zetta-tab-line-svg-overline t
  "When non-nil, draw a hairline rule along the TOP of the tab line.

The tab line is per-window, so this is a rule along the top of each WINDOW --
the horizontal partner to `zetta-window-divider-rule\=', which draws one down
the left.  Together they delineate a window on two sides without boxing it.

Drawn with the `tab-line\=' face\='s `:overline\=', not inside the SVG: an
overline is single-sided by construction and needs no engine support.  It
therefore sits at the very top of the tab line\='s area -- above the image\='s
own top margin (`zetta-tab-line-svg-margin-y\='), so there is a small gap
between the rule and the tinted background below it.  Set that margin\='s top
to 0 if you would rather the rule hugged the tint."
  :type 'boolean :group 'zetta)

(defcustom zetta-tab-line-svg-overline-strength 0.22
  "How far the tab-line overline is blended from the page toward the ink.
Matches `zetta-window-divider-rule-strength\=' so the two rules read as one
system rather than as two unrelated lines.

This is the SELECTED window's strength;
`zetta-tab-line-svg-overline-inactive-strength\=' is the other half of the
pair, and the gap between them is what marks the window you are in.

Either one number, or a cons (LIGHT . DARK) to set the two polarities
apart -- see the inactive strength, where that distinction matters."
  :type '(choice number (cons :tag "Per polarity"
                              (number :tag "Light") (number :tag "Dark")))
  :group 'zetta)

(defcustom zetta-tab-line-svg-overline-inactive-strength '(0.08 . 0.14)
  "Strength of the overline in a window that is NOT selected, or nil.

Either one number, or a cons (LIGHT . DARK).  It has to be a pair,
because the same blend is not equally visible in both polarities and the
reason is not the blend: measured in CIE L*, 0.08 moves the rule about 7
units off the page whichever way round the theme is.

What differs is the page.  `alpha-background\=' is 85 in
`default-frame-alist\=', so a sixth of the desktop shows through it, while
the rule is opaque pixels inside the SVG (which paints no background of
its own -- see `zetta-tab-line-svg-tint\=').  On a light theme that is
harmless: the page is already the brightest thing on screen and bleed
barely moves it, so the separation holds at about 6 L* over any backdrop.
On a dark theme the page you actually see is not `brushup-bg\=' at all but
`brushup-bg\=' lifted toward the wallpaper, and a rule computed 8 percent
off the nominal colour is not 8 percent off the visible one -- over a
bright backdrop the gap falls by more than half.

Hence a heavier dark default, at roughly twice the lightness step.  It
stays well under the selected window's, which is the point: the pair has
to keep saying which window you are in.  Raise the dark half further if
your wallpaper is bright, lower it toward the light value if it is dark
or if the frame is opaque.

The pair with `zetta-tab-line-svg-overline-strength\=' is what makes the
rule say which window you are in.  Held at one strength the rule
delineates every window equally and so distinguishes none of them; dimmed
here, the selected window is the one with a rule you can see, and the
prominence does the telling rather than a second colour.

nil drops the rule entirely on unselected windows, which is the strongest
version of the same idea -- worth trying if a dim rule still reads as a
boundary rather than as a lesser one.

Only the SVG-drawn rule can do this.  A face `:overline\=' is one global
attribute painted wherever the face lands, and face remapping is
buffer-local rather than window-local, so the fallback route cannot tell
two windows apart even when they show different buffers.  See
`zetta-tab-line-svg-overline\='."
  :type '(choice (const :tag "No rule when unselected" nil)
                 number
                 (cons :tag "Per polarity"
                       (number :tag "Light") (number :tag "Dark")))
  :group 'zetta)

(defun zetta-tab-line-svg--strength (value)
  "Resolve VALUE: one number for both polarities, or (LIGHT . DARK)."
  (if (consp value)
      (if (bound-and-true-p brushup-dark-p) (cdr value) (car value))
    value))

(defun zetta-tab-line-svg--rule-color ()
  "Colour for the rule in the window being rendered, or nil for none.

Evaluated per render, so `mode-line-window-selected-p\=' answers for the
window whose tab line is being drawn -- the same predicate `:active\=' uses
to pick the inactive tab palette, which is what keeps the rule and the
tabs agreeing about which window is selected."
  (and (zetta-tab-line-overline-wanted-p)
       (bound-and-true-p brushup-bg)
       (let ((strength (zetta-tab-line-svg--strength
                        (if (mode-line-window-selected-p)
                            zetta-tab-line-svg-overline-strength
                          zetta-tab-line-svg-overline-inactive-strength))))
         (and strength
              (zetta-line-blend brushup-bg brushup-fg strength)))))

(defcustom zetta-tab-line-svg-overline-height 1
  "Thickness of the tab-line overline, in pixels.
Only consulted for the SVG-drawn rule (`svg-line-rule-supported\='); the
fallback face `:overline\=' is one pixel by construction."
  :type 'integer :group 'zetta)

(defcustom zetta-tab-line-svg-overline-margin nil
  "Pixels the overline is inset from BOTH window edges, or nil.

nil insets it by `zetta-tab-line-svg-margin\=', so the rule ends exactly
where the tab line\='s background would if one were painted -- the rule and
the tint read as one strip rather than as a rule with a narrower thing
under it.  A number overrides that: 0 spans the full window (what the face
`:overline\=' did, and all it could do), larger pulls the ends in further.

Only consulted for the SVG-drawn rule; a face `:overline\=' is always the
full width of the face it is on."
  :type '(choice (const :tag "Match the tab line's margin" nil) integer)
  :group 'zetta)

(defcustom zetta-tab-line-svg-overline-files-only t
  "When non-nil, draw the overline only above a buffer visiting a FILE.

The rule delineates the window you are working in.  Above a shell, dired,
treemacs, *Messages*, an embark collect -- anything not visiting a file --
it is a boundary drawn around furniture rather than around work, so it is
suppressed there and those windows sit flush under what is above them.

`buffer-file-name\=' is the whole test, which is what \"directly associated
with a file\" means: an indirect clone answers nil and loses the rule, as
does a dired buffer that is merely POINTED at a directory.

Asked per RENDER, through `zetta-tab-line-overline-wanted-p\=', because the
rule is drawn inside the SVG (see `zetta-tab-line-svg-overline\=') and the
renderer runs with the window\='s buffer current.  So this really is per
window-showing-a-buffer, not the coarser per-buffer answer a face remap
would have given."
  :type 'boolean :group 'zetta)

(defun zetta-tab-line-overline-wanted-p ()
  "Non-nil when the current buffer should carry the rule.

The one predicate both routes ask.  It is evaluated per RENDER now that
the rule is drawn inside the SVG (`:rule\=' below), which is what makes a
per-buffer answer possible without remapping anything: the renderer runs
with the window\='s buffer current, so the rule simply is not drawn for a
buffer that should not have one.

\(An earlier version suppressed the FACE `:overline\=' with a buffer-local
remap and a set of hooks.  That machinery is gone: it has no effect on a
rule the SVG draws, and it was only ever needed because a face attribute
cannot be decided per render.)"
  (and zetta-tab-line-svg-overline
       (or (not zetta-tab-line-svg-overline-files-only)
           (buffer-file-name))))

(defcustom zetta-tab-line-svg-tint 0
  "How far the tab line's background is blended from the page toward the ink.
0 (or nil) paints NO background at all -- not a rect in the page colour,
which is a different thing: the frame is translucent, so an opaque rect in
`brushup-bg\=' shows as a solid block over the backdrop rather than
disappearing.  1.0 would make it the foreground colour.

Off by default -- `zetta-tab-line-svg-overline\=' does the delineating on its
own.  If you turn it back on, blend rather than taking a rung off the
`brushup-bg-N\=' ladder: the first rung is spoken for by
`zetta-tab-line-svg-inactive-tab-background\=', and a bar painted that same
value swallows the pills it sits behind.  Keep it below that rung -- and note
the pill ladder in `zetta-svg-line-apply-brushup-palette\=' was measured
against a TRANSPARENT bar, so a tint wants those pills a rung higher again."
  :type 'number :group 'zetta)

(defcustom zetta-tab-line-svg-margin 60
  "Pixels the tab line's background is inset from BOTH window edges.
Margin, not padding: it narrows the painted background itself, so the tab
line reads as a distinctly narrower strip than the full-width header line
below it.  The tabs are centred within what is left."
  :type 'integer :group 'zetta)

(defcustom zetta-tab-line-svg-max-name 30
  "Truncate an individual tab name to this many characters (then …)."
  :type 'integer :group 'zetta)
(defcustom zetta-tab-line-svg-center t
  "When non-nil, centre the tabs while they all fit on one row.
Once there are enough tabs to wrap onto a second row they revert to the
normal flush-left flow."
  :type 'boolean :group 'zetta)

;;; Palette.  The tab-line strip itself is TRANSPARENT: nothing is painted
;;; behind the tabs, so the `tab-line' face background (which brushup paints
;;; to the buffer background) shows through and all that is visible is the
;;; floating tab pills.  With no bar to carry it, the active/inactive
;;; distinction rests entirely on those pills -- see the inactive palette
;;; further down, which steps every element down the same ladder so no
;;; unfocused element is ever more present than its focused counterpart.
(defcustom zetta-tab-line-svg-background nil
  "Background strip painted behind the SVG tab line (selected window).
nil -- the default -- paints nothing: the tab line is transparent and only
the tab pills float on the buffer background.  Set a colour to get a solid
bar back.  Overridden at runtime from the theme by
`zetta-svg-line-apply-brushup-palette'."
  :type '(choice (const :tag "Transparent" nil) color) :group 'zetta)

(defcustom zetta-tab-line-svg-foreground "#4f4f4f"
  "Foreground for ordinary (non-current) tab labels in the SELECTED window.
Dark enough to read against `zetta-tab-line-svg-tab-background' -- with no
bar behind the tabs the label contrast is doing work the bar used to do.
Overridden at runtime from the theme."
  :type 'color :group 'zetta)

(defcustom zetta-tab-line-svg-current-background "#2f2f2f"
  "Pill drawn behind the current (active) tab.  nil = none.
This is the loudest thing the tab line says: on a transparent strip an
INVERTED pill (near-foreground, not merely a tint) is what marks the
focused window at a glance."
  :type '(choice (const :tag "None" nil) color) :group 'zetta)

(defcustom zetta-tab-line-svg-current-foreground "#ffffff"
  "Foreground for the current tab's label (light, to read on the dark pill)."
  :type 'color :group 'zetta)

(defcustom zetta-tab-line-svg-tab-background "#dcdcdc"
  "Pill drawn behind each ordinary (non-current) tab in the SELECTED window.
A soft chip that lifts the tab off the buffer background without competing
with the inverted current-tab pill.  nil = transparent."
  :type '(choice (const :tag "Transparent" nil) color) :group 'zetta)

(defcustom zetta-tab-line-svg-modified-foreground "#c1641e"
  "Foreground for a tab whose buffer has unsaved changes.
A warm amber that stands out from the neutral tab text without shouting,
echoing the built-in `tab-line-tab-modified' distinction.  Replaced at
runtime by the theme\='s own warning colour when that reads on the tab pill."
  :type 'color :group 'zetta)

(defcustom zetta-tab-line-svg-modified-background "#dcdcdc"
  "Pill drawn behind a modified (but not current) tab.  nil = transparent.
Must match `zetta-tab-line-svg-tab-background\=': the engine draws EITHER the
modified pill or the ordinary one, never both, so leaving this nil punches a
hole in the row -- a modified tab floating pill-less between two pilled
neighbours.  That went unnoticed while the strip had a background of its own."
  :type '(choice (const :tag "Transparent" nil) color) :group 'zetta)

(defcustom zetta-tab-line-svg-modified-marker ""
  "Marker appended to a modified tab's label (in addition to the colour).
Empty by default -- the modified colour alone marks unsaved tabs."
  :type 'string :group 'zetta)

;;; Inactive palette -- used when the tab line's window is NOT selected,
;;; the way the mode line dims in unfocused windows.  Each falls back to
;;; its active counterpart when nil, so a value is given for every element
;;; that has to differ (nil would inherit the ACTIVE colour, not clear it).
(defcustom zetta-tab-line-svg-inactive-background nil
  "Background strip in NON-selected windows.  nil = transparent (the default).
Left transparent for the same reason as `zetta-tab-line-svg-background':
the unfocused window is distinguished by its pills, not by its bar."
  :type '(choice (const :tag "Transparent" nil) color) :group 'zetta)

(defcustom zetta-tab-line-svg-inactive-foreground "#7e7e7e"
  "Foreground for ordinary tabs in NON-selected windows.
Legible, but a clear step down from `zetta-tab-line-svg-foreground'."
  :type 'color :group 'zetta)

(defcustom zetta-tab-line-svg-inactive-current-background "#cacaca"
  "Pill behind the current tab in NON-selected windows.
A mid grey rather than the focused window's inverted pill -- you can still
see which buffer each window is showing, but only one window shouts."
  :type '(choice (const :tag "None" nil) color) :group 'zetta)

(defcustom zetta-tab-line-svg-inactive-tab-background "#eeeeee"
  "Pill behind ordinary tabs in NON-selected windows.
Barely there -- one step off the buffer background, just enough to keep the
tabs delineated."
  :type '(choice (const :tag "Transparent" nil) color) :group 'zetta)

(defcustom zetta-tab-line-svg-inactive-current-foreground "#3f3f3f"
  "Current tab's label colour in NON-selected windows.
Readable on `zetta-tab-line-svg-inactive-current-background', muted so the
unfocused current tab does not read as loudly as the focused one."
  :type 'color :group 'zetta)

(defcustom zetta-tab-line-svg-inactive-modified-foreground "#d8a06a"
  "Modified tab's label colour in NON-selected windows (dimmed amber)."
  :type 'color :group 'zetta)

(defcustom zetta-tab-line-svg-inactive-modified-background "#eeeeee"
  "Pill behind a modified (but not current) tab in NON-selected windows.
Matches `zetta-tab-line-svg-inactive-tab-background\=', for the reason given
at `zetta-tab-line-svg-modified-background\='."
  :type '(choice (const :tag "Transparent" nil) color) :group 'zetta)


;;; ------------------------------------------------------------------
;;; Content -- a list of (LABEL . STATE) for the `wrap' layout, where
;;; STATE is a plist of `:current' / `:modified' flags.
;;; ------------------------------------------------------------------
(defun zetta-tab-line-svg--ace-lead ()
  "This window\'s ace-window key, for the tab line\'s left margin, or nil.

Only while `zetta-line-window-picking-p\' -- the key is a prompt, and a
prompt that is always on screen is not a prompt.

Drawn by the engine in the margin rather than handed back as a leading TAB,
which is what it was first: a tab takes a slot in the flow, and a slot that
appears the moment you press the pick key shoves every tab sideways just as
you are reading them.  The margin is empty anyway (`zetta-tab-line-svg-margin\'
insets the flow by 60px), so the indicator costs no layout at all.

The tab line is the right bar for this now that every buffer has one (see
`zetta-tab-line-name-space-ok\') and not every buffer has a mode line --
which is where this badge used to live, and why it could not be relied on."
  (when (and (fboundp 'zetta-line-window-picking-p)
             (zetta-line-window-picking-p))
    (let ((path (window-parameter (selected-window) 'ace-window-path))
          (pad (make-string (max 0 zetta-tab-line-svg-tab-pad) ?\s)))
      (and path (> (length path) 0)
           (concat pad (substring-no-properties path) pad)))))

(defun zetta-tab-line-svg-tabs ()
  "Return a list of (LABEL . STATE) for the window's tab-line tabs.
LABEL is \"N GLYPH name\" -- the 1-based index (matching g1..g9), a
nerd-font file-type glyph, and the buffer name, with
`zetta-tab-line-svg-modified-marker' appended when the buffer has unsaved
changes.  STATE is a plist: `:current' marks the tab for the buffer shown
in this window; `:modified' marks a file-visiting buffer with changes.
Because the glyph is part of the label text it needs no separate icon."
  (let ((tabs (ignore-errors (funcall tab-line-tabs-function)))
        (cur  (current-buffer)))
    (cl-loop for buf in tabs
             for i from 1
             for real = (if (bufferp buf) buf cur)
             for name = (buffer-name real)
             for currentp = (eq buf cur)
             for modifiedp = (and (buffer-live-p real)
                                  (buffer-modified-p real)
                                  (buffer-file-name real)
                                  t)
             for glyph = (zetta-line-buffer-glyph real)
             for short = (if (> (length name) zetta-tab-line-svg-max-name)
                             (concat (substring name 0 (1- zetta-tab-line-svg-max-name)) "…")
                           name)
             ;; capture the buffer in a fresh binding -- cl-loop reuses one
             ;; binding for `real', so action/menu closures must not close over
             ;; it directly (they would all see the last tab's buffer).
             collect (let ((b real) (nm name)
                           (pad (make-string (max 0 zetta-tab-line-svg-tab-pad) ?\s)))
                       (cons (concat pad
                                     (or (ct/circle-number i) (format "%d" i))
                                     (if glyph (concat glyph " ") " ")
                                     short
                                     (if modifiedp zetta-tab-line-svg-modified-marker "")
                                     pad)
                             (list :current currentp :modified modifiedp
                                   :id b
                                   :help (format "buffer: %s" nm)
                                   :action-help "switch to this buffer"
                                   :action (lambda () (interactive)
                                             (when (buffer-live-p b) (switch-to-buffer b)))
                                   :menu
                                   (delq nil
                                         (list (cons "Switch to buffer"
                                                     (lambda () (interactive)
                                                       (when (buffer-live-p b) (switch-to-buffer b))))
                                               (and (buffer-file-name b)
                                                    (cons "Save buffer"
                                                          (lambda () (interactive)
                                                            (when (buffer-live-p b)
                                                              (with-current-buffer b (save-buffer))))))
                                               (cons "Kill buffer"
                                                     (lambda () (interactive)
                                                       (when (buffer-live-p b) (kill-buffer b))))
                                               (cons "Copy buffer name"
                                                     (lambda () (interactive)
                                                       (kill-new (buffer-name b))))))))))))

(svg-line-define 'zetta-tab-line
  :target 'tab-line
  :layout 'wrap
  :width 'window
  :content #'zetta-tab-line-svg-tabs
  ;; dim the whole tab line when its window is not the selected one,
  ;; the same way the SVG mode line distinguishes active/inactive.
  :active #'mode-line-window-selected-p
  :font (lambda () (zetta-svg-line-font-for :tab-line))
  :font-size (lambda () zetta-tab-line-svg-font-size)
  :line-pad (lambda () zetta-tab-line-svg-line-pad)
  :char-advance-ratio (lambda () zetta-tab-line-svg-char-advance-ratio)
  :gap (lambda () zetta-tab-line-svg-tab-gap)
  :pad (lambda () zetta-tab-line-svg-pad)
  :pad-y (lambda () zetta-tab-line-svg-pad-y)
  :margin (lambda () zetta-tab-line-svg-margin)
  :margin-y (lambda () zetta-tab-line-svg-margin-y)
  :center (lambda () zetta-tab-line-svg-center)
  ;; The rule along the top of the window.  A function, so the colour is
  ;; recomputed from the palette at render time and follows a theme change
  ;; with no brushup entry of its own.
  :rule #'zetta-tab-line-svg--rule-color
  :rule-height (lambda () zetta-tab-line-svg-overline-height)
  :rule-margin (lambda () zetta-tab-line-svg-overline-margin)
  ;; the window-picking key, in the left margin the tab flow never uses
  :lead (lambda () (zetta-tab-line-svg--ace-lead))
  :background (lambda () zetta-tab-line-svg-background)
  :foreground (lambda () (or zetta-tab-line-svg-foreground
                             (face-foreground 'shadow nil t) "#888888"))
  :current-foreground (lambda () zetta-tab-line-svg-current-foreground)
  :current-background (lambda () zetta-tab-line-svg-current-background)
  :tab-background (lambda () zetta-tab-line-svg-tab-background)
  :modified-foreground (lambda () zetta-tab-line-svg-modified-foreground)
  :modified-background (lambda () zetta-tab-line-svg-modified-background)
  ;; inactive (unfocused-window) palette
  :inactive-background (lambda () zetta-tab-line-svg-inactive-background)
  :inactive-foreground (lambda () zetta-tab-line-svg-inactive-foreground)
  :inactive-current-foreground (lambda () zetta-tab-line-svg-inactive-current-foreground)
  :inactive-current-background (lambda () zetta-tab-line-svg-inactive-current-background)
  :inactive-tab-background (lambda () zetta-tab-line-svg-inactive-tab-background)
  :inactive-modified-foreground (lambda () zetta-tab-line-svg-inactive-modified-foreground)
  :inactive-modified-background (lambda () zetta-tab-line-svg-inactive-modified-background))

;;; ------------------------------------------------------------------
;;; Switching.  svg-line installs the tab line by advising the
;;; `tab-line-format' FUNCTION (so it catches buffers whose
;;; `tab-line-format' variable is buffer-local), and removes the advice
;;; on deactivate.
;;; ------------------------------------------------------------------
(defun zetta-tab-line-using-svg-p ()
  "Non-nil if the wrapping SVG tab line is currently active."
  (svg-line-active-p 'zetta-tab-line))

;; svg-line delivers mouse enter/leave only through the help-echo machinery,
;; so its hover highlight needs a `show-help-function' hook feeding
;; `svg-line--note-help'.  (svg-margin owns the same wiring for the margin via
;; `svg-margin-hover-mode'; this is svg-line's half, kept here so the svg-margin
;; module stays free of any svg-line reference.)  The wrapper chains the prior
;; `show-help-function', so it composes with svg-margin's.
(declare-function svg-line--note-help "svg-line")
(defvar zetta-svg-line--prev-show-help nil
  "The `show-help-function' in effect before svg-line's hover wrapper.")
(defun zetta-svg-line--show-help (help)
  "Feed HELP to svg-line's hover tracker, then display it as before."
  (when (fboundp 'svg-line--note-help) (svg-line--note-help help))
  (when (functionp zetta-svg-line--prev-show-help)
    (funcall zetta-svg-line--prev-show-help help)))
(defun zetta-svg-line--enable-hover ()
  "Turn on svg-line's hover highlight and install its show-help wrapper."
  (setq svg-line-hover-highlight t)
  (unless (eq show-help-function #'zetta-svg-line--show-help)
    (setq zetta-svg-line--prev-show-help show-help-function
          show-help-function #'zetta-svg-line--show-help)))

;;;###autoload
(defun zetta-tab-line-use-svg ()
  "Switch the tab line to the wrapping SVG renderer."
  (interactive)
  (zetta-svg-line--enable-hover)      ; highlight the tab/item under the mouse
  (svg-line-activate 'zetta-tab-line)
  (message "tab-line: wrapping SVG renderer active (M-x zetta-tab-line-use-default to revert)"))

;;;###autoload
(defun zetta-tab-line-use-default ()
  "Restore the built-in tab line."
  (interactive)
  (svg-line-deactivate 'zetta-tab-line)
  (message "tab-line: built-in renderer active"))

;;;###autoload
(defun zetta-tab-line-toggle ()
  "Toggle between the SVG and built-in tab line."
  (interactive)
  (if (zetta-tab-line-using-svg-p)
      (zetta-tab-line-use-default)
    (zetta-tab-line-use-svg)))

;;; ------------------------------------------------------------------
;;; Startup default (opt-out).  The tab line is per-window and installs
;;; by advising `tab-line-format', so it is safe to activate from the
;;; startup hook (sets up advice only; no rendering at hook time).
;;; ------------------------------------------------------------------
(defcustom zetta-tab-line-svg-default t
  "When non-nil, activate the wrapping SVG tab line at startup.
Set to nil (and restart) to keep the built-in tab line; either way you
can switch at runtime with `zetta-tab-line-toggle'."
  :type 'boolean :group 'zetta)

(when zetta-tab-line-svg-default
  (add-hook 'emacs-startup-hook #'zetta-tab-line-use-svg))

(provide 'tab-line-svg)
;;; tab-line-svg.el ends here
