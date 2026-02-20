;; -*- lexical-binding: t; -*-

(use-package dash)
(use-package dash-docs :ensure (:wait t) :demand t
  :config
  (setq dash-docs-browser-function 'eww))
(use-package dash-functional)
(use-package s)
(use-package ht)
(use-package ts)
(use-package f)

(provide 'bootstrap-utils)
