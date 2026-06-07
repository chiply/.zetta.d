;;; tooltip.el --- Show help-echo in the echo area, not a tooltip frame -*- lexical-binding: t; -*-

;; Display `help-echo' (hover help) in the echo area instead of a pop-up
;; tooltip.  Why:
;;
;; - Emacs's own tooltips (`use-system-tooltips' nil) honour `tooltip-delay'
;;   and are fast, but each is a separate top-level FRAME -- which a tiling
;;   window manager (aerospace) treats as a window and tiles, snapping the
;;   Emacs frame to half the screen.
;; - macOS native tooltips (`use-system-tooltips' t) don't get tiled, but
;;   their delay is system-controlled (~1s) and ignores `tooltip-delay', so
;;   they feel sluggish.
;;
;; Echo-area help sidesteps both: no frame (nothing for the WM to tile) and
;; it appears instantly -- a stronger "this is interactive" cue.  The
;; svg-margin gutter shows its hover help with a contrasting background
;; (`svg-margin-help-face'), which stands out well in the echo area.
;;
;; This is global: ALL help-echo now shows in the echo area rather than a
;; tooltip.  To restore pop-up tooltips, (tooltip-mode 1).

(tooltip-mode -1)

;;; tooltip.el ends here
