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
  '(?⏺ ?⎿ ?❯ ?✳ ?✚ ?✅ ?❌ ?─ ?│ ?┼ ?⣿ ?✻ ?⏵ ?⏸)
  "Glyphs terminal UIs actually put on screen.
Used to measure whether a fallback advances the right number of cells.")

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
