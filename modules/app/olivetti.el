;;; olivetti.el --- Configure olivetti -*- lexical-binding: t; -*-

(use-package olivetti
  :config
  ;; NOTE -- with fancy style, you get stuff in the fringe with a big
  ;; gap between what it's actually indicating... in order to get the
  ;; indicator to stretch, you need to apply a background color -- the
  ;; color will stretch even the the foreground stays centered
  (setq-default olivetti-style 'fancy)
  (setq-default olivetti-margin-width 3)
  (setq-default olivetti-body-width 0.80)
  (setq-default olivetti-minimum-body-width 80)
  (add-to-list 'brushup-styles
               '(progn
                  (set-face-attribute 'olivetti-fringe nil :background brushup-bg)
                  ))
  :general
  (
   :keymaps 'override
    "s-e" 'olivetti-mode
   )
  )
;;; olivetti.el ends here
