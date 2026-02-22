;;; hl-line.el --- Configure hl-line -*- lexical-binding: t; -*-

(use-package hl-line
  :ensure nil
  :init
  ;; NOTE causes lagging of beacon mode, so leaving off
  (global-hl-line-mode 1)
  (make-variable-buffer-local 'global-hl-line-mode)
  (setq hl-line-overlay-priority -5000)

  ;; NOTE underline (no background keeps it from interfering with
  ;; other faces (org *highlight* for example))
  :brushup
  (add-to-list 'brushup-styles
               '(progn
                  (set-face-attribute 'hl-line nil
                                      :background 'unspecified
                                      :underline `(:color ,brushup-bg-5)))))
;;; hl-line.el ends here
