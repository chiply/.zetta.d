;;; bootstrap-compile-angel.el --- Auto byte/native compilation -*- lexical-binding: t; -*-

;; Ensures all loaded .el files are byte-compiled and native-compiled
;; automatically, closing the gap between edits and compilation without
;; needing to run `zetta sync' manually.
;;
;; Installed directly via `elpaca' + `elpaca-wait' rather than
;; use-package, because this loads before elpaca-use-package-mode has
;; fully initialised the declaration pipeline.

(elpaca compile-angel)
(elpaca-wait)

(require 'compile-angel)
(setq compile-angel-verbose t)

;; Exclude init files per compile-angel recommendations — these use
;; macros (use-package, elpaca) that can cause issues when compiled.
;; Exclude elpaca packages (already compiled during build) and
;; zettapkg sources (missing lexical-binding headers).
;; Exclude bootstrap directory — its .elc files are managed by
;; `zetta sync`/`install`.  If compile-angel compiles them on load,
;; the resulting .elc becomes stale after edits and
;; load-prefer-newer=nil loads the stale bytecode on next startup.
(setq compile-angel-excluded-files-regexps
      '("/init\\.el\\'"
        "/early-init\\.el\\'"
        "/\\.zetta\\.el\\'"
        "/\\.private\\.el\\'"
        "/elpaca/"
        "/zettapkg/"
        "/source/bootstrap/"))

(compile-angel-on-load-mode 1)

(provide 'bootstrap-compile-angel)
;;; bootstrap-compile-angel.el ends here
