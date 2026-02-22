;;; gnus.el --- Configure gnus -*- lexical-binding: t; -*-

(use-package gnus
  :ensure nil
  :commands gnus
  :config
  (setq gnus-select-method '(nnnil ""))
  (setq gnus-secondary-select-methods '((nntp "news.gmane.io")))
  (setq gnus-check-new-newsgroups 'ask-server)
  )
;;; gnus.el ends here
