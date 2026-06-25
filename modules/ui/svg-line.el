;;; svg-line.el --- Load the svg-line engine -*- lexical-binding: t; -*-

;; Loads the `svg-line' package (https://github.com/chiply/svg-line), the
;; shared engine that renders the tab-bar, tab-line, header-line and
;; mode-line as SVG.  The per-target modules (tab-bar-svg.el,
;; modeline-svg.el, tab-line-svg.el, ...) `(require 'svg-line)' and supply
;; their own content + styling via `svg-line-define'.
;;
;; This file is listed early in the :ui ordered load list (in
;; bootstrap-modules.el, before header-line-svg.el) so the engine is ready
;; before any svg consumer loads -- including the ones (tab-bar-svg,
;; modeline-svg, tab-line-svg) that fall in the alphabetical remainder
;; after the ordered files.  `:wait t' makes elpaca finish installing
;; svg-line before those `(require 'svg-line)' calls run.

(use-package svg-line
  :ensure (:host github :repo "chiply/svg-line" :wait t)
  :custom
  ;; Enlarge Nerd-Font icon glyphs (numbers, buffer/calendar icons, ...) a
  ;; touch over the 1.3 default.  This only scales the glyph tspans, not the
  ;; fixed char-advance grid, so the reserved width is unchanged and nothing
  ;; is pushed off the right edge.
  (svg-line-glyph-scale 1.4))
;;; svg-line.el ends here
