;;; prescient.el --- Configure prescient -*- lexical-binding: t; -*-

;; NOTE using for sorting

;; NOTE doesn't work for some commands, for example, doesn't work for
;; consult-gh -- TODO can I customize this?

;; NOTE consult also disables sorting in certain cases where it
;; doesn't make sense (eg consult-line)

(use-package prescient
  :demand t
  :after orderless
  :config
  (prescient-persist-mode t))

(use-package corfu-prescient
  :ensure (corfu-prescient :repo "radian-software/prescient.el"
                           :files ("corfu-prescient.el"))
  :demand t
  :after (corfu prescient)
  :config
  (corfu-prescient-mode t)
  )

(use-package vertico-prescient
  :ensure (vertico-prescient :repo "radian-software/prescient.el"
                             :files ("vertico-prescient.el"))
  :demand t
  :after (prescient vertico)
  :config
  (setq vertico-prescient-enable-sorting t)
  (setq vertico-prescient-enable-filtering t)
  (setq vertico-prescient-completion-styles
        '(tab prescient orderless basic))
  (vertico-prescient-mode t))
;;; prescient.el ends here
