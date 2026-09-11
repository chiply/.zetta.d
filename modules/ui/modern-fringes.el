;;; modern-fringes.el --- Configure modern-fringes -*- lexical-binding: t; -*-

(use-package modern-fringes
  :config
  ;; Fringe bitmaps exist only in a build with window-system support:
  ;; `set-fringe-bitmap-face' is void on a headless Emacs (CI's batch
  ;; builds, emacs-nox), and the package calls it from both forms below.
  (when (fboundp 'set-fringe-bitmap-face)
    (modern-fringes-mode 1)
    (modern-fringes-invert-arrows))
  :brushup
  (add-to-list 'brushup-styles
               '(set-face-attribute 'modern-fringes-arrows nil
                                    :background brushup-bg-1_0 :foreground brushup-bg-3)))
;;; modern-fringes.el ends here
