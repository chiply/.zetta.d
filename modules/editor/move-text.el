;;; move-text.el --- Configure move-text -*- lexical-binding: t; -*-

(use-package move-text
  ;; NOTE -- works well on single line, not so much with region as the
  ;; region gets deselcted not with evil at least
  :config
  (move-text-default-bindings)
  )
;;; move-text.el ends here
