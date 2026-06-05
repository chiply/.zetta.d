;;; svg-line.el --- Load the svg-line engine -*- lexical-binding: t; -*-

;; Loads the in-tree `svg-line' package (source/zettapkg/svg-line), the
;; shared engine that renders the tab-bar, tab-line, header-line and
;; mode-line as SVG.  The per-target modules (tab-bar-svg.el,
;; modeline-svg.el, tab-line-svg.el, ...) `(require 'svg-line)' and supply
;; their own content + styling via `svg-line-define'.
;;
;; This file is listed early in the :ui ordered load list (in
;; bootstrap-modules.el, before header-line-svg.el) so the engine and its
;; load-path entry are ready before any svg consumer loads -- including
;; the ones (tab-bar-svg, modeline-svg, tab-line-svg) that fall in the
;; alphabetical remainder after the ordered files.

(use-package svg-line
  :ensure nil
  :load-path "source/zettapkg/svg-line"
  :config
  ;; Optional icon bridge: lets the tab-bar / tab-line draw real vector
  ;; icons.  Requiring it does NOT pull in svg-lib -- that is loaded lazily
  ;; (off the render path) only when an icon is actually harvested.
  (require 'svg-line-icons))
;;; svg-line.el ends here
