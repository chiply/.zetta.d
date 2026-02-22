;;; recursion-indicator.el --- Configure recursion-indicator -*- lexical-binding: t; -*-

(use-package recursion-indicator
  :hook (elpaca-after-init . recursion-indicator-mode)

    :brushup
  (add-to-list 'brushup-styles
               '(when (facep 'recursion-indicator-general)
                  (set-face-attribute 'recursion-indicator-general nil
                                      :height 0.8)
                  (set-face-attribute 'recursion-indicator-minibuffer nil
                                      :height 0.8)))

  )
;;; recursion-indicator.el ends here
