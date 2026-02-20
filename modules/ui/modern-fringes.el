(use-package modern-fringes
  :config 
  (modern-fringes-mode 1)
  (modern-fringes-invert-arrows) 
  :brushup
  (add-to-list 'brushup-styles
               '(set-face-attribute 'modern-fringes-arrows nil
                                    :background brushup-bg-1_0 :foreground brushup-bg-3)))
