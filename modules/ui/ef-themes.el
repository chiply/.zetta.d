;;; ef-themes.el --- Configure ef-themes -*- lexical-binding: t; -*-

(use-package ef-themes
  ;; set ef theme to ef-light
  :config
  ;; Disable any previously loaded themes to prevent stacking
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme 'ef-light t)
  ;; Emacs 31 has header-line-active/header-line-inactive as built-in faces.
  ;; Unify them so inactive header-line matches active.
  (set-face-attribute 'header-line-inactive nil :inherit 'header-line
                      :background 'unspecified :foreground 'unspecified)
  (when (facep 'header-line-active)
    (set-face-attribute 'header-line-active nil :inherit 'header-line
                        :background 'unspecified :foreground 'unspecified))
  ;; ensure brushup styling is applied after theme loads
  (when (fboundp 'brushup)
    (brushup)))

;;; ef-themes.el ends here
