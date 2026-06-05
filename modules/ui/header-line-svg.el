;;; header-line-svg.el --- SVG breadcrumb header line (svg-line config) -*- lexical-binding: t; -*-

;; Configures the `svg-line' engine (source/zettapkg/svg-line) to render
;; the per-window `header-line' as a 2-line SVG image of breadcrumbs --
;; the successor to dual-header.el, now on the shared engine.  This file
;; supplies only CONTENT + styling + activation; rendering lives in
;; `svg-line'.
;;
;; The breadcrumb content (row 1 = file/path + position, row 2 =
;; lsp/org/imenu crumbs) is defined here as mode-line constructs.
;;
;; Switch at runtime:
;;   M-x zetta-header-line-use-svg    ; activate the SVG header line
;;   M-x zetta-header-line-use-none   ; remove the header line
;;   M-x zetta-header-line-toggle     ; flip

(require 'svg-line)

;;; ------------------------------------------------------------------
;;; Breadcrumb content (zetta-header-line-svg-line1/2-format and the
;;; --line1/--line2 renderers) lives in line-utils.el now; this file
;;; only composes + binds it below.
;;; ------------------------------------------------------------------

(defcustom zetta-header-line-svg-font-size 15
  "Font size (px) for SVG header-line text." :type 'integer :group 'zetta)
(defcustom zetta-header-line-svg-line-pad 4
  "Extra vertical padding (px) per SVG header-line row." :type 'integer :group 'zetta)

;;; ------------------------------------------------------------------
;;; Content -- two left-aligned breadcrumb rows.
;;; ------------------------------------------------------------------
(defun zetta-header-line-svg-lines ()
  "Return the header line as a list of (LEFT-SEGMENTS . RIGHT-SEGMENTS)."
  (list (cons '(zetta-header-line-svg--line1) nil)
        (cons '(zetta-header-line-svg--line2) nil)))

(svg-line-define 'zetta-header-line
  :target 'header-line
  :layout 'lines
  :width 'window
  :content #'zetta-header-line-svg-lines
  :font (lambda () zetta-svg-line-font)
  :font-size (lambda () (zetta-svg-line-scaled zetta-header-line-svg-font-size))
  :line-pad (lambda () zetta-header-line-svg-line-pad)
  :foreground (lambda () (or (bound-and-true-p brushup-fg-3)
                             (face-foreground 'default nil t) "#cccccc")))

;;; ------------------------------------------------------------------
;;; Switching
;;; ------------------------------------------------------------------
(defun zetta-header-line-using-svg-p ()
  "Non-nil if the SVG header line is currently active."
  (svg-line-active-p 'zetta-header-line))

;;;###autoload
(defun zetta-header-line-use-svg ()
  "Activate the SVG breadcrumb header line."
  (interactive)
  (svg-line-activate 'zetta-header-line)
  (message "header-line: SVG breadcrumbs active (M-x zetta-header-line-use-none to remove)"))

;;;###autoload
(defun zetta-header-line-use-none ()
  "Remove the header line (restore the value from before activation)."
  (interactive)
  (svg-line-deactivate 'zetta-header-line)
  (message "header-line: removed"))

;;;###autoload
(defun zetta-header-line-toggle ()
  "Toggle the SVG header line on/off."
  (interactive)
  (if (zetta-header-line-using-svg-p)
      (zetta-header-line-use-none)
    (zetta-header-line-use-svg)))

;;; ------------------------------------------------------------------
;;; Startup default (opt-out) -- dual-header was on by default.  Runs
;;; from `emacs-startup-hook' (after line.el has defined the content);
;;; sets a variable only, so it is safe on a frameless daemon start.
;;; Colours are functions read on each render, so theme changes are
;;; picked up automatically (no brushup-styles entry needed).
;;; ------------------------------------------------------------------
(defcustom zetta-header-line-svg-default t
  "When non-nil, activate the SVG header line at startup.
Switch at runtime with `zetta-header-line-toggle'."
  :type 'boolean :group 'zetta)

(when zetta-header-line-svg-default
  (add-hook 'emacs-startup-hook #'zetta-header-line-use-svg))

(provide 'header-line-svg)
;;; header-line-svg.el ends here
