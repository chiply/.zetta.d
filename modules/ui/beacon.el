;;; beacon.el --- Configure beacon -*- lexical-binding: t; -*-

(defcustom zetta-beacon-palette-rung 'brushup-bg-5
  "Palette rung the beacon flashes in.

A rung rather than a colour because the background ladder always recedes
AWAY from `brushup-bg', whichever direction the theme goes: under a light
theme these are darker than the page, under a dark one lighter.  So one
value reads correctly in both, where a literal colour would be invisible in
half the themes here.

Lower rungs are subtler, higher ones brighter."
  :type 'symbol :group 'zetta)

(defun zetta-beacon-apply-palette ()
  "Take `beacon-color' from the theme, per `zetta-beacon-palette-rung'.
A string, so beacon reads it with `color-values' rather than treating it as
a brightness fraction of plain white or black -- which is what a number
means to it, and what made the beacon theme-blind before."
  (when (boundp zetta-beacon-palette-rung)
    (setq beacon-color (symbol-value zetta-beacon-palette-rung))))

(use-package beacon
  :custom
  (beacon-blink-duration 0.2)                    ; fast blink
  (beacon-blink-when-window-scrolls nil)         ; distracting, so remove
  (beacon-blink-when-point-moves-vertically nil)
  (beacon-blink-when-point-moves-horizontally nil)
  :config
  ;; Once on load as well as on every theme change: `brushup-styles' may
  ;; already have run before this package existed.
  (zetta-beacon-apply-palette)
  ;; Previously disabled here, with the note "stops working after a while,
  ;; laggy" -- and hl-line.el still records beacon as the reason IT stays
  ;; off.  Enabled by request; if the lag returns, those two notes are where
  ;; the history is, and the scroll/motion triggers above are already the
  ;; expensive ones turned off.
  (beacon-mode 1)
  :brushup
  (add-to-list 'brushup-styles '(zetta-beacon-apply-palette)))
;;; beacon.el ends here
