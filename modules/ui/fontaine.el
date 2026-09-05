;;; fontaine.el --- Configure fontaine (font presets) -*- lexical-binding: t; -*-

;; Fontaine sets font family/height/weight per face and remembers the last
;; preset across restarts.  Two things it fixes here beyond switching fonts:
;;
;;   `fixed-pitch' and `variable-pitch' were never set, so they resolved to
;;   Emacs's generic "Monospace"/"Sans Serif" aliases -- a different family
;;   from `default' (Terminus).  Any theme that leans on those faces then
;;   renders in two fonts at once; doric-themes pins 25 faces to
;;   `fixed-pitch', which is where that seam shows up.
;;
;;   It gives a single place to declare the font, instead of the
;;   `default-frame-alist' + `set-face-attribute' pair in core/interface.el.

(defun zetta-fontaine-uniform (family &rest overrides)
  "Preset properties putting FAMILY on every face fontaine manages.

For the common case -- \"just use this font everywhere\" -- so a new font
is one line instead of fourteen `:x-family\=' pairs:

  (berkeley . ,(zetta-fontaine-uniform \"Berkeley Mono\" :default-height 160))

OVERRIDES are spliced in FRONT of the generated defaults.  Fontaine reads
presets with `plist-get\=', which returns the FIRST match, so anything given
here wins over the uniform value.

A function rather than a macro on purpose: this only builds a list at load
time.  There is no evaluation to control and no new syntax to introduce, so
a macro would buy nothing and cost debuggability.

`:svg-line-family\=' deliberately does NOT default to FAMILY.  The SVG chrome
needs a font that advances Nerd icons and text identically, and almost
nothing does -- see FONTS.org.  It defaults to the known-good Terminess;
pass your own if you have checked it with
`zetta-svg-line--uniform-advance-p\='."
  (append
   overrides
   (list :default-family family
         :fixed-pitch-family family
         :fixed-pitch-serif-family family
         :variable-pitch-family family
         :mode-line-active-family family
         :mode-line-inactive-family family
         :header-line-family family
         :line-number-family family
         :tab-bar-family family
         :tab-line-family family
         :bold-family family
         :italic-family family
         :default-height 160
         :variable-pitch-height 1.0
         :svg-line-family "Terminess Nerd Font Mono")))

(defvar zetta-fontaine-curated-presets nil
  "Hand-written presets.  Generated per-font presets are appended to these.")

(defvar zetta-fontaine-generated-presets nil
  "Presets generated from installed font families by
`zetta-fontaine-refresh-font-presets\='.")

(defvar zetta-fontaine-generate-height 160
  "`:default-height\=' given to every generated preset.")

(defun zetta-fontaine--monospace-p (family)
  "Non-nil when FAMILY advances a narrow and a wide glyph identically.
Proportional families are excluded from generation: this config's whole
metric apparatus -- terminal grids, box-drawing alignment, the SVG chrome
-- assumes a fixed cell."
  (ignore-errors
    (let ((narrow (string-pixel-width
                   (propertize (make-string 8 ?i) 'face (list :family family :height 150))))
          (wide (string-pixel-width
                 (propertize (make-string 8 ?M) 'face (list :family family :height 150)))))
      (and (> narrow 0) (= narrow wide)))))

(defun zetta-fontaine--preset-name (family)
  "Symbol naming the generated preset for FAMILY."
  (intern (downcase (replace-regexp-in-string "[^A-Za-z0-9]+" "-" family))))

(defun zetta-fontaine-generate-font-presets ()
  "Build a uniform preset for every installed monospaced family.

Each gets its own family on all faces.  `:svg-line-family\=' is the family
itself only when it advances Nerd icons like text; otherwise it falls back
to Terminess, because the SVG chrome cannot be laid out on a font whose
icons sit on a different advance -- see FONTS.org.

Skips names already taken by `zetta-fontaine-curated-presets\=', so a
hand-tuned preset always wins over a generated one."
  (let ((taken (mapcar #'car zetta-fontaine-curated-presets))
        (result nil))
    (dolist (family (font-family-list))
      (let ((name (zetta-fontaine--preset-name family)))
        (when (and (not (memq name taken))
                   (not (assq name result))
                   (zetta-fontaine--monospace-p family))
          (push (cons name
                      (apply #'zetta-fontaine-uniform family
                             (append
                              (list :default-height zetta-fontaine-generate-height)
                              (when (ignore-errors
                                      (zetta-svg-line--uniform-advance-p family))
                                (list :svg-line-family family)))))
                result))))
    (nreverse result)))

;;;###autoload
(defun zetta-fontaine-refresh-font-presets ()
  "Regenerate a fontaine preset for every installed monospaced font.
Run after installing or removing fonts.  Curated presets are preserved and
always take precedence over a generated one of the same name."
  (interactive)
  (unless (seq-some #'display-graphic-p (frame-list))
    (user-error "Font measurement needs a graphical frame"))
  ;; Emacs will not see newly installed families until its font cache is
  ;; dropped, and `clear-font-cache' is not a command -- so do it here and
  ;; make this the one thing to run after installing fonts.
  (clear-font-cache)
  (setq zetta-fontaine-generated-presets (zetta-fontaine-generate-font-presets))
  ;; the `t' entry is fontaine's fallback and must come last
  (let* ((fallback (assq t zetta-fontaine-curated-presets))
         (curated (assq-delete-all t (copy-alist zetta-fontaine-curated-presets))))
    (setq fontaine-presets
          (append curated zetta-fontaine-generated-presets
                  (when fallback (list fallback)))))
  ;; Dropping the font cache re-realizes faces, which loses the font
  ;; fontaine had set; and new families change which one the fontset picks
  ;; for a fallback glyph, so the metric corrections need re-deriving.  The
  ;; sync does both -- forced, since the signature has not changed.
  (when (fboundp 'zetta-fontaine--sync)
    (setq zetta-font--last-signature nil)
    (zetta-fontaine--sync))
  (when (called-interactively-p 'interactive)
    (message "fontaine: %d curated + %d generated presets (%d can drive the chrome)"
             (length zetta-fontaine-curated-presets)
             (length zetta-fontaine-generated-presets)
             (seq-count (lambda (p)
                          (not (equal (plist-get (cdr p) :svg-line-family)
                                      "Terminess Nerd Font Mono")))
                        zetta-fontaine-generated-presets)))
  fontaine-presets)

(use-package fontaine
  :ensure (fontaine :host github :repo "protesilaos/fontaine")
  :demand t
  :init
  (setq fontaine-latest-state-file
        (locate-user-emacs-file "fontaine-latest-state.eld"))

  ;; Monaspace's five families are metrically compatible by design, so they
  ;; can be mixed in one frame without breaking column alignment.  The NF
  ;; builds are the upstream ones (Monaspace ships its own since v1.2), and
  ;; register as "Monaspace <Family> NF".
  ;;
  ;; Note the metrics differ from Terminus: Monaspace is ascent 11/descent 4
  ;; at size 16 against Terminus's 13/4, so the same :height reads smaller.
  ;; The Monaspace presets compensate with a larger height.
  ;; Every preset names ALL the families it cares about.  Fontaine leaves
  ;; attributes a preset does not mention untouched, so a partial preset
  ;; means switching back from `monaspace-mixed' would strand the mode line
  ;; and header line on Monaspace.
  ;;
  ;; `:svg-line-family' stays on Terminess for every preset, and that is not
  ;; laziness.  The SVG renderers lay icons and text on ONE fixed grid, so
  ;; the chrome font must advance both identically.  Measured at height 150:
  ;;
  ;;   Terminess Nerd Font Mono      text 8.0   icons 8.0   uniform
  ;;   Monaspace Krypton NF          text 9.0   icons 8.0
  ;;   MonaspiceKr Nerd Font Mono    text 9.0   icons 8.0   (nerd-fonts build)
  ;;
  ;; Nerd glyphs are drawn on a fixed 8px design grid; Terminus-derived fonts
  ;; work only because their text is also 8px.  No Monaspace-derived build is
  ;; uniform -- not even the "Mono" variant -- so pointing the chrome at one
  ;; makes every icon under-fill its cell and the masthead, tab line and mode
  ;; line drift and overlap.
  ;;
  ;; `:svg-line-family' is not a fontaine property.  Fontaine merges presets
  ;; with plain `plist-get', so unknown keys pass through untouched and can
  ;; be read back with `fontaine--get-preset-property'.  It exists because
  ;; the mode line, tab bar, tab line and header line are SVG IMAGES drawn
  ;; with `zetta-svg-line-font' -- not text in those faces -- so fontaine's
  ;; :mode-line-active-family and friends have no effect on them.
  (setq zetta-fontaine-curated-presets
        `((terminus
           :default-family "Terminus (TTF)"
           :default-height 160
           :fixed-pitch-family "Terminus (TTF)"
           :variable-pitch-family "Helvetica Neue"
           :variable-pitch-height 1.0
           :mode-line-active-family "Terminus (TTF)"
           :mode-line-inactive-family "Terminus (TTF)"
           :header-line-family "Terminus (TTF)"
           :tab-bar-family "Terminus (TTF)"
           :tab-line-family "Terminus (TTF)"
           :line-number-family "Terminus (TTF)"
           :italic-family "Terminus (TTF)"
           :bold-family "Terminus (TTF)"
           :svg-line-family "Terminess Nerd Font Mono")

          ;; One family throughout -- the conservative Monaspace preset.
          (monaspace
           :default-family "Monaspace Neon NF"
           :default-height 170
           :fixed-pitch-family "Monaspace Neon NF"
           :variable-pitch-family "Monaspace Argon NF"
           :variable-pitch-height 1.0
           :mode-line-active-family "Monaspace Neon NF"
           :mode-line-inactive-family "Monaspace Neon NF"
           :header-line-family "Monaspace Neon NF"
           :tab-bar-family "Monaspace Neon NF"
           :tab-line-family "Monaspace Neon NF"
           :line-number-family "Monaspace Neon NF"
           :italic-family "Monaspace Neon NF"
           :bold-family "Monaspace Neon NF"
           :svg-line-family "Terminess Nerd Font Mono")

          ;; The reason to run a superfamily: the five are metrically
          ;; compatible, so different families can carry different roles
          ;; without leaving the grid.
          ;;   Neon    neo-grotesque -- code
          ;;   Argon   humanist      -- prose / variable-pitch
          ;;   Xenon   slab serif    -- header line
          ;;   Krypton mechanical    -- chrome (and the SVG lines)
          ;;   Radon   handwriting   -- unused here; see :italic-family below
          (monaspace-mixed
           :default-family "Monaspace Neon NF"
           :default-height 170
           :fixed-pitch-family "Monaspace Neon NF"
           :variable-pitch-family "Monaspace Argon NF"
           :variable-pitch-height 1.0
           :header-line-family "Monaspace Xenon NF"
           :mode-line-active-family "Monaspace Krypton NF"
           :mode-line-inactive-family "Monaspace Krypton NF"
           :tab-bar-family "Monaspace Krypton NF"
           :tab-line-family "Monaspace Krypton NF"
           :line-number-family "Monaspace Neon NF"
           ;; Neon's own italic cut, not Radon.  Radon made sense while
           ;; `brushup--normalize-fonts' was stripping :slant from every face
           ;; -- family was then the ONLY way emphasis could read differently.
           ;; With genuine italics restored, matching the body font is the
           ;; conventional choice.  Swap in "Monaspace Radon NF" for slanted
           ;; handwriting instead.
           :italic-family "Monaspace Neon NF"
           :bold-family "Monaspace Neon NF"
           :svg-line-family "Terminess Nerd Font Mono")

          ;; Prose-leaning, for org.  Argon is the humanist face; Neon stays
          ;; on `fixed-pitch' so source blocks and tables keep the same
          ;; texture as code buffers.  Both are Monaspace, so they are
          ;; metrically compatible and tables still line up.
          ;;
          ;; Every grid role here used to be "Terminus (TTF)", which is what
          ;; the paragraph above was already describing as Neon -- the values
          ;; had drifted from the rationale.  Terminus is not metrically
          ;; compatible with Monaspace at all: measured at size 17 the five
          ;; Monaspace faces are identical (h15 asc11 desc4, 7px cell) while
          ;; Terminus is h13 asc10 desc3 on a 6px cell, so a table or src
          ;; block sat on a different grid from the prose around it.
          (monaspace-prose
           :default-family "Monaspace Argon NF"
           :default-height 170
           :fixed-pitch-family "Monaspace Neon NF"
           :variable-pitch-family "Monaspace Argon NF"
           :variable-pitch-height 1.0
           :header-line-family "Monaspace Xenon NF"
           :mode-line-active-family "Monaspace Argon NF"
           :mode-line-inactive-family "Monaspace Argon NF"
           :tab-bar-family "Monaspace Argon NF"
           :tab-line-family "Monaspace Argon NF"
           :line-number-family "Monaspace Neon NF"
           :italic-family "Monaspace Argon NF"
           :bold-family "Monaspace Argon NF"
           :svg-line-family "Terminess Nerd Font Mono")

          ;; Deliberately loud: as much of the Monaspace superfamily as one
          ;; buffer can show, with Terminus for anything that is code.  All
          ;; five families are metrically compatible, so tables and blocks
          ;; still line up despite the variety.
          ;;
          ;;   Argon    humanist    -- body prose
          ;;   Xenon    slab serif  -- document title, H1/H3/H5
          ;;   Krypton  mechanical  -- H2/H4/H6, bold, drawers, metadata
          ;;   Radon    handwriting -- italic, quotes
          ;;   Neon     grotesque   -- links, dates, tags
          ;;   Terminus              -- code: blocks, tables, verbatim
          (org-wild
           :default-family "Monaspace Argon NF"
           :default-height 170
           :fixed-pitch-family "Monaspace Neon NF"
           :variable-pitch-family "Monaspace Argon NF"
           :variable-pitch-height 1.0
           :header-line-family "Monaspace Xenon NF"
           :mode-line-active-family "Monaspace Krypton NF"
           :mode-line-inactive-family "Monaspace Krypton NF"
           :tab-bar-family "Monaspace Krypton NF"
           :tab-line-family "Monaspace Krypton NF"
           :line-number-family "Monaspace Neon NF"
           :italic-family "Monaspace Radon NF"
           :bold-family "Monaspace Krypton NF"
           :svg-line-family "Terminess Nerd Font Mono"
           ;; everything font-lock touches -- i.e. the inside of src blocks
           :code-family "Monaspace Krypton NF"
           ;; except comments and docstrings, which are prose inside code
           :comment-family "Monaspace Radon NF"
           :extra-faces
           ((org-document-title . "Monaspace Xenon NF")
            (org-property-value . "Monaspace Neon NF")
            (org-level-1        . "Monaspace Xenon NF")
            (org-level-2        . "Monaspace Krypton NF")
            (org-level-3        . "Monaspace Xenon NF")
            (org-level-4        . "Monaspace Krypton NF")
            (org-level-5        . "Monaspace Xenon NF")
            (org-level-6        . "Monaspace Krypton NF")
            (org-quote          . "Monaspace Radon NF")
            (org-link           . "Monaspace Neon NF")
            (org-date           . "Monaspace Neon NF")
            (org-tag            . "Monaspace Neon NF")
            (org-todo           . "Monaspace Krypton NF")
            (org-done           . "Monaspace Krypton NF")
            ;; Code takes Krypton, the mechanical face: src blocks, ~code~
            ;; and =verbatim= read as machine text against the humanist
            ;; Argon around them.  The structural furniture -- tables,
            ;; drawers, keywords, checkboxes -- stays on Neon, the plainest
            ;; of the five, so it recedes rather than competing with the
            ;; code it sits next to.  All five share a cell, so none of
            ;; this moves the grid.
            (org-block          . "Monaspace Krypton NF")
            (org-code           . "Monaspace Krypton NF")
            (org-verbatim       . "Monaspace Krypton NF")
            (org-inline-src-block . "Monaspace Krypton NF")
            ;; Tables are structure rather than code, and stay on Neon.
            ;; Metrically it makes no difference -- the five Monaspace
            ;; faces share a cell -- so this is purely about texture.
            (org-table          . "Monaspace Neon NF")
            (org-drawer         . "Monaspace Neon NF")
            (org-special-keyword . "Monaspace Neon NF")
            (org-meta-line      . "Monaspace Neon NF")
            (org-checkbox       . "Monaspace Neon NF")))

          ;; One font everywhere, via the helper.  JetBrainsMono is one of
          ;; the few families whose Nerd icons advance like its text, so it
          ;; can serve as its own chrome font.
          (jetbrains . ,(zetta-fontaine-uniform
                         "JetBrainsMono Nerd Font Mono"
                         :default-height 150
                         :svg-line-family "JetBrainsMono Nerd Font Mono"))

          ;; Inherited by every preset above for anything left unset.
          (t
           :default-weight regular
           :default-slant normal
           :fixed-pitch-height 1.0
           :bold-weight bold
           :italic-slant italic
           :line-number-height 1.0)))

  :config
  (defvar zetta-fontaine-default-preset 'gohufont-11-nerd-font
    "Preset to fall back on when there is no saved state to restore.

A GENERATED preset -- one per installed monospaced font -- rather than a
curated one, so it exists only on a machine that actually has the font.
`zetta-fontaine--apply-startup-preset' falls back to a curated preset
where it does not.")

  (defvar zetta-fontaine--startup-preset-applied nil
    "Non-nil once the wanted startup preset has actually been applied.")

  (defun zetta-fontaine--apply-startup-preset ()
    "Apply the saved preset, or `zetta-fontaine-default-preset'.

Retries until the preset it wants exists.  Generated presets are not built
until a graphical frame has measured the installed fonts, and under the
daemon that is long after this first runs -- `fontaine-presets' holds only
the seven curated ones at that point.  `fontaine-set-preset' does not
complain about a preset it cannot find: it quietly applies the `t'
fallback, so asking for a generated preset too early leaves the frame on
the wrong font with nothing said about it.  Apply a curated preset
meanwhile and come back once generation has happened.

One-shot by design.  It stops retrying the moment it succeeds, so a preset
chosen by hand afterwards is never snapped back to the saved one by the
next frame."
    (unless zetta-fontaine--startup-preset-applied
      (let ((wanted (or (fontaine-restore-latest-preset)
                        zetta-fontaine-default-preset)))
        (if (assq wanted fontaine-presets)
            (progn (setq zetta-fontaine--startup-preset-applied t)
                   (fontaine-set-preset wanted))
          (fontaine-set-preset 'terminus)))))

  ;; Populate `fontaine-presets' from the curated list plus one preset per
  ;; installed monospaced font.  Deferred to the first graphical frame:
  ;; generation measures real font metrics, which a daemon cannot do at
  ;; startup.
  (if (seq-some #'display-graphic-p (frame-list))
      (zetta-fontaine-refresh-font-presets)
    (setq fontaine-presets zetta-fontaine-curated-presets)
    (add-hook 'server-after-make-frame-hook
              #'zetta-fontaine-refresh-font-presets)
    ;; APPENDED, so it runs after the generation above on the same hook --
    ;; the whole point is to get a second go once the preset exists.
    (add-hook 'server-after-make-frame-hook
              #'zetta-fontaine--apply-startup-preset t))

  (defun zetta-fontaine--sync ()
    "Carry a preset change through to the parts fontaine cannot reach.

Three things need doing that `fontaine-set-preset' does not:

1. The frame font.  Fontaine installs faces with `custom-theme-set-faces'
   under a theme it does not enable, and an existing frame keeps rendering
   `default' from its own `font' frame parameter.  Force it, for every
   frame and for frames yet to be created.

2. `zetta-svg-line-font'.  The mode line, tab bar, tab line and header
   line are SVG images, so face families never reach them.

3. The metric corrections in core/interface.el, which are derived from
   the default font's ascent/descent and cell width and are therefore
   wrong the moment the default font changes.

4. Recording the choice where fontaine will persist it."
    ;; `fontaine-store-latest-preset' -- which `fontaine-mode' runs from
    ;; `kill-emacs-hook' -- writes `(car fontaine-preset-history)', NOT
    ;; `fontaine-current-preset'.  That history is only ever pushed to by
    ;; fontaine's own interactive `completing-read', and
    ;; `zetta-fontaine-pick-preset' reads with a history of its own and then
    ;; calls `fontaine-set-preset' as a plain function.  So every preset
    ;; chosen through the picker was dropped at exit and the next session
    ;; restored whatever was last set with `M-x fontaine-set-preset' --
    ;; which is why `fontaine-preset-history' held nothing but curated
    ;; presets and a generated one could never become the default.
    (when fontaine-current-preset
      (add-to-history 'fontaine-preset-history
                      (symbol-name fontaine-current-preset)))
    ;; Everything below measures real font metrics or touches frames, none
    ;; of which is meaningful without a graphical frame.  Under the daemon
    ;; there is none when `fontaine-mode' restores the saved preset at
    ;; startup, so re-arm for the first real frame instead of silently
    ;; skipping -- which left the chrome font switched but its layout grid
    ;; and the buffer font still on the old preset.
    (if (not (seq-some #'display-graphic-p (frame-list)))
        (add-hook 'server-after-make-frame-hook #'zetta-fontaine--sync)
      (remove-hook 'server-after-make-frame-hook #'zetta-fontaine--sync)
      (let* ((preset fontaine-current-preset)
             (family (fontaine--get-preset-property preset :default-family))
             (height (fontaine--get-preset-property preset :default-height))
             (svg (fontaine--get-preset-property preset :svg-line-family)))
        ;; Fontaine installs its faces with `custom-theme-set-faces' under a
        ;; theme it never enables.  That applies them once, but any later
        ;; `clear-face-cache' re-realizes faces from their SPECS -- and with
        ;; the theme disabled fontaine's spec is not consulted, so `default'
        ;; falls back to the generic sans (Helvetica).  The metric derivation
        ;; below clears the cache, so without this the font silently reverts.
        (when (custom-theme-p 'fontaine)
          (ignore-errors (enable-theme 'fontaine)))
        (when (and family height)
          nil)
        (when svg (setq zetta-svg-line-font svg))
        ;; Metrics first: it clears the face cache, so asserting the frame
        ;; font before this would just be undone.
        (when (fboundp 'zetta-font-apply-metric-corrections)
          (zetta-font-apply-metric-corrections))
        (when (and family height)
          (let ((spec (format "%s-%d" family (round (/ height 10.0)))))
            (setf (alist-get 'font default-frame-alist) spec)
            ;; Only touch frames that are actually wrong: `set-frame-font'
            ;; resizes frames and invalidates font caches.
            (dolist (frame (frame-list))
              (when (and (display-graphic-p frame)
                         (not (equal family (face-attribute 'default :family frame))))
                (ignore-errors (set-frame-font spec nil (list frame)))))))
        ;; `set-frame-font' re-realizes faces against the new frame font and
        ;; drops attributes fontaine had just written -- `italic' most
        ;; visibly, which `font-lock-comment-face' inherits, so comments kept
        ;; the OLD preset's family.  It only fires when the family actually
        ;; changes, which is why re-selecting the same preset appeared to fix
        ;; it: the second pass skipped the step doing the damage.
        ;;
        ;; Re-assert fontaine's faces as the last word.  Cheap, and it makes
        ;; the hook idempotent by construction rather than by luck.
        (when (and (fboundp 'fontaine--set-faces) fontaine-current-preset)
          (ignore-errors (fontaine--set-faces fontaine-current-preset)))

        ;; the SVG lines lay text out on a px-per-char grid tied to that font
        (when (fboundp 'zetta-svg-line-derive-char-advance)
          (zetta-svg-line-derive-char-advance))
        (when (fboundp 'zetta-svg-line-apply-brushup-palette)
          (zetta-svg-line-apply-brushup-palette))
        ;; A buffer-local preset is only needed where it DIFFERS from the
        ;; global one, so changing the global preset changes which buffers
        ;; need a remap -- and which can drop theirs.
        (when (fboundp 'zetta-fontaine-refresh-buffer-presets)
          (zetta-fontaine-refresh-buffer-presets))
        (force-mode-line-update t))))

  (add-hook 'fontaine-set-preset-hook #'zetta-fontaine--sync)

  ;; Persists the chosen preset and re-applies it for new frames (which
  ;; matters under the daemon).
  (fontaine-mode 1)
  (zetta-fontaine--apply-startup-preset))
;;; fontaine.el ends here

;;; ------------------------------------------------------------------
;;; Per-buffer presets (proof of concept)
;;; ------------------------------------------------------------------
;; Fontaine is global: it installs face specs with `custom-theme-set-faces',
;; and Emacs faces are frame-scoped, not buffer-scoped.  The only per-buffer
;; mechanism is `face-remapping-alist', so this reads a preset out of
;; `fontaine-presets' and remaps `default', `fixed-pitch' and
;; `variable-pitch' locally.  Fontaine stays the single source of truth for
;; what each preset means.
;;
;; Uses `face-remap-add-relative' rather than setting `face-remapping-alist'
;; directly: `text-scale-mode' lives in that same variable, and clobbering it
;; breaks C-x C-+ in the buffer.  Cookies are kept so the remap can be undone.

(defvar zetta-fontaine-buffer-presets
  '((org-mode    . org-wild)
    ;; before prog-mode, which it derives from
    (sql-mode     . monaspace-mixed))
  "Alist of major mode -> fontaine preset, applied buffer-locally.
Matched with `derived-mode-p', so a derived mode inherits its parent's
entry unless it has one of its own.

Deliberately short.  Every entry here is a buffer whose font DIFFERS from
the global preset, and consult previews those buffers in-window while you
are still moving through candidates -- so each one is a font that visibly
swaps in and out mid-completion, taking the line height with it.  That is
worth paying for org prose, which is a genuinely different kind of text.
It was not worth paying for prog-mode, magit, dired, ibuffer and
tabulated-list, which all wanted \"a fixed cell\" and were pinned to
terminus to get it -- something any monospaced global preset already
gives them.

The cost was invisible while the global preset WAS terminus:
`zetta-fontaine-apply-buffer-preset' skips a remap when the mapped preset
already matches the global one, so the entries did nothing until the
global preset moved off terminus.")

(defvar zetta-fontaine-buffer-exclude
  '(ghostel-mode vterm-mode term-mode eat-mode)
  "Modes that never get a buffer-local font.
A terminal emulator is a fixed grid whose row count was already reported
to the PTY from the FRAME's cell metrics.  Changing the font in the buffer
desynchronizes the two and clips output at the bottom -- the exact failure
documented in FONTS.org.")

(defvar zetta-fontaine-comment-faces
  '(font-lock-comment-face
    font-lock-comment-delimiter-face
    font-lock-doc-face
    font-lock-doc-markup-face)
  "Faces exempt from `:code-family', styled by `:comment-family' instead.
Comments and docstrings are prose that happens to live inside code, so
they are the one part of a source block that reasonably takes a different
typeface from the code around it -- which is what Monaspace Radon exists
for.  Without the exemption `:code-family' flattens them along with the
keywords and the handwriting effect disappears.")

(defvar zetta-fontaine-buffer-faces
  '(default fixed-pitch fixed-pitch-serif variable-pitch
    bold italic line-number)
  "Faces a buffer-local preset remaps.

A subset of `fontaine-faces'.  Remapping only `default' and the two pitch
faces is not enough: fontaine also sets `bold' and `italic' globally, org
headings are bold and emphasis is italic, so a global preset change would
still visibly alter an org buffer that was supposed to be pinned.

`mode-line-active', `mode-line-inactive', `header-line', `tab-bar' and
`tab-line' are deliberately excluded -- that chrome is SVG drawn in
`zetta-svg-line-font', so face families never reach it, and it is global
by nature anyway.")

(defvar-local zetta-fontaine--buffer-cookies nil
  "Face-remap cookies for this buffer, so the remap can be removed.")

(defvar-local zetta-fontaine--buffer-preset nil
  "Preset currently applied to this buffer, or nil.")

(defun zetta-fontaine--local-spec (preset face)
  "Face spec for FACE under PRESET, or nil when it names no family."
  (let ((family (fontaine--get-preset-property
                 preset (intern (format ":%s-family" face))))
        (height (fontaine--get-preset-property
                 preset (intern (format ":%s-height" face)))))
    (when family
      (append (list :family family)
              ;; an integer height is absolute (1/10 pt); a float is
              ;; relative, and relative is meaningless against a remap
              (when (integerp height) (list :height height))))))

(defun zetta-fontaine-unset-preset-locally ()
  "Remove any buffer-local font preset from the current buffer."
  (interactive)
  (mapc #'face-remap-remove-relative zetta-fontaine--buffer-cookies)
  (setq zetta-fontaine--buffer-cookies nil
        zetta-fontaine--buffer-preset nil))

(defun zetta-fontaine-set-preset-locally (preset)
  "Apply PRESET's font stack to the current buffer only."
  (interactive
   (list (intern (completing-read
                  "Preset (buffer-local): "
                  (mapcar #'car (seq-remove (lambda (p) (eq (car p) t))
                                            fontaine-presets))
                  nil t))))
  (zetta-fontaine-unset-preset-locally)
  (dolist (face zetta-fontaine-buffer-faces)
    (when-let* ((spec (zetta-fontaine--local-spec preset face)))
      (push (face-remap-add-relative face spec)
            zetta-fontaine--buffer-cookies)))
  ;; `:extra-faces' reaches past the twelve faces fontaine knows about, so a
  ;; preset can style mode-specific faces -- org has 119 of its own.  Another
  ;; custom key riding along in the plist; fontaine ignores what it does not
  ;; recognise.  Each entry is (FACE . FAMILY) or (FACE . SPEC-PLIST).
  ;; `:code-family' -- every `font-lock-*' face at once.  Inside an org
  ;; buffer those appear only within src blocks (native fontification), and
  ;; several inherit `bold' or `italic', which a preset may point at a
  ;; different family: without this, `font-lock-keyword-face' rendered in
  ;; Krypton and `font-lock-doc-face' in Radon inside a Terminus code block.
  ;; Enumerating the faces individually would rot -- major modes add their
  ;; own -- so match the prefix.
  (when-let* ((code (fontaine--get-preset-property preset :code-family)))
    (dolist (face (face-list))
      (when (and (string-prefix-p "font-lock-" (symbol-name face))
                 (not (memq face zetta-fontaine-comment-faces)))
        (push (face-remap-add-relative face (list :family code))
              zetta-fontaine--buffer-cookies))))
  ;; comments and docstrings: prose inside code
  (when-let* ((prose (fontaine--get-preset-property preset :comment-family)))
    (dolist (face zetta-fontaine-comment-faces)
      (when (facep face)
        (push (face-remap-add-relative face (list :family prose))
              zetta-fontaine--buffer-cookies))))
  (dolist (entry (fontaine--get-preset-property preset :extra-faces))
    (let ((face (car entry)) (val (cdr entry)))
      (when (facep face)
        (push (face-remap-add-relative
               face (if (stringp val) (list :family val) val))
              zetta-fontaine--buffer-cookies))))
  (setq zetta-fontaine--buffer-preset preset))

(defun zetta-fontaine-apply-buffer-preset ()
  "Apply the preset `zetta-fontaine-buffer-presets' maps this mode to.
Does nothing for excluded modes, or when the mapped preset is already the
global one -- remapping to what is already active only costs redisplay."
  (unless (apply #'derived-mode-p zetta-fontaine-buffer-exclude)
    (when-let* ((entry (seq-find (lambda (cell) (derived-mode-p (car cell)))
                                 zetta-fontaine-buffer-presets))
                (preset (cdr entry)))
      (unless (or (eq preset fontaine-current-preset)
                  (eq preset zetta-fontaine--buffer-preset))
        (zetta-fontaine-set-preset-locally preset)))))

(add-hook 'after-change-major-mode-hook #'zetta-fontaine-apply-buffer-preset)

(defun zetta-fontaine-refresh-buffer-presets ()
  "Re-evaluate every buffer's local preset against the current global one.
Called after a global preset change: a buffer whose mapped preset now
matches the global preset drops its remap, and one that no longer matches
gains it."
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      ;; Force re-application rather than relying on
      ;; `zetta-fontaine-apply-buffer-preset', which short-circuits when the
      ;; mapped preset is already the buffer's.  That short-circuit means an
      ;; existing buffer never picks up a CHANGED face list -- when `bold'
      ;; and `italic' were added to `zetta-fontaine-buffer-faces', already
      ;; open buffers kept their old three-face remap and their emphasis
      ;; kept following the global preset.
      (when zetta-fontaine--buffer-preset
        (zetta-fontaine-unset-preset-locally))
      (zetta-fontaine-apply-buffer-preset))))

;;; ------------------------------------------------------------------
;;; A picker: consult preview, marginalia annotations, in-font candidates
;;; ------------------------------------------------------------------
;; Three things fontaine's own prompt does not do:
;;
;;   render each candidate in the font it names -- with 334 generated
;;   presets, reading the names is far slower than seeing them;
;;   annotate with family, size and chrome font;
;;   preview live, the way `consult-theme' does.
;;
;; The preview is deliberately CHEAP.  Applying a real preset runs
;; `zetta-fontaine--sync' -- `set-frame-font', `clear-face-cache', a full
;; metric re-derivation -- which is far too heavy to fire on every arrow
;; keypress across hundreds of candidates.  So preview only remaps
;; `default' in the current buffer, which is enough to judge a font, and
;; the real preset is applied once on selection.

(defun zetta-fontaine--preset-family (preset)
  "Default family PRESET names, when it is actually installed."
  (when-let* ((family (fontaine--get-preset-property preset :default-family)))
    (car (member family (font-family-list)))))

(defun zetta-fontaine--candidates ()
  "Preset names, each propertized to render in the font it selects."
  (mapcar (lambda (cell)
            (let* ((preset (car cell))
                   (name (symbol-name preset))
                   (family (zetta-fontaine--preset-family preset)))
              (if family (propertize name 'face (list :family family)) name)))
          (seq-remove (lambda (cell) (eq (car cell) t)) fontaine-presets)))

(defun zetta-fontaine-annotate (cand)
  "Annotation for preset CAND: family, height, and chrome font."
  (when-let* ((preset (intern-soft cand))
              (family (fontaine--get-preset-property preset :default-family)))
    (let ((height (fontaine--get-preset-property preset :default-height))
          (chrome (fontaine--get-preset-property preset :svg-line-family))
          (curated (assq preset zetta-fontaine-curated-presets)))
      (concat
       (propertize " " 'display '(space :align-to 34))
       (propertize (format "%-32s" family) 'face 'marginalia-value)
       (propertize (format "%-5s" (or height "")) 'face 'marginalia-number)
       (propertize (if (and chrome (not (equal chrome "Terminess Nerd Font Mono")))
                       "own chrome " "")
                   'face 'marginalia-modified)
       (propertize (if curated "curated" "") 'face 'marginalia-documentation)))))

(defvar zetta-fontaine-preview-key nil
  "How `zetta-fontaine-pick-preset\=' previews a candidate.

  nil     no preview at all (default) -- the candidate names already
          render in the font they select, which is the useful half;
          re-rendering the whole buffer on every arrow key is not.
  \"M-.\"   preview only when that key is pressed.
  \='any    consult\='s usual behaviour: preview every candidate as you move.

Passed straight to `consult--read\=' as :preview-key.")

(defun zetta-fontaine--preview ()
  "Consult state function previewing a preset in the current buffer only."
  (let ((cookie nil)
        (buffer (current-buffer)))
    (lambda (action cand)
      (when (buffer-live-p buffer)
        (with-current-buffer buffer
          (pcase action
            ((or 'preview 'exit 'return)
             (when cookie (face-remap-remove-relative cookie) (setq cookie nil))))
          (when (and (eq action 'preview) cand)
            (when-let* ((family (zetta-fontaine--preset-family (intern-soft cand))))
              (setq cookie (face-remap-add-relative
                            'default (list :family family))))))))))

;;;###autoload
(defun zetta-fontaine-pick-preset ()
  "Choose a fontaine preset.
Candidates render in the font they select, which is usually enough to
choose by.  Live preview is off by default -- see
`zetta-fontaine-preview-key\=' to enable it on a key, or on every
candidate."
  (interactive)
  (let ((choice (consult--read
                 (zetta-fontaine--candidates)
                 :prompt "Font preset: "
                 :category 'fontaine-preset
                 :require-match t
                 :sort nil
                 :history 'zetta-fontaine--preset-history
                 :annotate #'zetta-fontaine-annotate
                 :preview-key zetta-fontaine-preview-key
                 :state (and zetta-fontaine-preview-key
                             (zetta-fontaine--preview)))))
    (fontaine-set-preset (intern choice))))

(defvar zetta-fontaine--preset-history nil
  "History for `zetta-fontaine-pick-preset'.")

;; So marginalia also annotates anything else declaring this category.
(with-eval-after-load 'marginalia
  (when (boundp 'marginalia-annotator-registry)
    (add-to-list 'marginalia-annotator-registry
                 '(fontaine-preset zetta-fontaine-annotate builtin none))))
