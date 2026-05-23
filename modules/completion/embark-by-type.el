;;; embark-by-type.el --- embark-by-type wrapper -*- lexical-binding: t; -*-

;; Thin wrapper around the in-tree `embark-by-type' package (under
;; `source/zettapkg/').  When the package is factored out to its own
;; repo, swap `:ensure nil' + `:load-path' for `:ensure t'.
;;
;; Adds zetta-specific bits the upstream package deliberately omits:
;; - Custom symbol target types covering elisp `defvar' / `macro' / &c.
;; - Custom nav-type-map entries for treesit `ts-*' types (registered
;;   from `treesit-tap-embark-types' if treesit-tap-embark is loaded).
;; - Optional: enables `embark-by-type-target-word-at-point' as a finder.

(use-package embark-by-type
  :ensure nil
  :load-path "source/zettapkg/embark-by-type"
  :after embark
  :config
  ;; Enable the suite (capture-mode + sort + back-cycle + bindings +
  ;; defun-map).
  (embark-by-type-setup)

  ;; Word as an embark target finder (gated to prose + elisp).
  (add-to-list 'embark-target-finders
               #'embark-by-type-target-word-at-point)

  ;; Register zetta-flavored TAP-thing finders.  brick comes from
  ;; `treesit-tap.el' wrapper; line/sentence/paragraph are stock
  ;; thing-at-point things that embark's built-ins skip in most
  ;; modes; orgtree is defined in `modules/org/org.el'.
  (embark-by-type-deftap-finder brick)
  (embark-by-type-deftap-finder line)
  (embark-by-type-deftap-finder sentence)
  (embark-by-type-deftap-finder paragraph)
  (embark-by-type-deftap-finder orgtree)

  ;; Extend nav-type-map with zetta-flavored entry for `brick'.
  (setf (alist-get 'brick embark-by-type-nav-type-map) 'brick)

  ;; Zetta-specific ts-* nav mappings: when the treesit-tap-embark
  ;; sub-extension has populated `treesit-tap-embark-types', map each
  ;; `ts-<TYPE>' to a sensible thing for nav purposes.  Falls back
  ;; gracefully when treesit-tap-embark isn't loaded.
  (with-eval-after-load 'treesit-tap-embark
    (when (boundp 'treesit-tap-embark-types)
      (dolist (ts-type treesit-tap-embark-types)
        (let ((sym (intern (concat "ts-" ts-type))))
          (unless (alist-get sym embark-by-type-nav-type-map)
            (setf (alist-get sym embark-by-type-nav-type-map)
                  (cond
                   ((string-match-p "function\\|method" ts-type) 'function)
                   ((string-match-p "class" ts-type) 'class)
                   ((string-match-p "call" ts-type) 'call)
                   ((string-match-p "string" ts-type) 'str-lit)
                   (t 'sexp)))))))))

;;; embark-by-type.el ends here
