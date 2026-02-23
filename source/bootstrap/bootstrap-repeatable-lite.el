;;; bootstrap-repeatable-lite.el --- Configure repeatable-lite -*- lexical-binding: t; -*-

(use-package repeatable-lite
  :ensure (:host github :repo "chiply/repeatable-lite")
  :demand t)

;; Block until repeatable-lite is installed — bootstrap-display and other
;; downstream modules use `repeatable-lite-wrap` which must be available synchronously.
(elpaca-wait)

(provide 'bootstrap-repeatable-lite)
;;; bootstrap-repeatable-lite.el ends here
