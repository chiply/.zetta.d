;;; dired-subtree.el --- Configure dired-subtree -*- lexical-binding: t; -*-

(require 'color)

(use-package dired-hacks
  :ensure (dired-hacks :host github :repo "Fuco1/dired-hacks"
           :files ("dired-hacks.el" "dired-hacks-utils.el" "dired-subtree.el" "dired-ranger.el")))

;; dired-subtree shades each nesting level with a background face, and those
;; faces carry HARDCODED literals -- #252e30 down to #1a191a -- with nothing
;; to recompute them.  They are near-black, chosen for a dark theme, so under
;; a light one every expanded subtree became a dark box with its own text
;; barely legible inside it.  The steps between them are ~1%, which is the
;; effect wanted: a hint of depth, not a stripe.
;;
;; So the same idea, taken off the theme instead: blend the background a
;; little further toward `brushup-bg-3' at each level.  The ladder's own rungs
;; are much coarser than 1% -- they separate whole UI surfaces -- so walking
;; them directly would be far heavier than dired-subtree ever intended.

(defcustom zetta-dired-subtree-depth-tint 'brushup-bg-3
  "Palette rung the subtree backgrounds recede toward with depth.
Deeper rungs give a stronger stripe; `brushup-bg-1' is nearly invisible."
  :type 'symbol :group 'zetta)

(defun zetta-dired-subtree-apply-palette ()
  "Tint `dired-subtree-depth-N-face' backgrounds from the current theme.
Does nothing until dired-subtree has defined the faces, so it is safe to run
on a theme change that happens before dired is ever opened."
  (when (and (boundp 'brushup-bg) (facep 'dired-subtree-depth-1-face))
    (let* ((base (color-name-to-rgb brushup-bg))
           (into (color-name-to-rgb (symbol-value zetta-dired-subtree-depth-tint)))
           (levels 6))
      (when (and base into)
        (dotimes (i levels)
          (let* ((face (intern (format "dired-subtree-depth-%d-face" (1+ i))))
                 (f (/ (float (1+ i)) levels))
                 (rgb (cl-mapcar (lambda (a b) (+ a (* f (- b a)))) base into)))
            (when (facep face)
              (set-face-attribute face nil
                                  :background (apply #'color-rgb-to-hex
                                                     (append rgb (list 2)))))))))))

(use-package dired-subtree
  :ensure nil
  :after dired-hacks
  :config
  ;; Once on load as well as on every theme change: the faces do not exist
  ;; until this package loads, so a style that ran earlier found nothing to
  ;; paint and the hardcoded defaults would stand until the next theme change.
  (zetta-dired-subtree-apply-palette)
  :brushup
  (add-to-list 'brushup-styles '(zetta-dired-subtree-apply-palette)))
;;; dired-subtree.el ends here
