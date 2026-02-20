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
  :demand t
  :after (corfu prescient)
  :config
  (corfu-prescient-mode t)
  )

(use-package vertico-prescient
  :demand t
  :after (prescient vertico)
  :config
  (setq vertico-prescient-enable-sorting t)
  (setq vertico-prescient-enable-filtering t)
  (setq vertico-prescient-completion-styles
        '(tab prescient orderless basic))
  (vertico-prescient-mode t))

