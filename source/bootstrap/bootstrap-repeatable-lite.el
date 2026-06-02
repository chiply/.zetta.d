;;; bootstrap-repeatable-lite.el --- Configure repeatable-lite -*- lexical-binding: t; -*-

(use-package repeatable-lite
  ;; Local development checkout (was :host github :repo "chiply/repeatable-lite").
  ;; To pick up new commits: M-x elpaca-pull repeatable-lite (fetch + rebuild).
  :ensure (:repo "/Users/charlieholland/source_code/repeatable-lite" :wait t)
  :demand t)

;; Fallback when package is unavailable (e.g., CI with stale/missing cache):
;; return the function as-is so keybindings still work, just without repeat.
(unless (fboundp 'repeatable-lite-wrap)
  (defmacro repeatable-lite-wrap (fn &rest _args)
    "Fallback: return function symbol when repeatable-lite is not installed."
    `#',fn))

(provide 'bootstrap-repeatable-lite)
;;; bootstrap-repeatable-lite.el ends here
