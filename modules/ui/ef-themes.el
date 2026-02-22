;;; ef-themes.el --- Configure ef-themes -*- lexical-binding: t; -*-

(use-package ef-themes
  ;; set ef theme to ef-light
  :config
  ;; Disable any previously loaded themes to prevent stacking
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme 'ef-light t)
  ;; ensure brushup styling is applied after theme loads
  (when (fboundp 'zetta-brushup)
    (zetta-brushup)))

;;; ef-themes.el ends here
