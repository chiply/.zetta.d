;;; theme.el --- Configure modus-themes -*- lexical-binding: t; -*-

(use-package modus-themes
  :init
  (load-theme zetta-theme t))



;;(message "nord-theme")
;;(use-package nord-theme)
;;(message "poet-theme")
;;(use-package poet-theme)
;;(message "heroku-theme")
;;(use-package heroku-theme)
;;(message "jbeans-theme")
;;(use-package jbeans-theme)
;;(message "leuven-theme")
;;(use-package leuven-theme)
;;(message "rebecca-theme")
;;(use-package rebecca-theme)
;;(message "zenburn-theme")
;;(use-package zenburn-theme)
;;(message "lavender-theme")
;;(use-package lavender-theme)
;;(message "chocolate-theme")
;;(use-package chocolate-theme)

(custom-set-faces
 ;; `cursor' is deliberately NOT set here.  `custom-set-faces' writes into
 ;; the `user' theme, which outranks every loaded theme -- so pinning it to
 ;; "gray" masked the cursor colour every Prot theme already defines
 ;; (doric-plum sets #c070d0, for instance).  Leave it to the theme.
 '(header-line-inactive ((t (:background unspecified :foreground unspecified :inherit header-line)))))
;;; theme.el ends here
