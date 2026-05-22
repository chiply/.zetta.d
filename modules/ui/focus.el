;;; focus.el --- Configure focus -*- lexical-binding: t; -*-
;;
;; `focus-mode' dims everything except the current "thing" (as
;; determined by `focus-current-thing' or, as a fallback,
;; `focus-mode-to-thing'). The sync between `zetta-tap-current-thing'
;; and `focus-current-thing' lives in `zetta-tap-set-local'
;; (`modules/completion/tap.el'), so M-x zetta-tap-set-local RET
;; function RET immediately retargets focus-mode at functions.

;; Forward declaration so `(setq-local focus-current-thing …)' works
;; before the lazy `focus' package itself loads. The package's own
;; `defvar-local' of the same name is then idempotent.
(defvar-local focus-current-thing nil
  "Thing-at-point symbol focus-mode dims around.
Forward-declared here; set by `zetta-tap-set-local' so changes to
the tap thing propagate to focus-mode automatically.")

(use-package focus
  :commands focus-mode

  :brushup
  (add-to-list
   'brushup-styles
   '(progn
      (set-face-attribute 'focus-unfocused nil
                          :foreground
                          (if brushup-dark-p
                              (color-lighten-name brushup-bg 20)
                            (color-lighten-name brushup-bg -35)))))

  :general
  (
   :keymaps 'menu-window-map
   "C-f" (repeatable-lite-wrap focus-mode)
   ))
;;; focus.el ends here
