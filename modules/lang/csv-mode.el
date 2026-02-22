;;; csv-mode.el --- Configure csv-mode -*- lexical-binding: t; -*-

(use-package csv-mode
  :config
  (setq csv-align-max-width 40)
  (setq csv-align-style 'auto)
  (setq csv-align-padding 2)
  (add-hook 'csv-mode-hook
            (lambda () (csv-align-mode +1)))

  ;; note: align mode breaks when increasing text-scale, so disable this...
  :hook
  (csv-mode . (lambda () (setq-local zetta-zen-disable t) (text-scale-adjust 0)))
  )
;;; csv-mode.el ends here
