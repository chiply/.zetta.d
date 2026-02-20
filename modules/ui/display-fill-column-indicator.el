(use-package display-fill-column-indicator
  :ensure nil
  :hook (elpaca-after-init . global-display-fill-column-indicator-mode)

  :brushup
  
  (add-to-list 'brushup-styles
               '(progn
                  ;; provides subtlety, but still keeps it visible on
                  ;; the current line since the background is
                  ;; brushup-bg...
                  (set-face-attribute 'fill-column-indicator nil
                                      :background brushup-bg
                                      :foreground brushup-bg-1_0
                                      )
                  )
               )
  )
