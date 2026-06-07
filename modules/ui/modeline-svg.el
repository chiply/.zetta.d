;;; modeline-svg.el --- SVG multi-line mode line (svg-line config) -*- lexical-binding: t; -*-

;; Configures the `svg-line' engine (source/zettapkg/svg-line) to render a
;; per-window, multi-line mode line, with active/inactive styling.  This
;; file supplies only CONTENT + styling + activation policy; rendering
;; lives in `svg-line'.
;;
;; It RECREATES the data from `telephone-line.el' as TEXT.  telephone-line
;; is mostly icons/animations, which single-font SVG text cannot draw, so
;; those become short text labels or are dropped; the textual segments
;; (modal tag, ace path, repo:branch, flycheck, R/T/D/N/H indicators, doc
;; position, point position) recreate faithfully.
;;
;; Switch at runtime:
;;   M-x zetta-modeline-use-svg            ; activate this renderer
;;   M-x zetta-modeline-use-telephone-line ; restore telephone-line
;;   M-x zetta-modeline-toggle             ; flip

(require 'svg-line)

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
(defcustom zetta-modeline-svg-char-advance 8
  "Per-character advance (px) for rows laid out by run (pies/bars/segments).
Match it to the SVG font's real glyph width as librsvg renders it (~8 for the
bitmap Terminess Nerd Font Mono at 15px scaled).  Used to position progress
pies/bars and interactive segments (clickable indicators) and to right-align
their rows; plain all-text rows use exact font anchoring and ignore it.  If a
clickable indicator's hover box sits too far left (overlapping the previous
text) raise this; if it sits too far right (a gap before the text) lower it."
  :type 'number :group 'zetta)
(defcustom zetta-modeline-svg-right-margin 8
  "Pixels of inset kept between right-aligned text and the window edge."
  :type 'integer :group 'zetta)

(defcustom zetta-modeline-svg-bg-active "#e7edf6"
  "Background of the SVG mode line in the SELECTED window.  nil = transparent.
A subtle, light blue-tinted shade; distinct from (and slightly more
present than) `zetta-modeline-svg-bg-inactive' to recreate Emacs's
active/inactive mode-line distinction."
  :type '(choice (const :tag "Transparent" nil) color) :group 'zetta)

(defcustom zetta-modeline-svg-bg-inactive "#f3f6fb"
  "Background of the SVG mode line in NON-selected windows.  nil = transparent.
A barely-there light tint."
  :type '(choice (const :tag "Transparent" nil) color) :group 'zetta)

;;; ------------------------------------------------------------------
;;; Text segments (zetta-modeline-svg--modal/--vc/--flycheck/...) live in
;;; line-utils.el now; this file only composes + binds them below.
;;; ------------------------------------------------------------------

;;; ------------------------------------------------------------------
;;; Content -- rows of (LEFT-SEGMENTS . RIGHT-SEGMENTS)
;;; ------------------------------------------------------------------
(defun zetta-modeline-svg-lines ()
  "Return the mode line as a list of (LEFT-SEGMENTS . RIGHT-SEGMENTS)."
  (list
   ;; line 1:  [file] modal | ace | buffer        ......   mode | line:col
   (cons '(zetta-modeline-svg--file-icon " "
           zetta-modeline-svg--modal " " zetta-modeline-svg--ace " "
           zetta-modeline-svg--buffer)
         '(zetta-modeline-svg--mode "  " zetta-modeline-svg--point))
   ;; line 2:  git:branch (clickable -> magit) | [copilot] lsp | flycheck | flags
   ;;          ......   doc-position | <progress pie>
   ;; (the git + branch glyphs are folded into the clickable vc segment)
   (cons '(zetta-modeline-svg--vc " "
           zetta-modeline-svg--copilot-icon " " zetta-modeline-svg--checkers
           zetta-modeline-svg--flycheck " " zetta-modeline-svg--indicators)
         '(zetta-modeline-svg--docpos " " zetta-modeline-svg--file-progress))))

(svg-line-define 'zetta-mode-line
  :target 'mode-line
  :layout 'lines
  :width 'window
  :content #'zetta-modeline-svg-lines
  :active #'mode-line-window-selected-p
  :font (lambda () zetta-svg-line-font)
  :font-size (lambda () zetta-modeline-svg-font-size)
  :line-pad (lambda () zetta-modeline-svg-line-pad)
  :char-advance (lambda () zetta-modeline-svg-char-advance)
  :right-margin (lambda () zetta-modeline-svg-right-margin)
  :foreground (lambda () (or (bound-and-true-p brushup-fg-3)
                             (face-foreground 'mode-line nil t) "#cccccc"))
  :inactive-foreground (lambda () (or (face-foreground 'mode-line-inactive nil t) "#777777"))
  :background (lambda () zetta-modeline-svg-bg-active)
  :inactive-background (lambda () zetta-modeline-svg-bg-inactive))

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
  (if (fboundp 'telephone-line-mode)
      (telephone-line-mode 1)
    (force-mode-line-update t))
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
