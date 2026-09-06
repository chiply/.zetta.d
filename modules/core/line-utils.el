;;; line-utils.el --- Configure line utilities -*- lexical-binding: t; -*-

;; `zetta-hue-wash' works in HSL; nothing else here pulls color.el in.
(require 'color)

;;;;;; Utils
(defvar ml-selected-window nil)

(defun ml-record-selected-window ()
  (setq ml-selected-window (selected-window)))

(defun ml-update-all ()
  (force-mode-line-update t))

(add-hook 'post-command-hook 'ml-record-selected-window)
(add-hook 'buffer-list-update-hook 'ml-update-all)

;;;; functions for generating icons
(defun zetta-line-iedit-icon ()
  (when (and (boundp 'iedit-mode) iedit-mode)
    (all-the-icons-material
     "find_replace"
     :face 'mode-line )))

(defun zetta-line-github-icon ()
  (when vc-mode
    (all-the-icons-faicon
     "github"
     :face 'mode-line )))

(defun zetta-line-modified-icon ()
  (when (buffer-modified-p)
    (all-the-icons-material
     "change_history"
     :face 'mode-line
     )))

(defun zetta-line-tramp-icon ()
  (when (and (fboundp '4mn-get-tramp-hop-types)
             (member "ssh" (4mn-get-tramp-hop-types)))
    (all-the-icons-faicon "server"
                          :face 'mode-line)))

(defun zetta-line-docker-icon ()
  (when (and (fboundp '4mn-get-tramp-hop-types)
             (member "docker" (4mn-get-tramp-hop-types)))
    (all-the-icons-fileicon
     "dockerfile"
     :face 'mode-line)))

(defun zetta-line-hydra-indicator-icon ()
  (if (and
       ;; hydra loaded
       (boundp 'hydra-curr-map)
       ;; head active
       hydra-curr-map
       ;; on selected window
       (eq ml-selected-window (selected-window)))
      (all-the-icons-material
       "flare"

       ;; make invisible in other buffers
       :face 'mode-line
       )
    nil))

(defun zetta-line-narrowed-icon ()
  (when (buffer-narrowed-p) "N"))

;; Repo/branch render inside mode-line :eval forms (treemacs,
;; telephone-line), so they run on every redisplay of those windows and
;; must never fork a shell there: two `git rev-parse' subprocesses per
;; window per redisplay block the main loop long enough to starve timers
;; (async consult/irs results stall until a keypress).  Cache per
;; directory instead; a branch switch shows up within `zetta-git-info-ttl'.
(defvar zetta-git-info-ttl 10
  "Seconds a cached repo/branch answer stays fresh.")
(defvar zetta--git-info-cache (make-hash-table :test 'equal)
  "Maps `default-directory' to (TIME REPO-NAME BRANCH-NAME).")

(defun zetta--git-info ()
  "Return (REPO-NAME BRANCH-NAME) for `default-directory', cached briefly.
REPO-NAME is a one-element list, as `zetta-get-repo-name' has always
returned; BRANCH-NAME is a string."
  (let ((hit (gethash default-directory zetta--git-info-cache))
        (now (float-time)))
    (if (and hit (< (- now (car hit)) zetta-git-info-ttl))
        (cdr hit)
      (cdr (puthash
            default-directory
            (list now
                  (last (split-string
                         (nth 0 (split-string
                                 (shell-command-to-string
                                  "git rev-parse --show-toplevel")
                                 "\n"))
                         "/"))
                  (nth 0 (split-string
                          (shell-command-to-string
                           "git rev-parse --abbrev-ref HEAD")
                          "\n")))
            zetta--git-info-cache)))))

(defun zetta-get-repo-name ()
  (nth 0 (zetta--git-info)))

(defun zetta-get-branch-name ()
  (nth 1 (zetta--git-info)))

(defun zetta-line-col ()
  (let ((col-length (length (int-to-string (current-column)))))
    (cond
     ((eq col-length 1) "%c%2 ")
     ((eq col-length 2) "%c%1 ")
     ((eq col-length 3) "%c")
     )
    )
  )

;;;; Indicators (segment functions, moved from the -svg config modules)
;; ----------------------------------------------------------------
;; Atomic display segments.  The -svg config modules in :ui bind these
;; into lines (they only compose, not define).  line-utils.el (:core)
;; loads before those :ui consumers, so the functions are defined first.

;; Interactive (clickable/hover/menu) segments are built with the svg-line
;; engine's `svg-line-seg'; `zetta-svg-seg' wraps it to give every segment a
;; per-window-unique id (so only the hovered window's copy of an indicator
;; highlights) and to no-op gracefully when the engine isn't loaded.
(declare-function svg-line-seg "svg-line")
(declare-function svg-line-segs "svg-line")
(declare-function svg-line-map-string-regions "svg-line")

(defun zetta-svg-seg (text key &rest plist)
  "Return an interactive svg-line segment for TEXT, keyed by KEY.
The hover/identity id is (KEY . current-buffer) so a per-window bar only
highlights the indicator in the window under the mouse.  PLIST passes through
\(`:help' `:action' `:action-help' `:menu' `:color'/`:face').  Returns nil when
TEXT is empty or the engine is unavailable, so the segment then contributes
nothing."
  (when (and text (fboundp 'svg-line-seg)
             (> (length (format-mode-line text)) 0))
    (apply #'svg-line-seg text :id (cons key (current-buffer)) plist)))

(defun zetta-svg--crumb-target (str pos text)
  "Return a buffer position/marker the crumb at POS (text TEXT) in STR points to.
Reads the target breadcrumb already stashed on the crumb: `breadcrumb-region'
or `org-imenu-marker' on the crumb itself, else the crumb's entry in the
`breadcrumb-siblings' alist (matched by TEXT).  Returns nil when no target is
discoverable (e.g. lsp crumbs, whose own handler we keep instead)."
  (let ((reg  (get-text-property pos 'breadcrumb-region str))
        (om   (get-text-property pos 'org-imenu-marker str))
        (sibs (get-text-property pos 'breadcrumb-siblings str)))
    (cond
     ((consp reg) (car reg))                       ; (start . end) -> start
     ((markerp om) om)
     ((and (listp sibs) text)
      (let ((hit (assoc text (mapcar (lambda (e)
                                       (cons (and (stringp (car-safe e))
                                                  (substring-no-properties (car e)))
                                             (cdr-safe e)))
                                     sibs))))
        (let ((tgt (cdr hit)))
          (cond ((markerp tgt) tgt)
                ((numberp tgt) tgt)
                ((overlayp tgt) (overlay-start tgt)))))))))

(defun zetta-svg--crumb-jump (target)
  "Return an interactive command that navigates to TARGET (a marker or position).
Selects TARGET's window/buffer, pushes the mark, moves point and reveals it
\(unfolding in org), so a crumb click goes straight there -- no completing-read."
  (lambda ()
    (interactive)
    (let* ((m (if (markerp target) target nil))
           (buf (if m (marker-buffer m) (current-buffer)))
           (pos (if m (marker-position m) target)))
      (when (and buf pos (buffer-live-p buf))
        (let ((win (get-buffer-window buf)))
          (if win (select-window win)
            (pop-to-buffer buf)))
        (push-mark)
        (goto-char pos)
        (cond ((derived-mode-p 'org-mode)
               (ignore-errors (org-fold-show-context))
               (ignore-errors (org-fold-show-entry)))
              ((bound-and-true-p outline-minor-mode)
               (ignore-errors (outline-show-entry))))
        (recenter)))))

(defun zetta-svg-segs-from-propertized (str id-key)
  "Split propertized STR into an svg-line `:svg-segs' group of clickable crumbs.
Builds on `svg-line-map-string-regions' (the package's region splitter +
mouse-1 handler extractor): each region carrying a mouse-1 keymap becomes an
interactive segment, regions without one stay plain text.  For a crumb whose own
text properties name a target (org/imenu markers, `breadcrumb-region'/`-siblings')
we jump there DIRECTLY -- bypassing `breadcrumb-jump''s `completing-read' -- else
we fall back to the crumb's own handler (e.g. lsp-headerline's, already direct).
Only a left-click action: these handlers take (interactive \"e\") and read the
invoking mouse event, which a real header-line click supplies.  ID-KEY (with the
buffer, for per-window hover) namespaces the per-crumb hover ids.  Returns nil
for empty STR."
  (when (and (stringp str) (fboundp 'svg-line-map-string-regions) (> (length str) 0))
    (let ((idx 0) (buf (current-buffer)))
      (apply #'svg-line-segs
             (svg-line-map-string-regions
              str
              (lambda (text start handler help)
                (let* ((target (and handler (zetta-svg--crumb-target str start text)))
                       (act (cond (target (zetta-svg--crumb-jump target))
                                  (handler handler))))
                  (if (and act (> (length (string-trim text)) 0))
                      (progn
                        (setq idx (1+ idx))
                        (svg-line-seg
                         text
                         :id (list id-key buf idx)
                         ;; clean help -- for a direct jump use the crumb text;
                         ;; else the handler's own first help line (properties
                         ;; stripped, since breadcrumb stuffs its sibling tree there)
                         :help (if target
                                   (concat "go to " (string-trim text))
                                 (if (stringp help)
                                     (substring-no-properties
                                      (car (split-string help "\n")))
                                   (format "%s" (string-trim text))))
                         :action-help (if target "jump" "open")
                         :action act))
                    text))))))))

;;; tab-bar / status segments
(defun zetta-buffer-name ()
  (let ((name (if (buffer-file-name)
                  (abbreviate-file-name (buffer-file-name))
                (buffer-name))))
    (if (> (length name) 70)
        (concat (substring name 0 67) "…")
      name)))

(defun zmc-modeline-indicator ()
  (concat
   (when (boundp 'local-transient) local-transient)
   " "))

(defun zetta-pyvenv-activate-poetry-modeline ()
  ;; pyvenv activation is process-global (and must stay active while
  ;; project buffers need lsp/dap), but display it only in buffers
  ;; living under the venv's project — showing it in an unrelated org
  ;; buffer reads as a lie about context.  Assumes in-project .venv
  ;; layout (the uv convention used everywhere here).
  (when-let* ((venv (bound-and-true-p pyvenv-virtual-env))
              (venv (directory-file-name venv))
              (root (file-name-directory venv)))
    (when (string-prefix-p (expand-file-name root)
                           (expand-file-name default-directory))
      (concat "{venv:"
              (zetta-minify-path venv)
              "/"
              (car (last (split-string venv "/")))
              "}"))))

(defun zetta-tab-bar-spot-mode-line-string ()
  (if (fboundp 'spot-mode-line-string)
      (spot-mode-line-string)
    "*"))

(defun zetta-tab-bar-modal ()
  "The active modal SYSTEM (evil / meow / emacs)."
  (or
   (when (and (boundp 'evil-mode) evil-mode) "evil")
   (when (and (boundp 'meow-mode) meow-mode) "meow")
   (when (not (or (and (boundp 'evil-mode) evil-mode)
                  (and (boundp 'meow-mode) meow-mode)))
     "emacs")))

(defun zetta-line-modal-state ()
  "The current modal STATE (e.g. normal, insert, visual) as a string.
Works for evil and meow; \"emacs\" when neither is editing this buffer."
  (cond
   ((bound-and-true-p evil-state) (symbol-name evil-state))
   ((and (bound-and-true-p meow-mode) (fboundp 'meow--current-state)
         (meow--current-state))
    (symbol-name (meow--current-state)))
   (t "emacs")))

(defun zetta-gptel-processes ()
  (when (boundp 'gptel--request-alist)
    (let ((num-processes (length gptel--request-alist)))
      (if (> num-processes 0)
          (format " ai:%d " num-processes)
        ""))))

(defun tab-bar-keycast ()
  (let ((str (keycast--format keycast-mode-line-format)))
    (when str
      (set-text-properties 0 (length str) nil str))
    `((keycast menu-item ,(or str "") ignore))))

(defun zetta-tab-bar-current-thing ()
  "Tab-bar item: shows the effective treesit-tap thing at point.
Uses the accessor `treesit-tap--current-thing' rather than the raw
buffer-local `treesit-tap-current-thing', so it is always visible:
it falls back to `treesit-tap-default-thing' (e.g. [defun]) in buffers
where no local thing has been set via `treesit-tap-set-local'."
  (when (fboundp 'treesit-tap--current-thing)
    (format "[%s] " (treesit-tap--current-thing))))

(defun zetta-tab-bar-recursion-level ()
  (let ((recursion-level (minibuffer-depth)))
    (if (zerop recursion-level)
        "[R:0] "
      (format " [R:%d] " recursion-level))))

(defun zetta-tab-bar-svg--keycast ()
  "Keycast string with a caps-keyboard glyph sitting next to the keys.
Keycast right-pads the keys (`keycast-mode-line-format' is \"%10s...\"), so trim
that leading whitespace before prefixing the glyph -- otherwise the glyph ends
up far to the left of the actual key/command.  Returns nil when idle."
  (let ((str (string-trim-left (or (nth 2 (car (tab-bar-keycast))) ""))))
    (when (> (length str) 0)
      (let ((icon (and (featurep 'nerd-icons)
                       (zetta-line--glyph (ignore-errors (nerd-icons-mdicon "nf-md-keyboard_caps"))))))
        (concat (and icon (concat icon " ")) str)))))

(defun zetta-tab-bar-recursion-icon ()
  "Type-hierarchy glyph shown to the left of the recursion-depth indicator."
  (and (featurep 'nerd-icons)
       (zetta-line--glyph (ignore-errors (nerd-icons-codicon "nf-cod-type_hierarchy_sub")))))

(defun zetta-current-prefix ()
  (let ((descr (key-description
                (or
                 (and
                  (boundp 'my-this-command-keys-vector)
                  my-this-command-keys-vector)
                 (this-command-keys-vector)))))
    (if (string-match-p "mouse" descr)
        ""
      descr)))

;; otherwise prefix keys won't show up
(add-hook 'prefix-command-echo-keystrokes-functions 'force-mode-line-update)


;;; ------------------------------------------------------------------
;;; Theme-derived colours for the SVG lines
;;; ------------------------------------------------------------------
;; The segments below used to carry hardcoded hexes -- a green insert pill, a
;; blue ace badge, a purple space marker.  Those were picked against one light
;; theme and look wrong everywhere else.
;;
;; brushup supplies foreground/background gradients but no HUES, so semantic
;; colour has to come from the theme's own faces.  Every theme defines `error',
;; `warning', `success', `link' and the diff faces, which is exactly the
;; vocabulary these indicators need.

(defvar zetta-theme-color-fallbacks
  '((error . "#d75f5f") (warning . "#d7af5f") (success . "#87af5f")
    (accent . "#5f87d7") (added . "#87af5f") (removed . "#d75f5f")
    (changed . "#d7af5f"))
  "Last-resort colours when the theme defines none of the candidate faces.")

(defun zetta-theme-color (kind)
  "A colour for KIND taken from the current theme.
KIND is one of error, warning, success, accent, added, removed, changed."
  (let ((faces (pcase kind
                 ('error   '(error compilation-error))
                 ('warning '(warning compilation-warning))
                 ('success '(success compilation-info))
                 ('accent  '(link font-lock-keyword-face))
                 ('added   '(diff-added magit-diff-added-highlight success))
                 ('removed '(diff-removed magit-diff-removed-highlight error))
                 ('changed '(diff-changed warning))
                 (_        '(default)))))
    (or (seq-some (lambda (f)
                    (and (facep f)
                         (let ((c (face-foreground f nil t)))
                           (and (stringp c) (color-name-to-rgb c) c))))
                  faces)
        (alist-get kind zetta-theme-color-fallbacks))))

(defun zetta-color--luminance (color)
  "WCAG relative luminance of COLOR, or nil."
  (when-let* ((rgb (color-name-to-rgb color)))
    (apply #'+ (cl-mapcar #'*
                          '(0.2126 0.7152 0.0722)
                          (mapcar (lambda (c)
                                    (if (<= c 0.03928) (/ c 12.92)
                                      (expt (/ (+ c 0.055) 1.055) 2.4)))
                                  rgb)))))

(defun zetta-contrast-ratio (a b)
  "WCAG contrast ratio between colours A and B."
  (let ((la (+ 0.05 (or (zetta-color--luminance a) 0)))
        (lb (+ 0.05 (or (zetta-color--luminance b) 0))))
    (/ (max la lb) (min la lb))))

(defcustom zetta-readable-on-threshold 7.0
  "Contrast ratio at which a theme colour is preferred over pure black/white.
`zetta-readable-on' hands back the theme\='s own ink whenever it clears this,
and only reaches for absolute black or white when neither does."
  :type 'number :group 'zetta)

(defun zetta-readable-on (bg)
  "Return whichever theme colour reads best on BG.

Picks by measured contrast rather than by a luminance threshold.  A
threshold works at the extremes and fails in the middle: a mid-tone pill
would be handed the light foreground on the strength of being \"dark\",
landing at 2:1.

Among the colours that DO read, the theme\='s own foreground/background win
over absolute black/white: maximum contrast alone picks #000000 over a
theme ink of #202020 on the strength of half a ratio point, and pure black
label text on a chip next to #202020 buffer text is a visible mismatch.
Falls back to plain white or black when no theme colour clears
`zetta-readable-on-threshold\='."
  (let* ((fg (or (bound-and-true-p brushup-fg) (face-foreground 'default nil t) "#ffffff"))
         (bgc (or (bound-and-true-p brushup-bg) (face-background 'default nil t) "#000000")))
    (or (car (sort (seq-filter (lambda (c) (>= (zetta-contrast-ratio c bg)
                                               zetta-readable-on-threshold))
                               (list fg bgc))
                   (lambda (x y) (> (zetta-contrast-ratio x bg)
                                    (zetta-contrast-ratio y bg)))))
        (car (sort (list fg bgc "#ffffff" "#000000")
                   (lambda (x y) (> (zetta-contrast-ratio x bg)
                                    (zetta-contrast-ratio y bg))))))))

;;; ------------------------------------------------------------------
;;; VC gutter marker colours
;;; ------------------------------------------------------------------
;; The gutter used to take its three hues from `zetta-theme-color\='s diff
;; kinds, which is the red/green/yellow stoplight every diff tool uses.
;; That convention earns its keep in a diff BUFFER, where red and green
;; are the content; in a two-pixel margin bar there is no diff to read,
;; only "which of the three is this", and the stoplight drags three
;; colours from outside the theme\='s palette down the edge of every window.
;;
;; So the markers separate by LIGHTNESS instead: three rungs of the
;; brushup ink ladder, the same ladder `zetta-line-chip-ladder\=' uses to
;; make a badge loud or quiet without giving it a hue.  Borrowing three
;; separable colours from the theme\='s syntax palette was the obvious
;; alternative and was tried; it works on a hue-diverse theme and has
;; nothing to offer a deliberately monochrome one (doric-obsidian paints
;; its whole font-lock palette in four greys) or a blue-heavy one, so the
;; gutter would have changed strategy -- not just shade -- from theme to
;; theme.  Lightness is an axis every theme has.
;;
;; Magit keeps the stoplight (see modules/tools/magit.el): there the
;; colours are the content.

(defvar zetta-vc-marker-ladder
  '((added . brushup-fg) (removed . brushup-fg-3) (modified . brushup-fg-6))
  "Ink-ladder rungs for the VC gutter markers, as kind to brushup variable.

`removed\=' takes the middle rung rather than an end.  It is the one marker
already distinguished by shape -- a triangle, where the other two are bars
\(see `zetta-svg-margin-git-gutter\=') -- so it can afford the smaller gaps
and leave the ladder\='s full span to the pair a reader has to tell apart on
colour alone.")

(defun zetta-vc-marker-color (kind)
  "Colour for VC marker KIND (`added\=', `modified\=' or `removed\=').
See `zetta-vc-marker-ladder\='.  Falls back to `zetta-theme-color-fallbacks\='
only if brushup has not defined its gradient yet."
  (let ((rung (alist-get kind zetta-vc-marker-ladder)))
    (or (and rung (boundp rung) (symbol-value rung))
        (alist-get (if (eq kind 'modified) 'changed kind)
                   zetta-theme-color-fallbacks))))

;;; ------------------------------------------------------------------
;;; Hue washes
;;; ------------------------------------------------------------------
;; For anything painting a theme colour BEHIND text that has to stay
;; readable through it: the org-remark pens, the log highlighters in
;; modules/core/utility.el.

(defun zetta-hue-wash (hue anchor sat)
  "HUE re-lit to weigh the same against the page as ANCHOR does.

Hue and saturation come from HUE, saturation clamped into SAT (a
`(min . max)\=' pair).  Lightness is searched for rather than taken from
HUE, so the result lands on ANCHOR\='s relative luminance -- ANCHOR being a
step of the brushup gradient, which is already the theme\='s own answer to
\"how far off the page is a faint wash\".

Matching luminance rather than HSL lightness is the whole point.  A shared
lightness is not a shared weight: blue at L 0.5 carries about a seventh of
the luminance of yellow at L 0.5, which is how the org-remark important pen came out
a near-black smudge on a dark page while the question pen read fine.
Luminance climbs monotonically with lightness at a fixed hue and
saturation, so a bisection finds the lightness that lands on ANCHOR."
  (if-let* ((rgb (color-name-to-rgb hue))
            (goal (zetta-color--luminance anchor)))
      (let* ((hsl (apply #'color-rgb-to-hsl rgb))
             (h (nth 0 hsl))
             ;; A theme colour that is genuinely achromatic is left
             ;; alone: forcing it up to the saturation floor would pick
             ;; hue 0 and silently turn a grey pen red.
             (s (if (< (nth 1 hsl) 0.05)
                    (nth 1 hsl)
                  (min (cdr sat) (max (car sat) (nth 1 hsl)))))
             (lo 0.0) (hi 1.0) (l 0.5) (hex hue))
        (dotimes (_ 14)
          (setq l (/ (+ lo hi) 2.0)
                hex (apply #'color-rgb-to-hex
                           (append (color-hsl-to-rgb h s l) '(2))))
          (if (< (zetta-color--luminance hex) goal)
              (setq lo l)
            (setq hi l)))
        hex)
    hue))

(defun zetta-hue-of (color)
  "Hue of COLOR as a turn in [0,1), or nil if it cannot be parsed."
  (when-let* ((rgb (color-name-to-rgb color)))
    (car (apply #'color-rgb-to-hsl rgb))))

(defun zetta-with-hue (color hue)
  "COLOR rotated to HUE (a turn in [0,1)), keeping its saturation and value."
  (if-let* ((rgb (color-name-to-rgb color)))
      (let ((hsl (apply #'color-rgb-to-hsl rgb)))
        (apply #'color-rgb-to-hex
               (append (color-hsl-to-rgb hue (nth 1 hsl) (nth 2 hsl)) '(2))))
    color))

(defun zetta-hue--clear-p (hue taken min-sep)
  "Non-nil if HUE sits at least MIN-SEP turns from every hue in TAKEN."
  (cl-every (lambda (other)
              (let ((d (abs (- hue other))))
                ;; the wheel wraps: 0.98 and 0.02 are 0.04 apart, not 0.96
                (>= (min d (- 1.0 d)) min-sep)))
            taken))

(defun zetta-hue-separate (hues min-sep)
  "HUES rotated apart so no two sit closer than MIN-SEP turns on the wheel.

Earlier entries keep their hue outright; a later one that crowds an
earlier one is moved to the NEAREST angle that clears everything already
placed, searching outward in both directions -- the smallest lie that
works, so a theme whose colours are already spread is left untouched and
one that bunches them is bent no further than it has to be.

Needed because a palette is under no obligation to supply four separable
hues.  ef-light paints `error' crimson and `warning' rust, two steps
apart on the wheel; doric-obsidian paints `warning' tan and `link' brown,
which wash to the same colour outright.  Where hue is decoration this
does not matter and the answer is to drop hue altogether (see
`zetta-vc-marker-ladder').  Where hue is the CONTENT, it has to be made
to separate."
  (let (taken out)
    (dolist (h hues (nreverse out))
      (let ((pick (if (or (null h) (zetta-hue--clear-p h taken min-sep))
                      h
                    (cl-loop for step from 0.01 to 0.5 by 0.01
                             for up = (mod (+ h step) 1.0)
                             for down = (mod (- h step) 1.0)
                             if (zetta-hue--clear-p up taken min-sep) return up
                             else if (zetta-hue--clear-p down taken min-sep)
                             return down
                             finally return h))))
        (when pick (push pick taken))
        (push pick out)))))

;;; ------------------------------------------------------------------
;;; Keyword prominence tiers
;;; ------------------------------------------------------------------
;; For the keyword vocabularies that appear as WORDS in a buffer: org's
;; TODO states, hl-todo's TODO/FIXME/NOTE.  The word already says which
;; keyword it is, so colour has nothing left to encode but how much
;; attention the thing deserves -- which is what these four rungs of the
;; brushup ink ladder say, on the same principle as
;; `zetta-line-chip-ladder' and `zetta-vc-marker-ladder'.
;;
;; Shared so that a word painted by two packages lands in one place.
;; hl-todo is hooked into `org-mode', so an org heading's TODO is
;; highlighted twice and hl-todo wins; when both consult this table, that
;; stops mattering.

(defvar zetta-keyword-tiers
  '((loud   . brushup-fg)     ; something is wrong, or in flight
    (open   . brushup-fg-2)   ; wants you
    (parked . brushup-fg-4)   ; context, not a call to action
    (closed . brushup-fg-6))  ; over
  "Ink-ladder rung for each keyword-prominence tier.")

(defun zetta-tier-color (tier)
  "Colour for keyword-prominence TIER.  See `zetta-keyword-tiers'."
  (let ((rung (alist-get tier zetta-keyword-tiers)))
    (or (and rung (boundp rung) (symbol-value rung))
        (face-foreground 'default nil t)
        "#a0a0a0")))

(defconst zetta-line-chip-ladder
  '((bare   nil          nil)
    (chip   brushup-bg-2 brushup-bg-1)
    (mid    brushup-bg-4 brushup-bg-2)
    (invert brushup-fg-1 brushup-bg-4))
  "Pill backgrounds by PROMINENCE, as (TIER SELECTED-WINDOW UNSELECTED-WINDOW).

The bars are transparent, so a badge cannot lean on a bar colour to be
seen, and it should not lean on a HUE either: an accent-coloured pill is a
blue smudge on a monochrome theme and says nothing a reader can decode.
These four tiers encode prominence as position on the same brushup
background ladder the tab pills use, so a badge is loud or quiet by how far
it sits from the page, never by what colour it is:

  bare    no pill at all -- the resting state, quietest
  chip    barely lifted off the page
  mid     a clearly present grey keycap
  invert  near-foreground: the loudest thing the line can say

Each tier names its own unselected colour one or two rungs down, so the
whole vocabulary dims together with everything else in an unfocused
window.  Symbols, not colours: they are resolved per call, after a theme
change has rewritten the palette.")

(defun zetta-line-chip (tier &optional inactive)
  "Style plist (`:bg\=' + readable `:color\=') for a TIER pill, or nil for `bare\='.
TIER is a key of `zetta-line-chip-ladder\='; INACTIVE picks its unselected
colour.  An unselected label is additionally muted the same way the mode
line\='s buffer chip is, so a badge never out-reads its own window."
  (when-let* ((row (assq tier zetta-line-chip-ladder))
              (sym (nth (if inactive 2 1) row))
              (bg  (and (boundp sym) (symbol-value sym))))
    (list :bg bg
          :color (let ((c (zetta-readable-on bg)))
                   ;; Muted TOWARD ITS OWN PILL, not toward the page: the pill
                   ;; has already stepped down a rung or two, so blending the
                   ;; label to the page on top of that lands each tier at a
                   ;; different, and for `invert' an unreadable, ratio.  Against
                   ;; its own pill every tier settles around 5:1 -- clearly
                   ;; quieter than the ~12:1 it reads at when selected, and
                   ;; still legible, which the ace keycap needs.
                   (if inactive (zetta-line-blend c bg 0.3) c)))))

(defconst zetta-line-modal-abbrev
  '(("normal" . "N") ("insert" . "I") ("visual" . "V") ("replace" . "R")
    ("operator" . "O") ("motion" . "M") ("emacs" . "E")
    ("beacon" . "B") ("keypad" . "K"))
  "Single-letter abbreviations for the states evil and meow report.
The mode line has room for a letter, not a word, and the state is glanced
at rather than read.  Any state not listed falls back to its own uppercased
first letter, which keeps every evil/meow state distinct in practice.")

(defconst zetta-line-modal-tier
  '(("insert" . invert) ("replace" . invert)
    ("visual" . mid) ("beacon" . mid) ("keypad" . mid)
    ("normal" . bare) ("motion" . bare) ("operator" . bare))
  "Prominence tier (see `zetta-line-chip-ladder\=') per modal state.

The states you can leave text in by accident -- insert, replace -- invert;
the transient selection states sit at `mid\='; normal and its navigational
relatives are `bare\=', because the resting state should not draw the eye.
Anything unlisted gets a faint `chip\=', so a state this table has not met
still reads as \"not normal\".  With hue gone, this tier and the letter are
what tell the states apart.")

;;; mode-line text segments
(defun zetta-modeline-svg--modal ()
  "The modal state as a single letter on a monochrome pill.

A letter rather than the word: `zetta-line-modal-abbrev\=' maps the state,
and the full name stays in the tooltip.  Colour is not carrying the
distinction any more -- green-for-insert said nothing to anyone who had not
been told, and read as a stray hue on a monochrome theme -- so the state is
told by its letter and by how far its pill sits off the page
\(`zetta-line-modal-tier\='), which works on any theme, light or dark.

The label is always padded to three characters so the segments after it do
not shift as the state changes.  The modal state is global, so every window
draws the same badge; the unselected ones step down the ladder, otherwise a
screenful of identical pills would say nothing about where point is."
  (let* ((st (zetta-line-modal-state))
         (letter (or (cdr (assoc st zetta-line-modal-abbrev))
                     (and (> (length st) 0) (upcase (substring st 0 1)))
                     "?"))
         (tier (or (cdr (assoc st zetta-line-modal-tier)) 'chip))
         (chip (zetta-line-chip tier (not (mode-line-window-selected-p)))))
    (apply #'zetta-svg-seg (format " %s " letter) 'ml-modal
           (append
            (list :help (format "modal state: %s" st)
                  :action-help "show key bindings"
                  :action #'describe-bindings
                  :menu (list (cons "Describe bindings" #'describe-bindings)
                              (cons "Describe mode" #'describe-mode)
                              (cons "Command (M-x)" #'execute-extended-command)))
            (and chip (append chip (list :weight 'bold)))))))

(defun zetta-modeline-svg--ace ()
  "Ace-window key for this window, as a monochrome keycap.

`aw-update\=' keeps `ace-window-path\=' populated at all times (see
ace-window.el), so this badge is permanent furniture rather than something
that appears during a jump -- which is why it dims with its window like the
rest of the line, and why it is a grey keycap rather than the theme accent
it used to borrow.  It stays legible when unselected: an unselected window
is exactly the one you are about to jump TO, so its key still has to read."
  (let ((path (window-parameter (selected-window) 'ace-window-path)))
    (and path (> (length path) 0)
         (apply #'zetta-svg-seg (format " %s " path) 'ml-ace
                :weight 'bold
                (append (zetta-line-chip 'mid (not (mode-line-window-selected-p)))
                        (list :help (format "ace-window key: %s" path)))))))

(defun zetta-modeline--lighter-bg (&optional inactive)
  "A chip background for the buffer name, or nil when the theme is unknown.

This used to blend the mode-line's own background toward the foreground,
but the mode line has no background any more -- it is transparent, and the
chip is one of the few pieces of material left floating on the buffer
background.  So it is taken straight off the brushup ladder instead, the
same ladder the tab-line pills use: one step up from the buffer background
for the selected window, half a step for the rest.  INACTIVE picks the
fainter chip."
  (if inactive
      (bound-and-true-p brushup-bg-1)
    (bound-and-true-p brushup-bg-2)))

(defun zetta-modeline-svg--buffer ()
  (let* ((buf (current-buffer))
         (n (buffer-name buf))
         (label (if (> (length n) 40) (concat (substring n 0 39) "…") n))
         ;; The chip took no notice of window selection before, so every
         ;; window's buffer name looked equally present.  With no bar behind
         ;; it that was the whole cue, so it now steps down with the rest.
         (activep (mode-line-window-selected-p))
         (chip (zetta-modeline--lighter-bg (not activep))))
    (svg-line-seg
     label
     ;; id includes the buffer so only THIS window's name boxes on hover
     :id (list 'ml-buffer buf)
     :bg chip
     :color (and chip (let ((c (zetta-readable-on chip)))
                        (if activep c (zetta-line-blend c chip 0.3))))
     :help (format "buffer: %s" n)
     :action-help "switch buffer"
     :action #'switch-to-buffer
     :menu (delq nil
                 (list
                  (cons "Switch buffer…" #'switch-to-buffer)
                  (cons "Save buffer"
                        (lambda () (interactive)
                          (with-current-buffer buf (save-buffer))))
                  (and (buffer-file-name buf)
                       (cons "Rename file…"
                             (lambda () (interactive)
                               (with-current-buffer buf
                                 (call-interactively #'rename-visited-file)))))
                  (cons "Revert buffer"
                        (lambda () (interactive)
                          (with-current-buffer buf (revert-buffer))))
                  (cons "Copy buffer name"
                        (lambda () (interactive) (kill-new n)))
                  (cons "Kill buffer"
                        (lambda () (interactive)
                          (when (buffer-live-p buf) (kill-buffer buf)))))))))

(defun zetta-modeline-svg--mode ()
  (zetta-svg-seg
   (format-mode-line mode-name) 'ml-mode
   :help (format "major mode: %s" major-mode)
   :action-help "describe mode"
   :action #'describe-mode
   :menu (list (cons "Describe mode" #'describe-mode)
               (cons "Describe bindings" #'describe-bindings)
               (cons "Customize mode" #'customize-mode))))

;; The vc cluster (git glyph + branch glyph + repo:branch) is one clickable
;; segment so the whole thing opens magit -- the separate icon segments are
;; folded in here and dropped from the mode-line content.
(defun zetta-modeline-svg--vc ()
  (when (and (fboundp 'vc-git-root)
             (vc-git-root (or (buffer-file-name) default-directory)))
    (let* ((repo   (ignore-errors (nth 0 (zetta-get-repo-name))))
           (branch (ignore-errors (vc-git--symbolic-ref
                                   (or (buffer-file-name) default-directory))))
           (vcg (and (buffer-file-name) (featurep 'nerd-icons)
                     (zetta-line--glyph (ignore-errors (nerd-icons-devicon "nf-dev-git")))))
           (brg (and (buffer-file-name) (featurep 'nerd-icons)
                     (zetta-line--glyph (ignore-errors (nerd-icons-octicon "nf-oct-git_branch")))))
           (text (concat (and vcg (concat vcg " "))
                         (and brg (concat brg " "))
                         (or repo "") (and branch (concat ":" branch)))))
      (zetta-svg-seg
       text 'ml-vc
       :help (format "git: %s%s" (or repo "?") (if branch (concat " @ " branch) ""))
       :action-help "open magit"
       :action (if (fboundp 'magit-status) #'magit-status #'vc-dir)
       :menu (delq nil
                   (list (and (fboundp 'magit-status) (cons "Magit status" #'magit-status))
                         (and (fboundp 'magit-log-current) (cons "Magit log" #'magit-log-current))
                         (and (fboundp 'magit-blame) (cons "Magit blame" #'magit-blame))
                         (and (fboundp 'magit-file-dispatch) (cons "File dispatch" #'magit-file-dispatch))
                         (cons "VC dir" #'vc-dir)
                         (and branch (cons "Copy branch name"
                                           (let ((b branch))
                                             (lambda () (interactive) (kill-new b)))))))))))

(defun zetta-modeline-svg--checkers ()
  ;; copilot is shown as an icon (zetta-modeline-svg--copilot-icon), not text
  (when (and (boundp 'lsp-mode) lsp-mode)
    (zetta-svg-seg
     (or (and (featurep 'nerd-icons)
              (zetta-line--glyph (ignore-errors (nerd-icons-devicon "nf-dev-vscode"))))
         "lsp")
     'ml-lsp
     :help "LSP session"
     :action-help "LSP diagnostics"
     :action (cond ((fboundp 'consult-lsp-diagnostics) #'consult-lsp-diagnostics)
                   ((fboundp 'lsp-treemacs-errors-list) #'lsp-treemacs-errors-list)
                   ((fboundp 'flymake-show-buffer-diagnostics) #'flymake-show-buffer-diagnostics)
                   (t #'ignore))
     :menu (delq nil
                 (list (and (fboundp 'lsp-describe-session) (cons "Describe session" #'lsp-describe-session))
                       (and (fboundp 'lsp-rename) (cons "Rename symbol" #'lsp-rename))
                       (and (fboundp 'lsp-find-references) (cons "Find references" #'lsp-find-references))
                       (and (fboundp 'lsp-organize-imports) (cons "Organize imports" #'lsp-organize-imports))
                       (and (fboundp 'lsp-workspace-restart) (cons "Restart workspace" #'lsp-workspace-restart)))))))

(defconst zetta-line-flycheck-tier
  '((error . invert) (warning . mid) (info . chip))
  "Prominence tier (see `zetta-line-chip-ladder\=') per worst diagnostic level.
Checked in this order; a buffer with nothing to report gets no pill at all.")

(defun zetta-modeline-svg--flycheck ()
  "Flycheck indicator: a bug glyph plus error/warning/info counts.

Severity is carried by the pill\='s PROMINENCE, not by a hue: errors invert,
warnings sit at `mid\=', an info-only buffer gets a faint `chip\=', and a
clean one stays `bare\=' so it does not draw the eye.  The red/amber/green
this used to draw were the last hardcoded colours on the line -- they
ignored the theme entirely (a fixed #f85149 on any background, light or
dark), and the counts already spell the severity out as \"2e 1w\", so the
colour was only repeating what the label had said.  The tier steps down in
an unselected window like every other badge.

Shown whenever `flycheck-mode\=' is active."
  (when (and (bound-and-true-p flycheck-mode) (fboundp 'flycheck-count-errors))
    (let* ((counts (flycheck-count-errors flycheck-current-errors))
           (err  (or (cdr (assq 'error counts)) 0))
           (warn (or (cdr (assq 'warning counts)) 0))
           (info (or (cdr (assq 'info counts)) 0))
           (bug  (and (featurep 'nerd-icons)
                      (zetta-line--glyph (ignore-errors (nerd-icons-codicon "nf-cod-bug")))))
           (parts (delq nil (list (and (> err 0)  (format "%de" err))
                                  (and (> warn 0) (format "%dw" warn))
                                  (and (> info 0) (format "%di" info)))))
           (label (concat (or bug "fc")
                          (and parts (concat " " (string-join parts " ")))))
           (worst (cond ((> err 0) 'error) ((> warn 0) 'warning) ((> info 0) 'info)))
           (chip (and worst
                      (zetta-line-chip (alist-get worst zetta-line-flycheck-tier)
                                       (not (mode-line-window-selected-p))))))
      (apply #'zetta-svg-seg
             (format " %s " label) 'ml-flycheck
             (append
              (list
               :help (format "flycheck: %d error(s), %d warning(s), %d info" err warn info)
               :action-help "list errors"
               :action (if (fboundp 'flycheck-list-errors) #'flycheck-list-errors #'ignore)
               :menu (delq nil
                           (list (and (fboundp 'flycheck-list-errors) (cons "List errors" #'flycheck-list-errors))
                                 (and (fboundp 'flycheck-next-error) (cons "Next error" #'flycheck-next-error))
                                 (and (fboundp 'flycheck-previous-error) (cons "Previous error" #'flycheck-previous-error))
                                 (and (fboundp 'flycheck-buffer) (cons "Recheck buffer" #'flycheck-buffer))
                                 (and (fboundp 'flycheck-verify-setup) (cons "Verify setup" #'flycheck-verify-setup)))))
              (and chip (append chip (list :weight 'bold))))))))

(defun zetta-modeline-svg--indicators ()
  (let* ((flags (delq nil
                      (list (and (bound-and-true-p repeat-in-progress) (cons "R" "repeat in progress"))
                            (and (fboundp 'zetta-line-tramp-icon) (zetta-line-tramp-icon) (cons "T" "remote (TRAMP)"))
                            (and (fboundp 'zetta-line-docker-icon) (zetta-line-docker-icon) (cons "D" "docker"))
                            (and (buffer-narrowed-p) (cons "N" "buffer narrowed"))
                            (and (fboundp 'zetta-line-hydra-indicator-icon) (zetta-line-hydra-indicator-icon) (cons "H" "hydra active")))))
         (text (mapconcat #'car flags "")))
    (when (> (length text) 0)
      (zetta-svg-seg
       text 'ml-flags
       :help (concat "flags: " (mapconcat #'cdr flags ", "))
       :action-help (if (buffer-narrowed-p) "widen buffer" "describe")
       :action (if (buffer-narrowed-p) #'widen #'ignore)
       :menu (delq nil
                   (list (and (buffer-narrowed-p) (cons "Widen buffer" #'widen))
                         (and (bound-and-true-p repeat-in-progress) (cons "Repeat help" #'describe-bindings))))))))

(defun zetta-modeline-svg--docpos ()
  (cond
   ((and (eq major-mode 'pdf-view-mode) (fboundp 'pdf-view-current-page))
    (let ((text (ignore-errors (format "%d/%d" (pdf-view-current-page)
                                       (pdf-cache-number-of-pages)))))
      (when text
        (zetta-svg-seg
         text 'ml-docpos
         :help "PDF page"
         :action-help "go to page"
         :action (if (fboundp 'pdf-view-goto-page) #'pdf-view-goto-page #'ignore)
         :menu (delq nil
                     (list (and (fboundp 'pdf-view-goto-page) (cons "Go to page…" #'pdf-view-goto-page))
                           (and (fboundp 'pdf-view-first-page) (cons "First page" #'pdf-view-first-page))
                           (and (fboundp 'pdf-view-last-page) (cons "Last page" #'pdf-view-last-page))))))))
   (t "")))

(defun zetta-modeline-svg--point ()
  (let* ((cur (line-number-at-pos))
         (tot (max 1 (line-number-at-pos (point-max))))
         (pct (round (* 100.0 (/ (float cur) tot)))))
    (zetta-svg-seg
     (format "%s  %d%%" (format-mode-line "%l:%c") pct) 'ml-point
     :help (format "line %d/%d (%d%%) : column" cur tot pct)
     :action-help "go to line"
     :action #'goto-line
     :menu (list (cons "Go to line…" #'goto-line)
                 (cons "What cursor position" #'what-cursor-position)
                 (cons "Go to char…" #'goto-char)))))

;;; header-line breadcrumb content
(defvar zetta-header-line-svg-line1-format
  '((:eval (when (or
                  (eq major-mode 'docker-image-mode)
                  (eq major-mode 'docker-container-mode)
                  (eq major-mode 'docker-volume-mode)
                  (eq major-mode 'embark-collect-mode))
             (propertize
              (window-parameter (selected-window) 'ace-window-path)
              'face 'focus-focused)))
    " "
    (:eval (when (fboundp 'spinner-print) (spinner-print spinner-current)))
    " "
    (:eval (ignore-errors (let ((i (nerd-icons-icon-for-buffer)))
                            (and (stringp i) (> (length i) 0) (concat i " ")))))
    (:eval (ignore-errors (concat (nerd-icons-mdicon "nf-md-folder") " ")))
    (:eval
     (let* ((dir default-directory)
            (path (abbreviate-file-name dir))
            (disp (if (> (length path) 30) (zetta-minify-path dir) path)))
       ;; clickable: a keymap (which the header-line harvester picks up) that
       ;; opens dired on the directory; no breadcrumb target prop, so the
       ;; harvester keeps this handler rather than building a jump.
       (propertize disp
                   'keymap (let ((m (make-sparse-keymap)))
                             (define-key m [header-line mouse-1]
                               (lambda () (interactive) (dired dir)))
                             m)
                   'help-echo (format "mouse-1: dired %s" dir)))))
  "Mode-line construct for header-line row 1 (mode icon / folder / path).")

(defvar zetta-header-line-svg-line2-format
  '((:eval
     (cond
      ((and (boundp 'lsp-mode) lsp-mode)
       (concat (ignore-errors (concat (nerd-icons-mdicon "nf-md-sitemap") " "))
               (window-parameter nil 'lsp-headerline--string)))
      ((derived-mode-p 'org-mode)
       ;; Prefer breadcrumb's imenu crumbs (each carries a clickable keymap our
       ;; header-line harvests) over `org-display-outline-path' (no per-crumb
       ;; keymap, so it would render as plain, non-clickable text).
       (if (fboundp 'breadcrumb-imenu-crumbs)
           (concat (ignore-errors (concat (nerd-icons-mdicon "nf-md-format_list_bulleted") " "))
                   ;; crumbs can signal on malformed imenu indexes (e.g.
                   ;; pdf-view outlines); never let that escape redisplay
                   (or (ignore-errors (breadcrumb-imenu-crumbs)) ""))
         (propertize
          (or (ignore-errors (org-display-outline-path nil t "/" t)) "/")
          'face '(:height 0.8))))
      ((or (equal major-mode 'jsonian-mode))
       (concat (jsonian--display-path (jsonian-path))))
      ((or (equal major-mode 'docker-compose-mode)
           (equal major-mode 'yaml-mode))
       (concat (jpt-yaml-path-to-point)))
      (t (when (fboundp 'breadcrumb-imenu-crumbs)
           (concat (ignore-errors (concat (nerd-icons-mdicon "nf-md-format_list_bulleted") " "))
                   (or (ignore-errors (breadcrumb-imenu-crumbs)) "")))))))
  "Mode-line construct for header-line row 2 (lsp / org / imenu crumbs).")

(defun zetta-header-line-svg--line1 ()
  "Render the first breadcrumb row (path / position), crumbs clickable."
  (zetta-svg-segs-from-propertized
   (format-mode-line zetta-header-line-svg-line1-format) 'hl1))

(defun zetta-header-line-svg--line2 ()
  "Render the second breadcrumb row (lsp / org / imenu crumbs), crumbs clickable."
  (zetta-svg-segs-from-propertized
   (format-mode-line zetta-header-line-svg-line2-format) 'hl2))

;;;; Nerd-font glyph icons for the SVG bars
;; ----------------------------------------------------------------
;; The bars render in a scalable Nerd Font (`zetta-svg-line-font'), so
;; icons are just text glyphs (nerd-icons codepoints): they flow inline
;; with the text in one native SVG <text>, font-accurate -- no separate
;; positioning, no char-advance estimation, no svg-lib path injection.
;; Each segment returns the bare glyph string (properties stripped) or nil.

(defvar zetta-svg-line-font "Terminess Nerd Font Mono"
  "Font family for the SVG bars (tab-bar, mode-line, tab-line, header-line).
A single-width Nerd Font carrying the icon glyphs, so icons render inline
as ordinary text.  Terminess is the Nerd-patched Terminus, keeping that
look; any Nerd Font works (e.g. \"JetBrainsMono Nerd Font Mono\").  Buffers
keep their own font (`zetta-font').")

(defun zetta-line--glyph (s)
  "Return nerd-icons glyph string S without text properties, or nil if empty."
  (and (stringp s)
       (let ((g (substring-no-properties s)))
         (and (> (length (string-trim g)) 0) g))))

;; Text-scale responsiveness now lives in the svg-line package
;; (`svg-line-scale-with-text-scale'): the engine scales line sizes with
;; the default-face height, so the bars track default-text-scale without
;; any config-side helper.

(defun zetta-line-buffer-glyph (&optional buffer)
  "Nerd-font file-type glyph for BUFFER (current by default), or nil."
  (and (featurep 'nerd-icons)
       (with-current-buffer (or buffer (current-buffer))
         (zetta-line--glyph (ignore-errors (nerd-icons-icon-for-buffer))))))

(defun zetta-circle-number (n)
  "Return a Nerd-Font circled-number glyph for integer N, or nil.
0-9 use `nf-md-numeric_N_circle'; 10 uses `nf-md-numeric_10_circle'; anything
higher falls back to `nf-md-numeric_9_plus_circle'.  The glyph carries
`:family' `zetta-svg-line-font' so it renders even in a plain-text context (an
SVG bar uses the engine's own font instead, so the face is harmless there).
This is the single source of the numbered-circle glyphs shared by the tab-line,
the space-tree tab-bar lighter, and (visually) svg-margin's org-heading rail."
  (and (featurep 'nerd-icons)
       (integerp n)
       (let ((g (zetta-line--glyph
                 (ignore-errors
                   (cond ((<= 0 n 9) (nerd-icons-mdicon (format "nf-md-numeric_%d_circle" n)))
                         ((= n 10)   (nerd-icons-mdicon "nf-md-numeric_10_circle"))
                         (t          (nerd-icons-mdicon "nf-md-numeric_9_plus_circle")))))))
         (and g (propertize g 'face (list :family zetta-svg-line-font))))))

;;; mode line
(defun zetta-modeline-svg--file-icon ()
  "File-type glyph for the current buffer."
  (zetta-line-buffer-glyph))

(defun zetta-modeline-svg--copilot-icon ()
  "GitHub Copilot glyph, shown when `copilot-mode' is on.  Click toggles it."
  (when (bound-and-true-p copilot-mode)
    (let ((g (and (featurep 'nerd-icons)
                  (zetta-line--glyph (ignore-errors (nerd-icons-octicon "nf-oct-copilot"))))))
      (when g
        (zetta-svg-seg
         g 'ml-copilot
         :help "GitHub Copilot (on)"
         :action-help "toggle Copilot"
         :action (if (fboundp 'copilot-mode) #'copilot-mode #'ignore)
         :menu (delq nil
                     (list (and (fboundp 'copilot-mode) (cons "Toggle Copilot" #'copilot-mode))
                           (and (fboundp 'copilot-complete) (cons "Complete now" #'copilot-complete))
                           (and (fboundp 'copilot-diagnose) (cons "Diagnose" #'copilot-diagnose)))))))))

(defun zetta-modeline-svg--vc-icon ()
  "Git glyph, shown when the file is under git version control."
  (when (and (buffer-file-name) (fboundp 'vc-git-root) (vc-git-root (buffer-file-name)))
    (and (featurep 'nerd-icons)
         (zetta-line--glyph (ignore-errors (nerd-icons-devicon "nf-dev-git"))))))

(defun zetta-modeline-svg--branch-icon ()
  "Branch glyph, shown when the file is on a git branch."
  (when (and (buffer-file-name) (fboundp 'vc-git-root) (vc-git-root (buffer-file-name)))
    (and (featurep 'nerd-icons)
         (zetta-line--glyph (ignore-errors (nerd-icons-octicon "nf-oct-git_branch"))))))

;;; tab bar
(defun zetta-tab-bar-file-icon ()
  "File-type glyph for the current buffer (tab bar)."
  (zetta-line-buffer-glyph))

(defun zetta-tab-bar-mu4e-icon ()
  "Mail glyph, shown when mu4e has a non-empty modeline string."
  (when (and (fboundp 'mu4e--modeline-string)
             (let ((s (ignore-errors (mu4e--modeline-string))))
               (and s (> (length (string-trim s)) 0)))) (and (featurep 'nerd-icons)
         (zetta-line--glyph (ignore-errors (nerd-icons-mdicon "nf-md-email_outline"))))))

(defun zetta-tab-bar-mu4e-text ()
  "The mu4e modeline string (unread counts, etc.), trimmed."
  (when (fboundp 'mu4e--modeline-string)
    (string-trim (or (ignore-errors (mu4e--modeline-string)) ""))))

;; Elfeed unread count, CACHED: the db holds 50k+ entries, so counting at
;; render time (the tab bar redraws every keystroke) is out.  The count is
;; recomputed off-render -- debounced on elfeed's update/tag hooks -- and
;; the segment just reads the cache.
(defvar zetta-tab-bar--elfeed-unread nil
  "Cached number of unread elfeed entries, or nil before elfeed loads.")

(defvar zetta-tab-bar--elfeed-count-timer nil)

(defcustom zetta-tab-bar-elfeed-count-window (* 6 30 24 60 60)
  "Age window (seconds) for the tab-bar elfeed unread count.
Matches the \"@6-months-ago\" horizon of the elfeed quick filters, so the
indicator agrees with what the search buffer shows -- and keeps ancient
entries whose read-state never synced back (a fever API limitation) from
inflating the number forever."
  :type 'integer :group 'zetta)

(defun zetta-tab-bar--elfeed-count-unread ()
  "Count unread entries within `zetta-tab-bar-elfeed-count-window'.
The db visits newest-first, so the scan stops at the window edge."
  (let ((n 0)
        (cutoff (- (float-time) zetta-tab-bar-elfeed-count-window)))
    (with-elfeed-db-visit (entry _feed)
      (if (< (elfeed-entry-date entry) cutoff)
          (elfeed-db-return)
        (when (memq 'unread (elfeed-entry-tags entry))
          (setq n (1+ n)))))
    n))

(defun zetta-tab-bar--elfeed-recount (&rest _)
  "Debounced recount of elfeed unread entries; refreshes the tab bar."
  (when (timerp zetta-tab-bar--elfeed-count-timer)
    (cancel-timer zetta-tab-bar--elfeed-count-timer))
  (setq zetta-tab-bar--elfeed-count-timer
        (run-with-idle-timer
         2 nil
         (lambda ()
           (when (featurep 'elfeed)
             (setq zetta-tab-bar--elfeed-unread
                   (ignore-errors (zetta-tab-bar--elfeed-count-unread)))
             (force-mode-line-update t))))))

(with-eval-after-load 'elfeed
  (add-hook 'elfeed-update-hooks #'zetta-tab-bar--elfeed-recount)
  (add-hook 'elfeed-tag-hooks #'zetta-tab-bar--elfeed-recount)
  (add-hook 'elfeed-untag-hooks #'zetta-tab-bar--elfeed-recount)
  (zetta-tab-bar--elfeed-recount))

;; "+N new this pull": how many entries the most recent update added, shown
;; mu4e-style beside the unread count and cleared when you open elfeed.  New
;; entries arrive asynchronously (curl/fever callbacks), so accumulate per
;; entry and promote the batch to the indicator once update activity settles.
(defvar zetta-tab-bar--elfeed-new-count 0
  "New elfeed entries from the last completed pull (the +N indicator).")
(defvar zetta-tab-bar--elfeed-new-accum 0
  "New entries seen so far in the in-progress pull, before promotion.")
(defvar zetta-tab-bar--elfeed-new-timer nil)

(defun zetta-tab-bar--elfeed-note-new (&rest _)
  "Count one new entry for the current pull (on `elfeed-new-entry-hook')."
  (setq zetta-tab-bar--elfeed-new-accum (1+ zetta-tab-bar--elfeed-new-accum)))

(defun zetta-tab-bar--elfeed-promote-new (&rest _)
  "Debounced: promote the pull's accumulated new count to the indicator.
Runs after update activity settles, so a burst of feeds reads as one pull.
A pull that added nothing leaves the previous +N (entries you've not seen)."
  (when (timerp zetta-tab-bar--elfeed-new-timer)
    (cancel-timer zetta-tab-bar--elfeed-new-timer))
  (setq zetta-tab-bar--elfeed-new-timer
        (run-with-idle-timer
         2 nil
         (lambda ()
           (when (> zetta-tab-bar--elfeed-new-accum 0)
             (setq zetta-tab-bar--elfeed-new-count zetta-tab-bar--elfeed-new-accum
                   zetta-tab-bar--elfeed-new-accum 0)
             (force-mode-line-update t))))))

(defun zetta-tab-bar--elfeed-clear-new (&rest _)
  "Clear the +N indicator -- you've opened elfeed, so the new ones are seen."
  (setq zetta-tab-bar--elfeed-new-count 0
        zetta-tab-bar--elfeed-new-accum 0)
  (force-mode-line-update t))

(with-eval-after-load 'elfeed
  (add-hook 'elfeed-new-entry-hook #'zetta-tab-bar--elfeed-note-new)
  (add-hook 'elfeed-update-hooks #'zetta-tab-bar--elfeed-promote-new)
  (advice-add 'elfeed :after #'zetta-tab-bar--elfeed-clear-new))

(defun zetta-tab-bar-clock ()
  "The `display-time' clock string, trimmed."
  (when (boundp 'display-time-string) (string-trim (or display-time-string ""))))

(defcustom zetta-tab-bar-battery-low 20
  "At or below this battery percentage the indicator is drawn red."
  :type 'integer :group 'zetta)
(defcustom zetta-tab-bar-battery-medium 50
  "At or below this battery percentage the indicator is drawn orange (red wins
below `zetta-tab-bar-battery-low'); above it the indicator is green."
  :type 'integer :group 'zetta)
(defcustom zetta-tab-bar-battery-colors nil
  "Explicit battery colours as an alist of (low medium full).
nil -- the default -- derives them from the theme's `error', `warning' and
`success' faces instead, so the indicator tracks whatever theme is loaded."
  :type '(alist :key-type symbol :value-type color) :group 'zetta)

(defvar zetta-tab-bar--battery-cache nil
  "(TIME . DATA) of the last battery status read; DATA is the alist.")

(defun zetta-tab-bar--battery-note (data)
  "Record DATA from `battery-update-functions' so renders never poll."
  (setq zetta-tab-bar--battery-cache (cons (float-time) data)))
(add-hook 'battery-update-functions #'zetta-tab-bar--battery-note)

(defun zetta-tab-bar--battery-data ()
  "Return (PCT . PLUGGED) from the cached battery status, or nil.
PCT is the integer charge percentage; PLUGGED is non-nil when on AC power.
`battery-status-function' shells out (pmset on macOS) and this renders
inside redisplay, so the status is polled here at most once a minute;
`display-battery-mode' normally refreshes the cache off-redisplay via
`battery-update-functions' before that ever expires."
  (when (and (boundp 'battery-status-function) (functionp battery-status-function))
    (let ((now (float-time)))
      (when (or (null zetta-tab-bar--battery-cache)
                (> (- now (car zetta-tab-bar--battery-cache)) 60))
        (setq zetta-tab-bar--battery-cache
              (cons now (ignore-errors (funcall battery-status-function)))))
      (when-let* ((data (cdr zetta-tab-bar--battery-cache)))
        (cons (string-to-number (or (cdr (assq ?p data)) "0"))
              (and (member (cdr (assq ?L data)) '("AC" "on-line" "on")) t))))))

(defun zetta-tab-bar--battery-fa-glyph (pct)
  "Font-Awesome battery glyph (nf-fa-battery_0..4) for PCT, or nil."
  (let ((n (cond ((>= pct 88) 4) ((>= pct 63) 3) ((>= pct 38) 2)
                 ((>= pct 13) 1) (t 0))))
    (and (featurep 'nerd-icons)
         (zetta-line--glyph (ignore-errors
                              (nerd-icons-faicon (format "nf-fa-battery_%d" n)))))))

(defun zetta-tab-bar--battery-color (pct)
  "Return the level colour for PCT.
Honours `zetta-tab-bar-battery-colors' when set; otherwise takes the
theme's own error/warning/success colours, so the indicator tracks the
theme rather than staying red-orange-green from a fixed palette."
  (let ((level (cond ((<= pct zetta-tab-bar-battery-low) 'low)
                     ((<= pct zetta-tab-bar-battery-medium) 'medium)
                     (t 'full))))
    (or (cdr (assq level zetta-tab-bar-battery-colors))
        (zetta-theme-color (pcase level
                             ('low 'error) ('medium 'warning) (_ 'success))))))

(defun zetta-tab-bar-workspace-lighter ()
  "The space-tree lighter string, or nil.
NB: `space-tree-modeline-lighter' is a FUNCTION (it returns the current-space
string like \"{ 1' }\"), not a variable -- so it must be called."
  (and (fboundp 'space-tree-modeline-lighter)
       (let ((s (ignore-errors (space-tree-modeline-lighter))))
         (and (stringp s) (> (length (string-trim s)) 0)
              (substring-no-properties s)))))

(defun zetta-tab-bar-workspace-icon ()
  "Workspace glyph, shown when space-tree has a lighter."
  (when (zetta-tab-bar-workspace-lighter)
    (and (featurep 'nerd-icons)
         (zetta-line--glyph (ignore-errors (nerd-icons-mdicon "nf-md-view_dashboard"))))))

(defun zetta-tab-bar-workspace-text ()
  "The space-tree workspace lighter string."
  (zetta-tab-bar-workspace-lighter))

(defun zetta-tab-bar-spotify-icon ()
  "Spotify glyph, sits to the left of the spot mode-line string."
  (and (featurep 'nerd-icons)
       (zetta-line--glyph (ignore-errors (nerd-icons-faicon "nf-fa-spotify")))))

(defun zetta-tab-bar-emacs-icon ()
  "Emacs-logo glyph for the full-height tab-bar masthead, or nil."
  (and (featurep 'nerd-icons)
       (zetta-line--glyph (ignore-errors (nerd-icons-sucicon "nf-custom-emacs")))))

(defun zetta-tab-bar-mode-icon ()
  "Nerd-Font glyph for the (context) buffer's major mode, for the masthead.
Reflects the buffer the tab bar reports on -- the minibuffer entry buffer
during completion/preview (`zetta-tab-bar--context-buffer'), else the current
buffer -- so it does not flicker as previews swap buffers.  The masthead
recolours it via `zetta-tab-bar-svg-icon-color', so the raw glyph is returned."
  (when (featurep 'nerd-icons)
    (let ((buf (or (and (fboundp 'zetta-tab-bar--context-buffer)
                        (zetta-tab-bar--context-buffer))
                   (current-buffer))))
      (with-current-buffer buf
        (let ((g (ignore-errors (nerd-icons-icon-for-buffer))))
          (and (stringp g)
               (let ((s (substring-no-properties (string-trim g))))
                 (and (> (length s) 0) s))))))))

;;; tab-bar interactive (svg-only) wrappers
;; ----------------------------------------------------------------
;; The base tab-bar segments above are shared with the *text* `tab-bar-format'
;; fallback, so they must keep returning plain strings.  These wrappers add
;; click/hover/menu for the SVG tab bar only; `zetta-tab-bar-svg-lines' uses
;; them in place of the plain segments (and folds in adjacent glyph icons).

(defun zetta-tab-bar-svg--buffer ()
  "Clickable tab-bar buffer name (switch buffer; menu of buffer/file actions)."
  (zetta-svg-seg
   (zetta-buffer-name) 'tb-buffer
   :help (format "buffer: %s" (buffer-name))
   :action-help "switch buffer"
   :action (if (fboundp 'consult-buffer) #'consult-buffer #'switch-to-buffer)
   :menu (delq nil
               (list (cons "Switch buffer…" (if (fboundp 'consult-buffer)
                                                #'consult-buffer #'switch-to-buffer))
                     (cons "Find file…" #'find-file)
                     (and (fboundp 'consult-recent-file)
                          (cons "Recent files…" #'consult-recent-file))
                     (cons "Save buffer" #'save-buffer)))))

(defun zetta-tab-bar-modal-glyph ()
  "Nerd-Font glyph for the active modal SYSTEM: vim for evil, cat for meow,
the Emacs logo for emacs.  Falls back to the `zetta-tab-bar-modal' string when
nerd-icons or the glyph is unavailable."
  (or (and (featurep 'nerd-icons)
           (zetta-line--glyph
            (ignore-errors
              (pcase (zetta-tab-bar-modal)
                ("evil" (nerd-icons-sucicon "nf-custom-vim"))
                ("meow" (nerd-icons-mdicon  "nf-md-cat"))
                (_      (nerd-icons-sucicon "nf-custom-emacs"))))))
      (zetta-tab-bar-modal)))

(defun zetta-tab-bar-svg--modal ()
  "Clickable tab-bar modal-system indicator (vim/cat/Emacs glyph; describe bindings)."
  (zetta-svg-seg
   (zetta-tab-bar-modal-glyph) 'tb-modal
   :help (format "modal system: %s" (zetta-tab-bar-modal))
   :action-help "describe bindings"
   :action #'describe-bindings
   :menu (list (cons "Describe bindings" #'describe-bindings)
               (cons "Command (M-x)" #'execute-extended-command))))

(defun zetta-tab-bar--left-of-clock-chars ()
  "How many characters a line-3 LEFT segment may use before the centred clock.
Derived from the LIVE frame width and the tab bar's own geometry, so it
adapts to any screen width: the clock spans all three rows, centred at
WIDTH/2 with radius ~0.86*(3*LH)/2; the left content starts past the square
masthead (width = bar height); inline-segment rows lay out at
`zetta-tab-bar-svg-char-advance' px/char.  These mirror `svg-line''s internal
geometry -- keep in sync if its clock-radius/masthead formulas change."
  (let* ((width (frame-inner-width))
         (fz   (or (bound-and-true-p zetta-tab-bar-svg-font-size) 15))
         (lp   (or (bound-and-true-p zetta-tab-bar-svg-line-pad) 4))
         (lh   (+ fz lp))
         (rows 3)
         (height (* lh rows))                              ; full bar height
         (r    (round (* 0.86 (/ (float height) 2))))      ; clock radius
         (masthead (if (bound-and-true-p zetta-tab-bar-svg-icon) height 0))
         (gap  (* 2 fz))                                    ; breathing room
         (ca   (max 1 (or (bound-and-true-p zetta-tab-bar-svg-char-advance) 8)))
         ;; the bar's own left inset comes off the budget too, or the left
         ;; content is sized as though it still started at x=0 and runs that
         ;; many pixels closer to the centred clock than intended
         (pad  (or (bound-and-true-p zetta-tab-bar-svg-pad) 0))
         (avail (- (/ width 2) r masthead gap pad)))
    (max 0 (floor avail ca))))

(defun zetta-tab-bar-svg--spotify ()
  "Clickable Spotify cluster (glyph + spot string): play/pause; transport menu.
The track string is truncated so the cluster never reaches the centred clock,
at any frame width (see `zetta-tab-bar--left-of-clock-chars')."
  (let* ((icon (ignore-errors (zetta-tab-bar-spotify-icon)))
         (txt  (zetta-tab-bar-spot-mode-line-string))
         (prefix (if icon (concat icon " ") ""))
         (maxc (zetta-tab-bar--left-of-clock-chars))
         (budget (- maxc (length prefix)))
         (txt (cond
               ((or (null txt) (<= (length txt) budget)) txt)
               ((> budget 1) (concat (substring txt 0 (1- budget)) "…"))
               (t "")))                                     ; no room -> icon only
         (label (concat prefix txt)))
    (zetta-svg-seg
     label 'tb-spotify
     :help "Spotify"
     :action-help "pause/play"
     :action (cond ((fboundp 'spot-player-pause) #'spot-player-pause)
                   ((fboundp 'spot-player-play) #'spot-player-play)
                   (t #'ignore))
     :menu (delq nil
                 (list (and (fboundp 'spot-player-play) (cons "Play" #'spot-player-play))
                       (and (fboundp 'spot-player-pause) (cons "Pause" #'spot-player-pause))
                       (and (fboundp 'spot-player-next) (cons "Next" #'spot-player-next))
                       (and (fboundp 'spot-player-previous) (cons "Previous" #'spot-player-previous))
                       (and (fboundp 'spot-consult-search) (cons "Search…" #'spot-consult-search))
                       (and (fboundp 'spot-add-current-track-to-playlist)
                            (cons "Add to playlist…" #'spot-add-current-track-to-playlist)))))))

(defun zetta-tab-bar-svg--mu4e ()
  "Clickable mail cluster (glyph + counts): open mu4e; mail menu."
  (let* ((icon (ignore-errors (zetta-tab-bar-mu4e-icon)))
         (txt  (zetta-tab-bar-mu4e-text))
         (label (concat (and icon (concat icon " ")) txt)))
    (when (and label (> (length (string-trim label)) 0))
      (zetta-svg-seg
       label 'tb-mu4e
       :help "email (mu4e)"
       :action-help "open mail"
       :action (if (fboundp 'mu4e) #'mu4e #'ignore)
       :menu (delq nil
                   (list (and (fboundp 'mu4e) (cons "Open mu4e" #'mu4e))
                         (and (fboundp 'mu4e-update-mail-and-index)
                              (cons "Update mail"
                                    (lambda () (interactive) (mu4e-update-mail-and-index t))))
                         (and (fboundp 'mu4e-compose-new) (cons "Compose" #'mu4e-compose-new))))))))

(defun zetta-tab-bar-svg--elfeed ()
  "Clickable feed cluster (rss glyph + unread count): open elfeed; feeds menu.
Hidden until elfeed loads (the count cache is nil); the count comes from
`zetta-tab-bar--elfeed-unread', recomputed off-render on elfeed's hooks."
  (when (numberp zetta-tab-bar--elfeed-unread)
    (let* ((refreshing (and (fboundp 'elfeed-queue-count-total)
                            (ignore-errors (> (elfeed-queue-count-total) 0))))
           ;; While a pull is in flight show a sync glyph instead of the rss
           ;; glyph; `elfeed-queue-count-total' > 0 means curl fetches are
           ;; active, so this self-clears when the pull drains.
           (icon (and (featurep 'nerd-icons)
                      (zetta-line--glyph
                       (ignore-errors
                         (nerd-icons-mdicon (if refreshing "nf-md-sync" "nf-md-rss"))))))
           (new zetta-tab-bar--elfeed-new-count)
           (label (concat (and icon (concat icon " "))
                          (number-to-string zetta-tab-bar--elfeed-unread)
                          (when (> new 0) (format " +%d" new)))))
      (zetta-svg-seg
       label 'tb-elfeed
       :help (cond
              (refreshing (format "elfeed: refreshing… (%d unread)"
                                  zetta-tab-bar--elfeed-unread))
              ((> new 0) (format "elfeed: %d unread (+%d new this pull)"
                                 zetta-tab-bar--elfeed-unread new))
              (t (format "elfeed: %d unread" zetta-tab-bar--elfeed-unread)))
       :action-help "open elfeed"
       :action (if (fboundp 'elfeed) #'elfeed #'ignore)
       :menu (delq nil
                   (list (and (fboundp 'elfeed) (cons "Open elfeed" #'elfeed))
                         (and (fboundp 'elfeed-update)
                              (cons "Update feeds" #'elfeed-update))
                         (and (fboundp 'zetta-consult-elfeed)
                              (cons "Search entries" #'zetta-consult-elfeed))
                         (and (fboundp 'elfeed-protocol-fever-reinit)
                              (cons "Full resync (reinit)"
                                    #'elfeed-protocol-fever-reinit))))))))

(defun zetta-tab-bar-svg--clock ()
  "Clickable clock (clock glyph + time): world clock; calendar menu."
  (let* ((txt (zetta-tab-bar-clock))
         (icon (and (featurep 'nerd-icons)
                    (zetta-line--glyph (ignore-errors (nerd-icons-mdicon "nf-md-clock_outline"))))))
    (when (and txt (> (length (string-trim txt)) 0))
      (zetta-svg-seg
       (concat (and icon (concat icon " ")) txt) 'tb-clock
       :help "time"
       :action-help "world clock"
       :action (if (fboundp 'world-clock) #'world-clock #'display-time-world)
       :menu (delq nil
                   (list (and (fboundp 'world-clock) (cons "World clock" #'world-clock))
                         (cons "Calendar" #'calendar)
                         (and (fboundp 'org-agenda) (cons "Agenda" #'org-agenda))))))))

(defun zetta-tab-bar-svg--battery ()
  "Clickable battery cluster: a Font-Awesome battery glyph coloured by level
\(red/orange/green), a plug glyph when on AC, and the percentage.  Click shows
the full battery status."
  (when (bound-and-true-p display-battery-mode)
    (let ((d (zetta-tab-bar--battery-data)))
      (when d
        (let* ((pct (car d)) (plugged (cdr d))
               (batt (zetta-tab-bar--battery-fa-glyph pct))
               (plug (and plugged (featurep 'nerd-icons)
                          (zetta-line--glyph (ignore-errors (nerd-icons-faicon "nf-fa-plug")))))
               (label (concat (and plug (concat plug " "))
                              (and batt (concat batt " "))
                              (format "%d%%" pct))))
          (when (> (length (string-trim label)) 0)
            (zetta-svg-seg
             label 'tb-battery
             :color (zetta-tab-bar--battery-color pct)
             :help (format "battery: %d%%%s" pct (if plugged " (plugged in)" ""))
             :action-help "battery status"
             :action #'battery
             :menu (list (cons "Battery status" #'battery)
                         (cons "Toggle battery display" #'display-battery-mode)))))))))

(defcustom zetta-tab-bar-svg-active-space-color nil
  "Colour for the active (selected) space-tree space in the tab-bar workspace.
Replaces space-tree's trailing-apostrophe marker.  nil -- the default --
uses the theme's accent colour instead of a fixed purple."
  :type 'color :group 'zetta)

(defcustom zetta-tab-bar-svg-inactive-space-color nil
  "Colour for the non-active tokens (spaces, braces, level bars) of the
tab-bar workspace cluster.  nil -- the default -- dims the theme foreground
toward the background, so it recedes on light AND dark themes rather than
only against a white bar."
  :type 'color :group 'zetta)

(defun zetta-tab-bar-svg--workspace ()
  "Clickable workspace cluster (glyph + spaces) for the SVG tab bar.
space-tree's lighter marks each level's selected space with a trailing
apostrophe; we render those labels in `zetta-tab-bar-svg-active-space-color'
and drop the apostrophe, since svg-line colours per-segment, not per-character.

We split on whitespace into one segment per token (space label / brace / level
bar), separators included as their own segments.  Those boundaries don't move
as you cycle spaces -- dropping the apostrophe keeps every token's width fixed,
so only one token's colour changes.  A shifting split point would instead jitter
its neighbours: svg-line starts each run on a fixed char-advance grid but flows
text by the font's natural advance within a run, so where that boundary lands
matters.  Every piece shares one hover id and the workspace action/menu, so the
cluster still behaves as one clickable unit."
  (let* ((icon (ignore-errors (zetta-tab-bar-workspace-icon)))
         (txt  (zetta-tab-bar-workspace-text)))
    (when (and (stringp txt) (> (length (string-trim txt)) 0))
      (let* ((action (cond ((fboundp 'space-tree-switch-space-by-name) #'space-tree-switch-space-by-name)
                           ((fboundp 'space-tree-switch-current-level) #'space-tree-switch-current-level)
                           (t #'ignore)))
             (menu (delq nil
                         (list (and (fboundp 'space-tree-switch-space-by-name)
                                    (cons "Switch by name…" #'space-tree-switch-space-by-name))
                               (and (fboundp 'space-tree-go-left) (cons "Previous space" #'space-tree-go-left))
                               (and (fboundp 'space-tree-go-right) (cons "Next space" #'space-tree-go-right))
                               (and (fboundp 'space-tree-create-space-current-level)
                                    (cons "New space (here)" #'space-tree-create-space-current-level))
                               (and (fboundp 'space-tree-create-space-top-level)
                                    (cons "New space (top)" #'space-tree-create-space-top-level))
                               (and (fboundp 'space-tree-name-current-space)
                                    (cons "Rename space…" #'space-tree-name-current-space))
                               (and (fboundp 'space-tree-delete-space)
                                    (cons "Delete space" #'space-tree-delete-space)))))
             (mkseg (lambda (s color)
                      (and (stringp s) (> (length s) 0)
                           (apply #'zetta-svg-seg s 'tb-workspace
                                  :help "workspace" :action-help "switch workspace"
                                  :action action :menu menu
                                  (and color (list :color color))))))
             (items (list (funcall mkseg (and icon (concat icon " ")) nil)))
             (first t))
        ;; One segment per whitespace-delimited token, with a fixed " " segment
        ;; between them.  A token ending in "'" is the selected space: strip the
        ;; apostrophe and colour it.  Boundaries stay put as the selection moves.
        (dolist (tok (split-string (string-trim txt) " " t))
          (unless first (push (funcall mkseg " " nil) items))
          (setq first nil)
          (let ((active (string-suffix-p "'" tok)))
            (push (funcall mkseg (if active (substring tok 0 -1) tok)
                           (if active
                               (or zetta-tab-bar-svg-active-space-color
                                   (zetta-theme-color 'accent))
                             (or zetta-tab-bar-svg-inactive-space-color
                                 (zetta-svg-line--dim
                                  (or (bound-and-true-p brushup-fg-3)
                                      (face-foreground 'default nil t) "#cccccc")
                                  0.5))))
                  items)))
        (apply #'svg-line-segs (nreverse (delq nil items)))))))


;;; ------------------------------------------------------------------
;;; SVG line palette -- derived from the live theme via brushup
;;; ------------------------------------------------------------------
;; The tab line, tab bar and mode line shipped a fixed purple/lavender
;; palette.  Those hexes only read on a light theme: on a dark one the SVG
;; furniture stayed pale and glowed against the buffer.  Derive them from
;; brushup instead, which tracks the live theme's foreground/background, so
;; the same relationships hold in either direction.
;;
;; Two families, used deliberately:
;;
;;   brushup-bg-1..6  step from the background toward the foreground.  With
;;                    a neutral theme background these are true greys, so
;;                    they carry the chrome (strips, inactive tabs).
;;   brushup-fg-1..6  step from the foreground toward the background, and
;;                    therefore invert with the theme.  Used only where an
;;                    element must read as "selected" -- dark on a light
;;                    theme, light on a dark one -- which is what the purple
;;                    was doing.
;;
;; No colour conversion is needed here: svg-line pushes every colour through
;; `svg-line--color', which normalizes brushup's 48-bit values
;; ("#57c071477e0a") down to the "#rrggbb" an SVG can parse.
;;
;; The amber "modified" markers are deliberately left alone.  They are the
;; only accent in the design and they carry meaning rather than decoration.

(defun zetta-fontaine--short-name (preset)
  "PRESET as a compact label.
Generated presets are named after their family and get long -- trim the
Nerd Font boilerplate that every one of them repeats."
  (when preset
    (let ((name (symbol-name preset)))
      (setq name (replace-regexp-in-string "-nerd-font\\(-mono\\|-propo\\)?\\'" "" name))
      (setq name (replace-regexp-in-string "\\`monaspace-" "mona-" name))
      name)))

(defun zetta-line-blend (color toward factor)
  "Blend COLOR TOWARD another colour by FACTOR (0.0-1.0).
Returns COLOR unchanged if either name cannot be parsed."
  (if-let* ((c (color-name-to-rgb color))
            (b (color-name-to-rgb toward)))
      (apply #'color-rgb-to-hex
             (append (cl-mapcar (lambda (x y) (+ (* x (- 1.0 factor)) (* y factor)))
                                c b)
                     (list 2)))
    color))

(defun zetta-svg-line--dim (color factor)
  "Blend COLOR toward the theme background by FACTOR (0.0-1.0).

Stepping down the brushup foreground gradient is not enough for this: two
adjacent steps differ by a few percent and read as the same colour in a
small SVG label.  Blending toward the background gives a separation that
holds up whatever the theme is."
  (zetta-line-blend color (or (bound-and-true-p brushup-bg)
                              (face-background 'default nil t) "#000000")
                    factor))

(defun zetta-tab-bar-font-preset ()
  "The active global fontaine preset, for the tab bar."
  (when-let* ((preset (bound-and-true-p fontaine-current-preset)))
    (svg-line-seg
     (concat "6 " (zetta-fontaine--short-name preset))
     :id 'zetta-font-preset-global
     :help (format "Global font preset: %s" preset)
     :action (and (fboundp 'zetta-fontaine-pick-preset)
                  #'zetta-fontaine-pick-preset)
     :action-help "click to change the font preset")))
(defun zetta-header-line-font-preset ()
  "The font preset in force for this buffer, for the right of the header line.

Always shows something, so a blank right-hand side never has to be
interpreted -- it would otherwise be ambiguous between \"this buffer follows
the global preset\" and \"the segment is broken\".

A buffer-local override is drawn in the normal foreground; an inherited
global preset is dimmed, so the distinction that actually matters -- is this
buffer doing something different? -- still reads at a glance.  Click either
to change it."
  (let* ((local (bound-and-true-p zetta-fontaine--buffer-preset))
         (preset (or local (bound-and-true-p fontaine-current-preset))))
    (when preset
      (svg-line-seg
       (concat "6 " (zetta-fontaine--short-name preset))
       :id 'zetta-font-preset
       :color (unless local
                (zetta-svg-line--dim
                 (or (bound-and-true-p brushup-fg-3)
                     (face-foreground 'default nil t) "#cccccc")
                 0.55))
       :help (if local
                 (format "Buffer-local font preset: %s" preset)
               (format "Following the global preset: %s" preset))
       ;; This segment is per-BUFFER, so it opens the per-mode picker when
       ;; the mode has presets offered for it, and only falls back to the
       ;; global one when it does not.  The tab-bar twin stays global --
       ;; that is the frame-wide reading of the same information.
       :action (if (and (fboundp 'zetta-fontaine-pick-mode-preset)
                        (fboundp 'zetta-fontaine--mode-entry)
                        (zetta-fontaine--mode-entry))
                   #'zetta-fontaine-pick-mode-preset
                 (and (fboundp 'zetta-fontaine-pick-preset)
                      #'zetta-fontaine-pick-preset))
       :action-help (if (and (fboundp 'zetta-fontaine--mode-entry)
                             (zetta-fontaine--mode-entry))
                        "click to change this mode's font preset"
                      "click to change the font preset")))))
(defun zetta-svg-line--px-per-char (family height)
  "Advance of FAMILY at face HEIGHT, in pixels per character.

Divides out any `face-font-rescale-alist' entry for FAMILY.  That matters
because the two consumers disagree: the SVG chrome is drawn by librsvg via
fontconfig, which never sees `face-font-rescale-alist', while
`string-pixel-width' measures Emacs rendering, which does.  The chrome font
is usually also a buffer fallback and therefore rescaled -- Terminess sat
at 0.87 to fit inside Monaspace's box -- so measuring it naively reported
7px/char when librsvg was still drawing it at 8, and every SVG line was
laid out one pixel per character too narrow."
  (let* ((probe (make-string 20 ?M))
         (measured (/ (float (string-pixel-width
                              (propertize probe 'face (list :family family :height height))))
                      20))
         (scale (or (cdr (assoc family face-font-rescale-alist)) 1.0)))
    (if (> scale 0) (/ measured scale) measured)))

(defvar zetta-svg-line-uniform-fallback "Terminess Nerd Font Mono"
  "Chrome font used when the requested one advances icons and text differently.")

(defvar zetta-svg-line-icon-probes
  '(#xE0A0    ; Powerline branch
    #xE5FF    ; Seti-UI
    #xF00C    ; Font Awesome
    #xF07C9   ; folder
    #xF0614)  ; Material Design -- the tmux status bar and masthead icons
  "Nerd Font codepoints spanning the ranges the SVG chrome actually draws.
A chrome font must contain all of them.")

(defun zetta-svg-line--has-icons-p (family)
  "Non-nil when FAMILY itself contains every glyph in `zetta-svg-line-icon-probes'.

Measuring advance alone is not enough.  A font with NO Nerd glyphs still
measures \"uniform\", because the probe falls through to whatever the
fontset substitutes and that font\='s advance may coincidentally match the
text -- which is how the Ark Pixel families were being offered as chrome
fonts despite carrying no icons at all.  They do have U+E0A0, so one probe
was not enough either; the set spans several ranges."
  (ignore-errors
    (when-let* ((spec (find-font (font-spec :family family :size 15)))
                (obj (open-font spec)))
      (seq-every-p (lambda (cp) (font-has-char-p obj cp))
                   zetta-svg-line-icon-probes))))

(defun zetta-svg-line--uniform-advance-p (family)
  "Non-nil when FAMILY can drive the SVG chrome.

Two conditions, and both matter:

1. FAMILY must actually CONTAIN the Nerd glyphs.  Advance alone is not
   enough -- a font with no icons still measures \"uniform\", because the
   probe falls through to whatever the fontset substitutes and that
   font\='s advance may coincidentally match.  That is how the Ark Pixel
   families were being offered as chrome fonts while carrying none of
   the icons the tab bar draws.

2. It must advance those icons exactly as it advances text.  The SVG
   renderers place both on ONE grid, so a font whose icons sit on a
   different advance cannot be laid out correctly at any single value.

The rescale factor is divided out of BOTH measurements; correcting only
the text advance makes any rescaled family read as a false negative."
  (and
   (zetta-svg-line--has-icons-p family)
   (let* ((scale (or (cdr (assoc family face-font-rescale-alist)) 1.0))
          (scale (if (> scale 0) scale 1.0))
          (tx (zetta-svg-line--px-per-char family 150))
          (ic (/ (/ (float (string-pixel-width
                            (propertize (make-string 10 #xF0614) 'face
                                        (list :family family :height 150))))
                    10)
                 scale)))
     (= (round tx) (round ic)))))

(defun zetta-svg-line-derive-char-advance ()
  "Set each SVG line's :char-advance from the font it actually draws with.

The renderers lay text out on a fixed pixels-per-character grid.  That
number was hardcoded to 8 in all four of them, and 8 is Terminus's
advance -- measured, at face height 150, Terminus and Terminess come to
exactly 8.00 px/char while every Monaspace family is 9.00.  So under any
other font the computed boxes are too narrow and the tab line, tab bar,
mode line and masthead clip and overlap.

The SVG `font-size' is in px and corresponds to a face height ten times
larger, so the advance is measured at (* 10 font-size) for whichever
family `zetta-svg-line-font' currently names."
  (let ((family (or (bound-and-true-p zetta-svg-line-font)
                    (face-attribute 'default :family nil 'default))))
    ;; Refuse a chrome font whose icons and text disagree -- see
    ;; `zetta-svg-line--uniform-advance-p'.
    (when (and family (seq-some #'display-graphic-p (frame-list))
               (not (zetta-svg-line--uniform-advance-p family)))
      (message "zetta: %s advances icons and text differently; chrome font -> %s"
               family zetta-svg-line-uniform-fallback)
      (setq family zetta-svg-line-uniform-fallback
            zetta-svg-line-font zetta-svg-line-uniform-fallback))
    ;; `display-graphic-p' with no argument asks the SELECTED frame, which
    ;; is not graphical in a daemon at startup -- check the frame list.
    (when (and family (seq-some #'display-graphic-p (frame-list)))
      (dolist (pair '((zetta-tab-bar-svg-char-advance      . zetta-tab-bar-svg-font-size)
                      (zetta-tab-line-svg-char-advance     . zetta-tab-line-svg-font-size)
                      (zetta-modeline-svg-char-advance     . zetta-modeline-svg-font-size)
                      (zetta-header-line-svg-char-advance  . zetta-header-line-svg-font-size)))
        (when (and (boundp (car pair)) (boundp (cdr pair)))
          (set (car pair)
               (max 1 (round (zetta-svg-line--px-per-char
                              family (* 10 (symbol-value (cdr pair))))))))))))

(defcustom zetta-svg-line-debug-tints
  '(:tab-bar     "#f6c9c9"
    :header-line "#c9e6c9"
    :tab-line    "#c9d4f6"
    :mode-line   "#f6e2b8")
  "Per-bar backgrounds used by `zetta-svg-line-debug-backgrounds\='.

Deliberately NOT derived from the theme.  Every other colour in the chrome
is, which is the point of the debug view: these four have to stay mutually
distinguishable and obviously foreign, so that what you are looking at is
each bar\='s geometry rather than its styling.  Each bar\='s inactive variant,
where it has one, is taken a step toward the background from these."
  :type 'plist :group 'zetta)

(defvar zetta-svg-line-debug-backgrounds nil
  "Non-nil while the SVG bars are painted their `zetta-svg-line-debug-tints\='.
Read by `zetta-svg-line-apply-brushup-palette\=', so the tints are re-applied
on a theme change rather than being silently reset to nil by it.")

(defun zetta-svg-line--bar-bg (bar)
  "Background for BAR (`:tab-bar\=' `:header-line\=' `:tab-line\=' `:mode-line\=').
nil unless `zetta-svg-line-debug-backgrounds\=' is on."
  (and zetta-svg-line-debug-backgrounds
       (plist-get zetta-svg-line-debug-tints bar)))

;;;###autoload
(defun zetta-svg-line-debug-backgrounds (&optional arg)
  "Toggle a distinct flat background behind each SVG bar.

The bars are normally transparent, which makes their EXTENTS invisible --
you can see the content but not where the image starts and stops, so
padding, insets and off-by-one geometry are impossible to eyeball.  This
paints each of the tab bar, header line, tab line and mode line its own
colour; the background rect covers the whole image, padding included, so
what you see is the real footprint of each bar.

With ARG, turn on if positive, off otherwise.  Toggle it back off when
done -- this is a measuring tool, not a look."
  (interactive "P")
  (setq zetta-svg-line-debug-backgrounds
        (if arg (> (prefix-numeric-value arg) 0)
          (not zetta-svg-line-debug-backgrounds)))
  (zetta-svg-line-apply-brushup-palette)
  (force-mode-line-update t)
  (message "svg-line debug backgrounds %s"
           (if zetta-svg-line-debug-backgrounds "ON" "off")))

(defun zetta-svg-line-apply-brushup-palette ()
  "Re-derive the SVG tab-line, tab-bar and mode-line colours from brushup.
Registered on `brushup-styles', so it re-runs on every theme change.
Each assignment is guarded: the module owning the variable may not have
loaded yet, and a missing one should simply keep its default."
  (when (boundp 'brushup-bg)
    (cl-flet ((setc (sym val) (when (boundp sym) (set sym val))))
      ;; --- tab line -----------------------------------------------------
      ;; No bar: the strip is transparent and the `tab-line' face background
      ;; (brushup paints it to `brushup-bg') shows through, so only the tab
      ;; pills are visible.  That means the pills carry the entire
      ;; selected/unselected distinction, and they are laid out on ONE
      ;; ladder -- brushup-bg-1 .. bg-6 then fg-6 .. fg-1 run monotonically
      ;; from "same as the buffer background" to "same as the buffer text",
      ;; on a dark theme as on a light one.  Every unfocused element sits
      ;; strictly lower on that ladder than its focused counterpart, so no
      ;; unfocused window can ever read as more present than the focused one.
      ;; The tab line is the one bar that keeps a background: a whisper of a
      ;; tint marking where each window begins.  Same value in unselected
      ;; windows -- it is structure, not a focus cue, and the pills already
      ;; carry the selected/unselected distinction.  The debug tint, when on,
      ;; overrides it.
      (let* ((strength (or (bound-and-true-p zetta-tab-line-svg-tint) 0))
             ;; zero means NO rect, not a rect in the page colour -- the frame
             ;; is translucent, so the latter is a visible block
             (faint (and (> strength 0)
                         (zetta-line-blend brushup-bg brushup-fg strength))))
        (setc 'zetta-tab-line-svg-background
              (or (zetta-svg-line--bar-bg :tab-line) faint))
        (setc 'zetta-tab-line-svg-inactive-background
              (or (when-let* ((c (zetta-svg-line--bar-bg :tab-line)))
                    (zetta-svg-line--dim c 0.45))
                  faint)))
      ;; selected window: a soft chip under ordinary tabs, dark text on it,
      ;; and an INVERTED pill under the current tab.
      ;; Measured against a TRANSPARENT bar.  If `zetta-tab-line-svg-tint' is
      ;; ever turned back on, every one of these has to move up a rung: with a
      ;; tint behind them, bg-1 pills measured 1.05:1 against the bar --
      ;; invisible -- and the labels followed them down.
      (setc 'zetta-tab-line-svg-tab-background            brushup-bg-2)
      (setc 'zetta-tab-line-svg-modified-background       brushup-bg-2)
      ;; Labels move up with the pills they sit on.  Measured on a dark theme
      ;; after the shift: fg-3 on the old bg-2 pill read 6:1, but on bg-3 only
      ;; 3.3 -- so the label steps too, keeping the selected window's tabs
      ;; comfortably ahead of the unselected ones rather than both sliding
      ;; toward mush.
      (setc 'zetta-tab-line-svg-foreground                brushup-fg-3)
      ;; The current tab is the one element that inverts, so its foreground
      ;; cannot be assumed to be the background colour: on a light theme with
      ;; a strongly tinted background, `brushup-bg' on `brushup-fg-1' can land
      ;; well under a readable ratio.  Ask which of fg/bg actually reads.
      (setc 'zetta-tab-line-svg-current-background        brushup-fg-1)
      (setc 'zetta-tab-line-svg-current-foreground        (zetta-readable-on brushup-fg-1))
      ;; unselected windows: every element one or more rungs down.  Note nil
      ;; is not available here -- svg-line reads an unset inactive colour as
      ;; "use the active one" -- so "no chip" is expressed as the faintest
      ;; chip the ladder has (bg-1, one step off the buffer background).
      (setc 'zetta-tab-line-svg-inactive-tab-background   brushup-bg-1)
      (setc 'zetta-tab-line-svg-inactive-modified-background brushup-bg-1)
      (setc 'zetta-tab-line-svg-inactive-foreground       brushup-fg-6)
      (setc 'zetta-tab-line-svg-inactive-current-background brushup-bg-3)
      (setc 'zetta-tab-line-svg-inactive-current-foreground
            (zetta-svg-line--dim (zetta-readable-on brushup-bg-3) 0.2))
      ;; The "unsaved changes" amber is the one non-grey in the tab line.
      ;; Take it from the theme when it actually reads against the tab pill,
      ;; so a dark theme is not left with the light-theme amber; keep the
      ;; hardcoded default when the theme's warning colour would not.
      (let ((warn (zetta-theme-color 'warning)))
        (when (and (stringp warn)
                   (> (zetta-contrast-ratio warn brushup-bg-2) 3.0))
          (setc 'zetta-tab-line-svg-modified-foreground warn)
          (setc 'zetta-tab-line-svg-inactive-modified-foreground
                (zetta-svg-line--dim warn 0.4))))
      ;; --- tab bar ------------------------------------------------------
      (setc 'zetta-tab-bar-svg-icon-color                 brushup-fg-3)
      (setc 'zetta-tab-bar-calendar-color                 brushup-fg-5)
      ;; --- mode line ----------------------------------------------------
      ;; Also bar-less.  What is left to tell the windows apart is the text
      ;; itself, so it takes the same two rungs the tab labels do; the buffer
      ;; chip, the accent badges and the progress pie step down alongside it
      ;; (see `zetta-modeline--lighter-bg', `zetta-line-chip-ladder' and
      ;; `zetta-modeline-svg-spans').
      (setc 'zetta-modeline-svg-bg-active           (zetta-svg-line--bar-bg :mode-line))
      (setc 'zetta-modeline-svg-bg-inactive
            (when-let* ((c (zetta-svg-line--bar-bg :mode-line)))
              (zetta-svg-line--dim c 0.45)))
      (setc 'zetta-header-line-svg-background       (zetta-svg-line--bar-bg :header-line))
      (setc 'zetta-tab-bar-svg-background           (zetta-svg-line--bar-bg :tab-bar))
      (setc 'zetta-modeline-svg-fg-active                 brushup-fg-3)
      (setc 'zetta-modeline-svg-fg-inactive               brushup-fg-6)
      ;; The progress pie is the one thing on the line drawn at FULL ink -- it
      ;; is a shape rather than a word, so it can carry the theme foreground
      ;; without competing with text the way a darker label would.  The ink is
      ;; in the one-pixel RING, which states the shape; the wedge inside only
      ;; has to say how far along it is, so it sits on the background ladder.
      (setc 'zetta-modeline-svg-pie-ring                  brushup-fg)
      (setc 'zetta-modeline-svg-pie-fill                  brushup-bg-3))))

;; Appended, not prepended: `add-to-list' pushes to the front, and
;; `brushup-init' -- which recomputes the palette -- already sits near the
;; end of `brushup-styles'.  A prepended style would therefore read the
;; PREVIOUS theme's colours and land one theme change behind.
(with-eval-after-load 'brushup
  (add-to-list 'brushup-styles '(zetta-svg-line-apply-brushup-palette) t))

;; brushup-mode runs `brushup' from the bootstrap, before these modules are
;; loaded, so the registration above misses that first pass.  Apply once
;; more after startup settles.
(add-hook (if (boundp 'elpaca-after-init-hook) 'elpaca-after-init-hook 'after-init-hook)
          #'zetta-svg-line-apply-brushup-palette)
(add-hook (if (boundp 'elpaca-after-init-hook) 'elpaca-after-init-hook 'after-init-hook)
          #'zetta-svg-line-derive-char-advance)

;;; line-utils.el ends here
