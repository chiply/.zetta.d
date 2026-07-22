;;; bootstrap-repeatable.el --- Configure repeatable -*- lexical-binding: t; -*-

;; repeatable declares Package-Requires ((emacs "30.1")), so on older
;; Emacsen elpaca can only ever refuse the order -- which then trips CI's
;; any-failed-package gate even though the fallback below is the designed
;; degraded mode for exactly this case.  Gate the order on the requirement
;; instead of queueing a guaranteed failure.
(when (version<= "30.1" emacs-version)
  (use-package repeatable
    ;; Published recipe -- portable, works in CI and on every clone.
    ;; For local development use `M-x elpaca-pull repeatable' or override the
    ;; recipe in ~/.zetta.el (untracked); do NOT commit a local filesystem :repo
    ;; path -- it only resolves on one machine and breaks CI.
    :ensure (:host github :repo "chiply/repeatable" :wait t)
    :demand t))

;; Fallback when package is unavailable (e.g., CI with stale/missing cache):
;; return the function as-is so keybindings still work, just without repeat.
(unless (fboundp 'repeatable-wrap)
  (defmacro repeatable-wrap (fn &rest _args)
    "Fallback: return function symbol when repeatable is not installed."
    `#',fn))

;; Short in-config alias: `**' is how keybinding modules wrap a command to
;; make it repeatable.  Defined here (after `repeatable-wrap' is guaranteed to
;; exist, real or fallback) so it is available before any module loads.
(defalias '** 'repeatable-wrap
  "Alias for `repeatable-wrap': wrap a command to make it repeatable.")

(provide 'bootstrap-repeatable)
;;; bootstrap-repeatable.el ends here
