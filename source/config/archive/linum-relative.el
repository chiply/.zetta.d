(use-package linum-relative
  :brushup
  (add-to-list 'brushup-styles
               '(progn
                  (set-face-attribute 'linum nil
                                      :foreground brushup-bg-3
                                      :background brushup-bg
                                      )
                  (set-face-attribute 'linum-relative-current-face nil
                                      :foreground brushup-bg-1
                                      :background brushup-bg)
                  )
               )

  :hook (use-package--focus--post-config . (lambda () (zetta-brushup)))
  )
