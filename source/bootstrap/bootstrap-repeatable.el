;;; bootstrap-repeatable.el --- Configure repeatable -*- lexical-binding: t; -*-

(use-package repeatable
  ;; Published recipe -- portable, works in CI and on every clone.
  ;; For local development use `M-x elpaca-pull repeatable' or override the
  ;; recipe in ~/.zetta.el (untracked); do NOT commit a local filesystem :repo
  ;; path -- it only resolves on one machine and breaks CI.
  :ensure (:host github :repo "chiply/repeatable" :wait t)
  :demand t)

;; Fallback when package is unavailable (e.g., CI with stale/missing cache):
;; return the function as-is so keybindings still work, just without repeat.
(unless (fboundp 'repeatable-wrap)
  (defmacro repeatable-wrap (fn &rest _args)
    "Fallback: return function symbol when repeatable is not installed."
    `#',fn))

(provide 'bootstrap-repeatable)
;;; bootstrap-repeatable.el ends here
