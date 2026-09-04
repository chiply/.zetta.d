;;; display-line-numbers.el --- Configure display-line-numbers -*- lexical-binding: t; -*-

(use-package display-line-numbers
  :ensure nil
  :init
  (setq-default
   display-line-numbers-type 'visual
   display-line-numbers-current-absolute t
   display-line-numbers-width-start 5 display-line-numbers-widen t
   display-line-numbers 'relative display-line-numbers-major-tick 20
   display-line-numbers-minor-tick 10)
  :hook (elpaca-after-init . global-display-line-numbers-mode)

  :brushup
  (add-to-list 'brushup-styles
               '(progn
                  ;; `:inherit default' is what makes line numbers scale with
                  ;; `text-scale-mode', and it has to be restated here on every
                  ;; theme change.  `line-number' ships as `:inherit (shadow
                  ;; default)', but `face-spec-recalc' skips the defface spec
                  ;; entirely once ANY theme sets the face -- and nearly every
                  ;; theme sets a line-number foreground.  The face was landing
                  ;; with no inherit at all, so it took its size from the
                  ;; FRAME's default face, which text-scale never touches.
                  ;;
                  ;; Two symptoms, one cause: the numbers stayed put while the
                  ;; text moved, and shrinking appeared to hit a floor -- a row
                  ;; is as tall as its tallest glyph, so full-size digits pin
                  ;; the line height and scaling down past a point bought only
                  ;; wider gaps, no density.
                  ;;
                  ;; Inheriting is the whole fix; do NOT also remap these faces
                  ;; from `text-scale-mode-hook'.  Remapping is RELATIVE and
                  ;; buffer-local face remapping propagates through `:inherit',
                  ;; so a remap on top of the inherit squares the factor:
                  ;; measured at 79px against a 38px default one step up, and
                  ;; at four steps down the doubly-shrunk size fell below what
                  ;; the font could render and snapped back up to 14px.
                  ;;
                  ;; `shadow' is dropped from the stock inherit list on
                  ;; purpose: it is there for the muted foreground, which the
                  ;; line below sets from the palette anyway.
                  (set-face-attribute 'line-number nil
                                      :inherit 'default
                                      :foreground brushup-bg-5
                                      :background brushup-bg)
                  (set-face-attribute 'line-number-current-line nil
                                      :inherit 'line-number
                                      :foreground brushup-bg-6
                                      :background brushup-bg
                                      :weight 'bold
                                      )
                  (set-face-attribute 'line-number-major-tick nil
                                      :inherit 'line-number
                                      :weight 'normal
                                      :foreground brushup-bg-6
                                      :background brushup-bg)
                  (set-face-attribute 'line-number-minor-tick nil
                                      :inherit 'line-number
                                      :weight 'normal
                                      :foreground brushup-bg-6
                                      :background brushup-bg)
                  ))

  :hook (((vterm-mode) . (lambda () (display-line-numbers-mode -1)))
         ((pdf-view-mode) . (lambda () (display-line-numbers-mode -1)))))

;; `global-display-line-numbers-mode' turns numbers on from
;; `after-change-major-mode-hook', which runs AFTER a major mode's own
;; hook -- so the per-mode `(display-line-numbers-mode -1)' hooks above
;; are re-overridden and do not reliably stick.  Exempt at the turn-on
;; function instead, the same way core/image.el does for image-mode and
;; friends.
;;
;; A terminal emulator is the clearest case for this: the buffer is a
;; fixed grid whose line "numbers" are just viewport rows and carry no
;; meaning, and the gutter takes real columns away from the width ghostel
;; reports to the PTY (it sizes from `window-max-chars-per-line').
(define-advice display-line-numbers--turn-on
    (:before-until () zetta-terminal-exempt)
  (derived-mode-p 'ghostel-mode))

;;; display-line-numbers.el ends here
