;;; interface.el --- Configure core interface -*- lexical-binding: t; -*-

;; download from https://files.ax86.net/terminus-ttf/ drag it into the
;; `Font Book` app
;; Set font in default-frame-alist for daemon compatibility (set-frame-font
;; fails silently in daemon mode since there's no frame yet)
(add-to-list 'default-frame-alist `(font . ,(format "%s-%d" zetta-font 16)))
(set-face-attribute 'default nil :family zetta-font :height 160)

;;; ------------------------------------------------------------------
;;; Font metric corrections -- derived, not hardcoded
;;; ------------------------------------------------------------------
;; Emacs sizes a display row as max(ascent) + max(descent) across the fonts
;; on that row, computed INDEPENDENTLY -- not max(ascent+descent).  So a
;; fallback font only fits the default font's box if BOTH its ascent and its
;; descent are within the default's.  It must also advance exactly one cell
;; per column, or it shifts the rest of the row.
;;
;; When either fails in a terminal-emulator buffer the damage is real: the
;; buffer is a fixed grid, ghostel sizes the PTY from `window-body-height'
;; (rows x default-line-height), and a few tall rows push the last rows below
;; the window with nowhere to scroll.  A narrow glyph breaks box-drawing
;; tables the same way horizontally.
;;
;; Ruled out as fixes: the `line-height' text property can only GROW a row,
;; never cap it; `line-spacing' is additive rather than a floor (measured
;; 882px -> 1074px with the disparity preserved).
;;
;; These corrections used to be constants tuned to Terminus (13/4, 8px wide).
;; They are now derived from whatever the default font currently is, so
;; switching a `fontaine' preset re-derives rather than silently invalidating
;; them.

(defvar zetta-font-fallback-families
  '("STIX Two Math"             ; U+23FA -- Claude Code's message bullet
    "Hiragino Sans"             ; U+23BF -- its tool-result marker
    "Arial Unicode MS"          ; U+271A and other symbols
    "JetBrainsMono Nerd Font"
    "Terminess Nerd Font Mono"  ; box drawing, Nerd PUA
    "Apple Color Emoji")        ; the only source of U+2705 / U+274C
  "Families known to serve glyphs the default font lacks.
A seed only: `zetta-font--borrowed-families' asks the fontset which
families are ACTUALLY in use and unions them in.  A fixed list is not
enough -- the real fallback shifts with the default font and the fontset,
and a family missing from it silently gets no correction (U+23BF arrived
from \"Hiragino Maru Gothic ProN\" while this list named \"Hiragino Sans\").")

(defun zetta-font--borrowed-families ()
  "Families the fontset actually borrows for `zetta-font-probe-glyphs'.
Excludes the default family: rescaling the font the buffer is set in
would shrink everything, not just the borrowed glyphs."
  (let ((own (face-attribute 'default :family nil 'default)))
    (seq-remove
     (lambda (fam)
       (or (null fam)
           (equal fam own)
           ;; Never rescale the generic sans/mono Emacs falls back to when a
           ;; face has no family: shrinking it would shrink unrelated text,
           ;; and its appearing here at all means a measurement went wrong.
           (member fam '("Helvetica" "Helvetica Neue" "Monospace" "Sans Serif"))))
     (delete-dups
      (append (mapcar #'zetta-font--serving-family zetta-font-probe-glyphs)
              zetta-font-fallback-families)))))

(defvar zetta-font-glyph-substitutions
  '((?⏺ . [?●])          ; U+23FA -> U+25CF
    (?✅ . [?✓ ?\s])      ; char-width 2, so glyph + space fills both cells
    (?❌ . [?✗ ?\s])
    (?❯ . [?⟩])           ; U+276F -> U+27E9
    (?✻ . [?*])
    (?✳ . [?*])
    (?⏵ . [?▶])
    (?⏸ . [?■]))
  "Glyphs to swap in terminal buffers, as (CHAR . REPLACEMENT-VECTOR).
Applied only where the default font lacks CHAR but has the replacement:
some fonts (Monaspace NF, for one) cover these natively, and substituting
then would trade a correct glyph for an approximation.")

(defun zetta-font--measurement-frame ()
  "The frame these metrics should be measured against.
Every helper here reads `frame-char-width', `string-pixel-width' or
`font-at', all of which answer for the SELECTED frame -- and under the
daemon that is whatever happens to be current, including child frames
(corfu) with a different default font.  Measuring one glyph against one
frame and its cell width against another produces nonsense: it once
attributed box drawing to Helvetica at an 8px cell while the real frame
was Monaspace at 11px.  Pick the largest graphical frame and hold it for
the whole derivation."
  (car (sort (seq-filter (lambda (f)
                           (and (display-graphic-p f)
                                (window-live-p (frame-selected-window f))))
                         (frame-list))
             (lambda (a b) (> (* (frame-width a) (frame-height a))
                              (* (frame-width b) (frame-height b)))))))

(defun zetta-font--metrics (family size)
  "Return (ASCENT DESCENT) for FAMILY at SIZE, or nil if unavailable."
  (ignore-errors
    (when-let* ((spec (find-font (font-spec :family family :size size)))
                (obj (open-font spec))
                (info (query-font obj)))
      (list (aref info 4) (aref info 5)))))

(defun zetta-font--default-size ()
  "Point size of the default face, in whole points."
  (max 1 (round (/ (face-attribute 'default :height nil 'default) 10.0))))

(defvar zetta-font-probe-glyphs
  '(;; what terminal UIs put on screen -- box drawing, Nerd PUA, status marks
    ?⏺ ?⎿ ?❯ ?✳ ?✚ ?✅ ?❌ ?─ ?│ ?┼ ?⣿ ?✻ ?⏵ ?⏸
    ;; what ordinary buffer and minibuffer text puts on screen.  These are
    ;; here for the HEIGHT pass, not the width one: this list is also what
    ;; `zetta-font--borrowed-families' probes to find out which families the
    ;; fontset actually borrows, and a family it never asks about gets no
    ;; correction at all.  Seeded only with terminal glyphs it found six
    ;; families and missed six more -- GohuFont 11 covers 9 of these 26
    ;; characters where Terminus covers 21, so on a sparse default font the
    ;; borrowing is constant and every uncapped family is a row 2-3px taller
    ;; than its neighbours.  `…' is the one that gives it away: vertico-flat
    ;; appends it as its overflow marker, so the minibuffer changed height by
    ;; two pixels every time the match count crossed the fits/does-not-fit
    ;; line.
    ?→ ?… ?• ?✓ ?✗ ?≠ ?≤ ?∞ ?λ ?π ?— ?“ ?” ?′)
  "Glyphs to measure fallback families against.

Serves two passes.  The WIDTH pass asks whether a borrowed family advances
the right number of cells; the HEIGHT pass asks whether its ascent and
descent fit the default font's box.  Both only ever see families that
serve a glyph on this list, so a character missing here is a family that
silently keeps its own metrics.

Deliberately no CJK.  Those fonts are double-width by design and belong in
a taller box; squeezing one into an 11px cell would make it unreadable,
which is a worse trade than a slightly tall row.")

(defun zetta-font--width-delta (char)
  "Pixels CHAR renders wider than the cells it occupies.  Negative = narrow."
  (let ((s (string char)))
    (- (string-pixel-width s) (* (frame-char-width) (string-width s)))))

(defun zetta-font--serving-family (char)
  "Family the fontset ACTUALLY uses for CHAR, or nil.
`font-at' accepts a string object, so this asks the real fontset without
touching a buffer.  Guessing from a candidate list instead does not work:
the fontset order is set by `set-fontset-font' prepends plus the system
fallback chain, so the first family that merely CAN render a glyph is
frequently not the one that does -- which shrinks the wrong font."
  (when-let* ((frame (zetta-font--measurement-frame))
              (win (frame-selected-window frame))
              (font (ignore-errors (font-at 0 win (string char))))
              (family (font-get font :family)))
    (format "%s" family)))

;;; ------------------------------------------------------------------
;;; Which families share a grid
;;; ------------------------------------------------------------------
;; Monaspace's five faces can be mixed inside one buffer because they agree
;; on advance, ascent and descent at every size -- that is the whole trick
;; of a monospace superfamily.  Nothing stops other families from happening
;; to agree too, and on a machine with 700-odd installed there is no way to
;; know by eye which.  These measure it.
;;
;; Two relations, because two different things can go wrong.  Sharing an
;; ADVANCE keeps columns aligned; a font that advances differently shifts
;; everything after it on the row.  Fitting inside the reference's ASCENT
;; and DESCENT keeps rows the same height, because Emacs sizes a row as
;; max(ascent) + max(descent) taken independently per font -- see
;; `zetta-font-derive-rescale'.  So:
;;
;;   strict   same advance, same ascent, same descent.  Symmetric: any
;;            member of the group can be the reference.
;;   fits     same advance, ascent and descent no GREATER than the
;;            reference's.  Asymmetric, and that asymmetry is real -- a
;;            shorter face drops into a taller face's grid, but not the
;;            reverse, where it would grow every row it touched.
;;
;; Measured at several sizes on purpose.  Two fonts whose proportions
;; differ can still round to the same pixel at one size; agreeing at 14, 17
;; and 24 means they agree by design rather than by luck.

(defcustom zetta-font-metric-probe-sizes '(14 17 24)
  "Point sizes at which `zetta-font-metric-signature' measures a family.
More sizes is a stricter test and a slower scan.  One size is not enough:
rounding makes unrelated fonts agree."
  :type '(repeat integer) :group 'zetta)

(defcustom zetta-font-metric-probe-chars '(?i ?M ?.)
  "Characters compared to decide whether a family is monospaced.
A narrow letter, a wide one and a punctuation mark.  All three must
advance identically."
  :type '(repeat character) :group 'zetta)

(defvar zetta-font-metric-signature-cache (make-hash-table :test 'equal)
  "Memo for `zetta-font-metric-signature'.
Opening and querying every installed family is slow enough to be worth
caching, and the answer only changes when fonts are installed or removed.
`zetta-font-forget-metrics' clears it.")

(defun zetta-font-forget-metrics ()
  "Drop the memo behind `zetta-font-metric-signature'.
Run after installing or removing fonts."
  (interactive)
  (clrhash zetta-font-metric-signature-cache))

(defun zetta-font-metric-signature (family &optional frame)
  "Grid signature of FAMILY: one (ADVANCE ASCENT DESCENT) per probe size.

Returns nil unless FAMILY is monospaced -- every character in
`zetta-font-metric-probe-chars' advancing identically -- at every size in
`zetta-font-metric-probe-sizes'.  A proportional family has no single
advance, so it has no grid to share and is simply not a candidate."
  (let ((key (list family (or frame (zetta-font--measurement-frame))
                   zetta-font-metric-probe-sizes zetta-font-metric-probe-chars)))
    (if (eq 'none (gethash key zetta-font-metric-signature-cache 'miss))
        nil
      (let ((hit (gethash key zetta-font-metric-signature-cache 'miss)))
        (if (not (eq hit 'miss))
            hit
          (let* ((frame (or frame (zetta-font--measurement-frame)))
                 (entity (and frame (ignore-errors
                                      (find-font (font-spec :family family) frame))))
                 (sig nil)
                 (mono (and entity t)))
            (when mono
              (dolist (size zetta-font-metric-probe-sizes)
                (let* ((obj (and mono (ignore-errors (open-font entity size frame))))
                       (info (and obj (ignore-errors (query-font obj))))
                       (widths (and info
                                    (mapcar
                                     (lambda (ch)
                                       (ignore-errors
                                         (aref (aref (font-get-glyphs
                                                      obj 0 1 (string ch))
                                                     0)
                                               4)))
                                     zetta-font-metric-probe-chars))))
                  (if (and widths (car widths) (not (memq nil widths))
                           (apply #'= widths))
                      (push (list (car widths) (aref info 4) (aref info 5)) sig)
                    (setq mono nil)))))
            (setq sig (and mono (= (length sig) (length zetta-font-metric-probe-sizes))
                           (nreverse sig)))
            (puthash key (or sig 'none) zetta-font-metric-signature-cache)
            sig))))))

(defun zetta-font-monospaced-families (&optional frame)
  "Every installed family that has a grid, as (FAMILY . SIGNATURE)."
  (let ((frame (or frame (zetta-font--measurement-frame))))
    (delq nil
          (mapcar (lambda (family)
                    (when-let* ((sig (zetta-font-metric-signature family frame)))
                      (cons family sig)))
                  (font-family-list frame)))))

(defun zetta-font-mixable-groups (&optional frame)
  "Every set of installed families that share a grid outright.

Returns ((SIGNATURE FAMILY...) ...), largest set first, singletons
dropped -- a family that matches nothing is not a superfamily.  Each set
is mixable in any combination and in any direction, so this is the list to
build presets from."
  (let ((groups nil))
    (pcase-dolist (`(,family . ,sig) (zetta-font-monospaced-families frame))
      (push family (alist-get sig groups nil nil #'equal)))
    (sort (delq nil
                (mapcar (lambda (g)
                          (when (cdr (cdr g))
                            (cons (car g) (sort (cdr g) #'string<))))
                        groups))
          (lambda (a b) (> (length (cdr a)) (length (cdr b)))))))

(defun zetta-font-mixable-with (family &optional frame)
  "How FAMILY can be mixed, as a plist.

  :signature  FAMILY's own grid signature, nil if it has none
  :strict     families agreeing exactly -- interchangeable with it
  :fits       families that can be dropped INTO its grid: same advance,
              never taller.  A superset of :strict.

Both lists exclude FAMILY itself."
  (let* ((frame (or frame (zetta-font--measurement-frame)))
         (target (zetta-font-metric-signature family frame))
         (strict nil) (fits nil))
    (when target
      (pcase-dolist (`(,other . ,sig) (zetta-font-monospaced-families frame))
        (unless (equal other family)
          (when (cl-every (lambda (a b)
                            (and (=  (nth 0 a) (nth 0 b))
                                 (<= (nth 1 a) (nth 1 b))
                                 (<= (nth 2 a) (nth 2 b))))
                          sig target)
            (push other fits)
            (when (equal sig target) (push other strict))))))
    (list :signature target
          :strict (sort strict #'string<)
          :fits (sort fits #'string<))))

;;;###autoload
(defun zetta-font-list-mixable (&optional family)
  "Report which installed families share a grid with FAMILY.

With no FAMILY, report every mixable group on the machine instead.  Called
from Lisp the underlying data comes from `zetta-font-mixable-groups' and
`zetta-font-mixable-with', which return plain lists meant to be consumed
by preset-building code; this command only renders them."
  (interactive
   (list (when current-prefix-arg
           (completing-read "Mixable with family: "
                            (mapcar #'car (zetta-font-monospaced-families))
                            nil t nil nil
                            (face-attribute 'default :family nil 'default)))))
  (let ((standard-output (get-buffer-create "*font grids*")))
    (with-current-buffer standard-output
      (let ((inhibit-read-only t)) (erase-buffer))
      (special-mode)
      (let ((inhibit-read-only t))
        (if family
            (let* ((r (zetta-font-mixable-with family))
                   (sig (plist-get r :signature)))
              (princ (format "%s\n  signature (advance ascent descent) at %s: %S\n\n"
                             family zetta-font-metric-probe-sizes sig))
              (unless sig
                (princ "  not monospaced -- no grid to share\n"))
              (when sig
                (princ (format "  interchangeable (%d):\n" (length (plist-get r :strict))))
                (dolist (f (plist-get r :strict)) (princ (format "    %s\n" f)))
                (let ((only (seq-difference (plist-get r :fits) (plist-get r :strict))))
                  (princ (format "\n  fits inside, shorter (%d):\n" (length only)))
                  (dolist (f only)
                    (princ (format "    %-38s %S\n"
                                   f (zetta-font-metric-signature f)))))))
          (let ((groups (zetta-font-mixable-groups)))
            (princ (format "%d mixable groups, probed at %s\n\n"
                           (length groups) zetta-font-metric-probe-sizes))
            (pcase-dolist (`(,sig . ,fams) groups)
              (princ (format "%S  -- %d families\n" sig (length fams)))
              (dolist (f fams) (princ (format "    %s\n" f)))
              (princ "\n"))))
        (goto-char (point-min))))
    (display-buffer standard-output)))

(defun zetta-font-derive-rescale ()
  "Rescale the families the fontset borrows, to fit the default font's cell.

Two constraints, and a family has to satisfy both:

  height  its ascent and descent must sit inside the default font's, or
          its rows grow and the bottom of a terminal buffer is clipped.
  width   it must advance exactly one cell per column, or it shifts the
          rest of the row and breaks box-drawing alignment.

Height is solved in closed form from the font metrics.  Width cannot be:
`query-font' reports the widest glyph in the whole font, which for a CJK
or symbol family is far wider than the glyph actually being borrowed, and
constraining on that shrinks it to nothing.  So width is measured on the
real glyphs in `zetta-font-probe-glyphs' and refined by iteration."
  (let* ((size (zetta-font--default-size))
         (base (zetta-font--metrics (face-attribute 'default :family nil 'default) size)))
    (when base
      (let ((asc-max (nth 0 base))
            (desc-max (nth 1 base))
            (factors nil))
        ;; --- pass 1: height, closed form -------------------------------
        (dolist (family (zetta-font--borrowed-families))
          (when-let* ((m (zetta-font--metrics family size)))
            (let* ((asc (nth 0 m)) (desc (nth 1 m))
                   (f (min 1.0
                           (if (> asc 0) (/ (float asc-max) asc) 1.0)
                           (if (> desc 0) (/ (float desc-max) desc) 1.0))))
              ;; round DOWN: rounding up can leave a 1px overhang
              (push (cons family (max 0.5 (/ (ffloor (* f 100)) 100.0))) factors))))
        (setq factors (nreverse factors))
        (unless (equal factors face-font-rescale-alist)
          (setq face-font-rescale-alist (copy-alist factors))
          (clear-face-cache t))
        ;; --- pass 2: width, measured once and corrected once -----------
        ;; Bounded deliberately.  Each round costs a `clear-face-cache',
        ;; which rebuilds every realized face, and this runs on every preset
        ;; switch AND at startup -- an open-ended loop here is a good way to
        ;; make Emacs appear to hang.  Two rounds is enough: the adjustment
        ;; is proportional, so the first lands nearly exactly and the second
        ;; only mops up integer rounding.
        (dotimes (_ 2)
          (let ((adjusted nil))
            (dolist (ch zetta-font-probe-glyphs)
              (let ((have (string-pixel-width (string ch)))
                    (want (* (frame-char-width) (string-width (string ch)))))
                (when (and (> have want) (> have 0))
                  (when-let* ((fam (zetta-font--serving-family ch))
                              (cell (assoc fam face-font-rescale-alist)))
                    (setcdr cell (max 0.3 (/ (ffloor (* (cdr cell)
                                                        (/ (float want) have) 100))
                                             100.0)))
                    (setq adjusted t)))))
            (when adjusted (clear-face-cache t))))
        face-font-rescale-alist))))

(defvar zetta-terminal-display-table nil
  "Display table swapping glyphs whose advance does not match their cells.
Rebuilt by `zetta-font-derive-display-table' for the current default font.")

(defun zetta-font-derive-display-table ()
  "Rebuild `zetta-terminal-display-table' for the current default font.
Only substitutes a glyph the default font actually lacks."
  (let* ((size (zetta-font--default-size))
         (spec (find-font (font-spec :family (face-attribute 'default :family nil 'default)
                                     :size size)))
         (font (and spec (ignore-errors (open-font spec))))
         (dt (make-display-table)))
    (dolist (entry zetta-font-glyph-substitutions)
      (let ((char (car entry)) (replacement (cdr entry)))
        (unless (and font (font-has-char-p font char))
          (aset dt char replacement))))
    (setq zetta-terminal-display-table dt)))

(defun zetta-use-terminal-display-table ()
  "Apply `zetta-terminal-display-table' to the current buffer."
  (unless zetta-terminal-display-table (zetta-font-derive-display-table))
  (setq buffer-display-table zetta-terminal-display-table))

(defvar zetta-font--last-signature nil
  "Font signature the corrections were last derived for.
Guards against re-deriving -- and re-clearing the face cache -- when a
preset switch did not actually change the font.")

(defun zetta-font-apply-metric-corrections ()
  "Re-derive every font metric correction for the current default font.

Does nothing without a graphical frame: all of this is measured from real
font metrics and rendered widths, and a daemon has no usable frame at
`elpaca-after-init-hook' time.  In that case it re-arms itself for the
first graphical frame instead.

Errors are swallowed on purpose -- this runs during startup and on every
preset switch, and a missing font must never be able to break either."
  (interactive)
  (if (not (zetta-font--measurement-frame))
      (add-hook 'server-after-make-frame-hook
                #'zetta-font-apply-metric-corrections)
    (remove-hook 'server-after-make-frame-hook
                 #'zetta-font-apply-metric-corrections)
    (with-selected-frame (zetta-font--measurement-frame)
    (condition-case err
        (let ((sig (list (face-attribute 'default :family nil 'default)
                         (face-attribute 'default :height nil 'default)
                         (bound-and-true-p zetta-svg-line-font))))
          ;; Early-out when nothing font-related moved.  Everything below
          ;; costs a `clear-face-cache', which rebuilds every realized face;
          ;; re-running it for an unchanged font is pure waste and makes
          ;; repeated preset switching far more expensive than it looks.
          (unless (equal sig zetta-font--last-signature)
            (setq zetta-font--last-signature sig)
            (zetta-font-derive-rescale)
          (zetta-font-derive-display-table)
          ;; existing terminal buffers hold the OLD table object
            (dolist (buf (buffer-list))
              (with-current-buffer buf
                (when (derived-mode-p 'ghostel-mode 'vterm-mode)
                  (setq buffer-display-table zetta-terminal-display-table))))
            (force-mode-line-update t)))
      (error (message "zetta-font: metric derivation skipped: %s"
                      (error-message-string err)))))))

;; Prefer Terminess (the Nerd-Font patch of Terminus, hence metric-matched)
;; for the symbol blocks terminal UIs use.  Emacs falls through to the next
;; font for any codepoint it lacks, so these are safe to prepend.
(dolist (range '((#x2300 . #x23ff)    ; Misc Technical   -- Claude Code ⏺ ⎿
                 (#x2500 . #x257f)    ; Box Drawing
                 (#x2580 . #x259f)    ; Block Elements
                 (#x25a0 . #x25ff)    ; Geometric Shapes
                 (#x2600 . #x26ff)    ; Misc Symbols     -- ✳
                 (#x2700 . #x27bf)    ; Dingbats         -- ❯ ✚
                 (#x2800 . #x28ff)))  ; Braille          -- btop graphs
  (set-fontset-font t range "Terminess Nerd Font Mono" nil 'prepend))

(add-hook 'ghostel-mode-hook #'zetta-use-terminal-display-table)
(add-hook 'vterm-mode-hook   #'zetta-use-terminal-display-table)

;; Derive once at startup; `fontaine' re-runs this on every preset change.
(add-hook (if (boundp 'elpaca-after-init-hook) 'elpaca-after-init-hook 'after-init-hook)
          #'zetta-font-apply-metric-corrections)


;; prevent the *Warnings* buffer from popping up
;;(setq warning-minimum-level :emergency)

(winner-mode)

(global-auto-revert-mode 1) ;; you might not want this
(setq auto-revert-verbose nil) ;; or this

;; need to turn this on per mode, causes too many issues
(global-visual-line-mode -1)

(pixel-scroll-precision-mode 1)

(setq scroll-margin 0 ;; setting this above 0 causes issues with jumping while scrolling
      scroll-conservatively 9999
      scroll-step 1)

(setq scroll-bar-width nil)
(setq scroll-bar-height nil)

(defun server-shutdown ()
  "Save buffers, Quit, and Shutdown (kill) server"
  (interactive)
  (save-some-buffers)
  (kill-emacs))

(defun zetta-scratch ()
  (interactive)
  (let* ((major-mode-input (completing-read "Enter a major mode: "
                                            '("python" "sql" "elisp"))))
    (switch-to-buffer (concat "*" major-mode-input "-scratch" "*"))
    (when (string= major-mode-input "python") (python-ts-mode))
    (when (string= major-mode-input "sql") (sql-mode))
    (when (string= major-mode-input "elisp") (emacs-lisp-mode))))

(setq enable-local-variables :all)

(general-define-key :keymaps 'menu-window-keymap
                    "C-S" 'zetta-scratch
                    "C-S-<backspace>" 'zetta-server-shutdown-save-desktop)

(setq-default left-margin-width 2)
(setq-default right-margin-width 2)

;; Emacs 28 and newer: Hide commands in M-x which do not work in the current
;; mode.  Vertico commands are hidden in normal buffers. This setting is
;; useful beyond Vertico.
(setq read-extended-command-predicate #'command-completion-default-include-p)

;; note can change the minibuffer font in this way.  not doing this
;; for now because the echo area height is determined by the default
;; font size.  so when there is a short default font and the font set
;; here is taller, then the minibuffer resizes whenever it gets used,
;; causign jitter in the interface
;; (add-hook 'minibuffer-setup-hook 'my-buffer-face-mode-pt-mono-p85)

;; activate makefile-mode whenver a file is opened matching the regex "Makefile.*"
(add-to-list 'auto-mode-alist '("Makefile.*" . makefile-mode))
(add-hook 'window-selection-change-functions (lambda (_) (force-mode-line-update)))

(use-package trailing-newline-indicator
  :ensure (trailing-newline-indicator
           :host github
           :repo "saulotoledo/trailing-newline-indicator")

  :init
  (global-trailing-newline-indicator-mode 1)

  :config
  (setq trailing-newline-indicator-show-line-number nil)
  )
;;; interface.el ends here
