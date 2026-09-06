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
                  ;; Colours only -- the `:inherit' that makes these scale
                  ;; lives in an override spec below, which needs no re-running.
                  (set-face-attribute 'line-number nil
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

;; `:inherit' is what makes line numbers scale with `text-scale-mode':
;; buffer-local face remapping propagates through it, so inheriting `default'
;; means inheriting the remapped size.  `line-number' ships as
;; `:inherit (shadow default)' and the stock behaviour is correct.
;;
;; Keeping it is the hard part.  `face-spec-recalc' skips the defface spec
;; entirely once ANY theme sets the face, and TWO things here do: nearly every
;; theme sets a line-number foreground, and fontaine writes its presets as a
;; `fontaine' theme carrying `:line-number-family'.  Either one lands the face
;; with no inherit at all, so it sizes from the FRAME's default face, which
;; text-scale never touches.  Restating it with `set-face-attribute' from
;; `brushup-styles' is not enough either: that only re-runs on a theme change,
;; and a fontaine PRESET change wipes it again -- which is exactly how this
;; came back the moment a gohufont preset was selected.
;;
;; `face-override-spec' is applied last by `face-spec-recalc', after every
;; theme spec, so it survives a theme change, a preset change and new frames
;; alike, and never needs re-running.
;;
;; Two symptoms, one cause: the numbers stayed put while the text moved, and
;; shrinking appeared to hit a floor -- a row is as tall as its tallest glyph,
;; so full-size digits pin the line height and scaling down past a point
;; bought only wider gaps, no density.
;;
;; Inheriting is the WHOLE fix.  Do NOT also remap these faces from
;; `text-scale-mode-hook': remapping is relative and propagates through the
;; inherit too, so it squares the factor -- measured at 79px against a 38px
;; default one step up, and four steps down the doubly-shrunk size fell below
;; what the font could render and snapped back up to 14px.
;;
;; `shadow' is dropped from the stock inherit list on purpose: it is there for
;; the muted foreground, which the brushup style above sets from the palette.
(dolist (spec '((line-number              . default)
                (line-number-current-line . line-number)
                (line-number-major-tick   . line-number)
                (line-number-minor-tick   . line-number)))
  (when (facep (car spec))
    (face-spec-set (car spec) `((t :inherit ,(cdr spec))) 'face-override-spec)))

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
