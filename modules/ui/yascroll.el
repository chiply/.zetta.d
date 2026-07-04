;;; yascroll.el --- Configure yascroll -*- lexical-binding: t; -*-

(use-package yascroll
  :config
  (global-yascroll-bar-mode)
  :brushup
  (setq yascroll:delay-to-hide 0.1)
  (add-to-list 'brushup-styles
               '(progn
                  (set-face-attribute 'yascroll:thumb-fringe nil
                                      :foreground "#ece4f6"
                                      :background "#ece4f6"
                                      )
                  (set-face-attribute 'yascroll:thumb-text-area nil
                                      :foreground "#ece4f6"
                                      :background "#ece4f6")
                  )))
;;; yascroll.el ends here
