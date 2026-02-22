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
                  (set-face-attribute 'line-number nil
                                      :foreground brushup-bg-4
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
;;; display-line-numbers.el ends here
