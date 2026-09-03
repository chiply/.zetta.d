;;; interface.el --- Configure core interface -*- lexical-binding: t; -*-

;; download from https://files.ax86.net/terminus-ttf/ drag it into the
;; `Font Book` app
;; Set font in default-frame-alist for daemon compatibility (set-frame-font
;; fails silently in daemon mode since there's no frame yet)
(add-to-list 'default-frame-alist `(font . ,(format "%s-%d" zetta-font 16)))
(set-face-attribute 'default nil :family zetta-font :height 160)

;; Keep every display row exactly `default-line-height' tall.
;;
;; Emacs sizes a display row as max(ascent) + max(descent) across the fonts
;; on that row, computed INDEPENDENTLY -- not max(ascent+descent).  Terminus
;; is 13/4 (=17px), so a fallback font only fits if its ascent <= 13 AND its
;; descent <= 4.  Any glyph Terminus lacks otherwise makes its row 18-21px.
;;
;; In a terminal buffer that silently breaks the grid: ghostel sizes the PTY
;; from `window-body-height' (rows x default-line-height), so a handful of
;; taller rows push the last 2-3 rows below the window and the bottom of the
;; output is clipped with nowhere to scroll.  Claude Code is the worst case --
;; its UI puts a fallback glyph on nearly every line.
;;
;; Measured on this setup (Terminus 13/4): before, rows were 17/20/21/24 and
;; overflowed an 838px window by 50px; after, every row is 17 and the same
;; content totals 816px.
;;
;; A fallback font must ALSO advance exactly (8px x cell count), or it shifts
;; the rest of its row and breaks box-drawing tables.  Width and height are
;; both proportional to the scale factor, so a family whose aspect ratio
;; differs from Terminus cannot always satisfy both; where they conflict,
;; height wins -- a too-tall row clips the bottom of the buffer, while a few
;; px of width error is only cosmetic.
;;
;; Measured deltas at these factors (target: 0):
;;   box drawing, ⎿, ✚   0   -- exact, tables align
;;   ✅ ❌               -3  -- width wants 0.76, but that makes rows 20px
;;   ⏺                  -2  -- width wants 0.80, but that makes rows 18px
;;   ❯                  -1
;;
;;   STIX Two Math            desc 8 -> 4  (only font here with U+23FA,
;;                                          Claude Code's message bullet)
;;   Hiragino Sans            13px -> 8px wide  (U+23BF ⎿)
;;   Arial Unicode MS         13px -> 8px wide  (U+271A ✚)
;;   Terminess Nerd Font Mono asc 14 -> 12; box drawing lands on 8px exactly
;;   Apple Color Emoji        asc 15/desc 5 -> 13/4; keeps rows at 17px
(dolist (entry '(("STIX Two Math"            . 0.60)
                 ("Hiragino Sans"            . 0.52)
                 ("Arial Unicode MS"         . 0.49)
                 ("JetBrainsMono Nerd Font"  . 0.80)
                 ("Terminess Nerd Font Mono" . 0.93)
                 ("Apple Color Emoji"        . 0.68)))
  (add-to-list 'face-font-rescale-alist entry))

;; Prefer Terminess (the Nerd-Font patch of Terminus, so metric-matched) for
;; the symbol blocks terminal UIs actually use.  Emacs falls through to the
;; next font for any codepoint Terminess lacks, so these are safe to prepend.
(dolist (range '((#x2300 . #x23ff)    ; Misc Technical   -- Claude Code ⏺ ⎿
                 (#x2500 . #x257f)    ; Box Drawing
                 (#x2580 . #x259f)    ; Block Elements
                 (#x25a0 . #x25ff)    ; Geometric Shapes
                 (#x2600 . #x26ff)    ; Misc Symbols     -- ✳
                 (#x2700 . #x27bf)    ; Dingbats         -- ❯ ✚
                 (#x2800 . #x28ff)))  ; Braille          -- btop graphs
  (set-fontset-font t range "Terminess Nerd Font Mono" nil 'prepend))

;; Two glyphs cannot be fixed by font metrics at all.  A sweep of all 190
;; installed families found only these sources:
;;
;;   U+23FA ⏺  STIX Two Math (desc 6) or Apple Color Emoji (15/5)
;;   U+2705 ✅  Apple Color Emoji only
;;
;; Width and height scale together, so no factor gives both an 8px advance
;; and metrics inside Terminus's 13/4 -- height must win, leaving ⏺ 2px and
;; ✅/❌ 3px narrow than their cells.  In a fixed-grid buffer that shifts the
;; rest of the row and visibly breaks box-drawing tables.
;;
;; So substitute characters Terminus already has at exactly 8px.  ✅ and ❌
;; are `char-width' 2, hence a glyph PLUS a space to fill both cells.
;; Scoped to terminal buffers: only a fixed grid needs cell-exact advances,
;; and everywhere else the real glyph is preferable.
;;
;; U+276F ❯ (starship's prompt char) is also 1px narrow -- Terminess has it
;; but at a 7px advance, and scaling up to 8px pushes its ascent to 14, which
;; would make every row carrying it 18px.  U+27E9 is the closest Terminus
;; glyph by shape (tall thin chevron) and lands on 8px exactly.  Alternatives
;; if the look grates: ?› (U+203A, smaller) or ?> (plain ASCII).
;;
;; This only affects terminal-emulator buffers, so the prompt still renders as
;; ❯ in a real Ghostty window.
(defvar zetta-terminal-display-table
  (let ((dt (make-display-table)))
    (aset dt ?⏺ (vector ?●))       ; U+23FA -> U+25CF, 8px in Terminus
    (aset dt ?✅ (vector ?✓ ?\s))  ; 2 cells -> check + space = 16px
    (aset dt ?❌ (vector ?✗ ?\s))  ; 2 cells -> cross + space = 16px
    (aset dt ?❯ (vector ?⟩))       ; U+276F -> U+27E9, 8px in Terminus
    ;; Claude Code's spinner / footer glyphs, likewise absent from Terminus
    (aset dt ?✻ (vector ?*))       ; U+273B spinner
    (aset dt ?✳ (vector ?*))       ; U+2733 spinner
    (aset dt ?⏵ (vector ?▶))       ; U+23F5 footer marker
    (aset dt ?⏸ (vector ?■))       ; U+23F8 paused
    dt)
  "Display table swapping glyphs whose advance does not match their cells.
Used in terminal-emulator buffers, where a mismatched advance shifts the
rest of the row and breaks box-drawing alignment.")

(defun zetta-use-terminal-display-table ()
  "Apply `zetta-terminal-display-table' to the current buffer."
  (setq buffer-display-table zetta-terminal-display-table))

(add-hook 'ghostel-mode-hook #'zetta-use-terminal-display-table)
(add-hook 'vterm-mode-hook   #'zetta-use-terminal-display-table)

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
