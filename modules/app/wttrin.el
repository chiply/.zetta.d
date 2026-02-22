;;; wttrin.el --- Configure wttrin -*- lexical-binding: t; -*-

(use-package wttrin
  :config
  (defun weather ()
    (interactive)
    (wttrin "Philadelphia")))
;;; wttrin.el ends here
