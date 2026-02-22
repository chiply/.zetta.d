;;; yascroll.el --- Configure yascroll -*- lexical-binding: t; -*-

(use-package yascroll
  :config
  (global-yascroll-bar-mode)
  :brushup
  (setq yascroll:delay-to-hide 0.1)
  (add-to-list 'brushup-styles
               '(progn
                  (set-face-attribute 'yascroll:thumb-fringe nil
                                      :foreground brushup-bg-2
                                      :background brushup-bg-2
                                      )
                  (set-face-attribute 'yascroll:thumb-text-area nil
                                      :foreground brushup-bg-2
                                      :background brushup-bg-2))))
;;; yascroll.el ends here
