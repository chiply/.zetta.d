;;; present.el --- CLIM-style presentation types wrapper -*- lexical-binding: t; -*-

;; Thin wrapper around the in-tree `present' package (under
;; `source/zettapkg/').  When the package is factored out to its own
;; repo, swap `:ensure nil' + `:load-path' for `:ensure t'.
;;
;; Adds zetta-specific integration:
;;   - Picker bindings in the minibuffer keymap (`M-i' / `C-c i').
;;   - Tree-sitter types from `treesit-tap-embark-types' registered
;;     into `present-types' (so picking accepts AST node types).
;;   - The richer zetta-embark visible-instance collector wired in as
;;     `present-collect-extra-fn' when embark is loaded.

(use-package present
  :ensure nil
  :load-path "source/zettapkg/present"
  :bind (:map minibuffer-local-map
              ("M-i"   . present-pick-avy)
              ("C-c i" . present-pick-completing-read))
  :config
  ;; Capture the calling command at minibuffer setup so we can recover
  ;; an expected type for bare `read-string' prompts via
  ;; `present-command-type-map' (e.g. browse-url → url).
  (present-mode 1)

  ;; Register tree-sitter presentation types from the embark side.
  (when (boundp 'treesit-tap-embark-types)
    (dolist (ts-type treesit-tap-embark-types)
      (let ((sym (intern (format "ts-%s" ts-type))))
        (unless (alist-get sym present-types)
          (setf (alist-get sym present-types)
                (list :parent 'string :embark sym))))))

  ;; When embark is loaded, use zetta-embark's collector for the WINDOW
  ;; under scan.  It returns plain (BEG . END) cons cells filtered to
  ;; the selected window's visible range, with treesit-aware position
  ;; walking that captures nested bounds.  The collector signature is
  ;; (TYPE THING) and it operates on the currently-selected window, so
  ;; we briefly switch into the window being scanned.
  (with-eval-after-load 'embark
    (when (fboundp 'embark-scope-collect-visible-instances)
      (setq present-collect-extra-fn
            (lambda (expected win buf _beg _end)
              (when (and expected
                         ;; Skip when the type has its own :finder — that
                         ;; finder is already comprehensive (e.g. URL in
                         ;; eww/org/plain), and double-collection just
                         ;; produces dupes to dedupe.
                         (not (present-type-prop expected :finder))
                         ;; And skip when the type carries no embark/thing
                         ;; mapping — `embark-scope-collect-visible-instances'
                         ;; would otherwise be called with `string' / a root
                         ;; type and return nothing useful (or error).
                         (or (present-type-prop expected :embark)
                             (present-type-prop expected :thing)))
                (let* ((embark-type (or (present-type-prop expected :embark)
                                        expected))
                       (thing (or (present-type-prop expected :thing)
                                  embark-type))
                       (bounds-list
                        (with-selected-window win
                          (with-current-buffer buf
                            (ignore-errors
                              (embark-scope-collect-visible-instances
                               embark-type thing))))))
                  (mapcar
                   (lambda (b)
                     (let* ((beg (car b))
                            (end (cdr b))
                            (text (with-current-buffer buf
                                    (buffer-substring-no-properties
                                     beg end))))
                       (list :type expected
                             :value text
                             :buffer buf
                             :window win
                             :beg beg
                             :end end
                             :text text)))
                   bounds-list))))))))

;;; present.el ends here
