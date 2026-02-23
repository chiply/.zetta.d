;;; bootstrap-repeatable-lite.el --- Configure repeatable-lite -*- lexical-binding: t; -*-

(use-package repeatable-lite
  :ensure (:host github :repo "chiply/repeatable-lite")
  :demand t)

;; Block until repeatable-lite is installed — bootstrap-display and other
;; downstream modules use `repeatable-lite-wrap` which must be available synchronously.
(elpaca-wait)

;; Fallback when package is unavailable (e.g., CI with stale/missing cache):
;; return the function as-is so keybindings still work, just without repeat.
(unless (fboundp 'repeatable-lite-wrap)
  (defmacro repeatable-lite-wrap (fn &rest _args)
    "Fallback: return function symbol when repeatable-lite is not installed."
    `#',fn))

(provide 'bootstrap-repeatable-lite)
;;; bootstrap-repeatable-lite.el ends here
