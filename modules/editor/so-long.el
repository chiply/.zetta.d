;;; so-long.el --- Keep files with very long lines usable -*- lexical-binding: t; -*-

;; After James Cherti, "Is Emacs slow on files with very long lines?"
;; (2026-09-17).  Emacs 29's `long-line-threshold' keeps redisplay itself
;; bounded on a minified file or an SQL dump, but it turns nothing OFF: every
;; minor mode that walks the buffer -- the gutter, flycheck, lsp, smartparens,
;; undo-tree -- still runs over the 6000-character line.  so-long is what
;; turns them off, and its defaults throw out more than they need to: the
;; major mode, syntax highlighting, line numbers and the buffer's write bit.
;;
;; Tuned so the file stays the file.  `so-long-minor-mode' keeps the major
;; mode; font-lock stays on at the cheapest decoration level; line numbers
;; stay; the buffer stays writable; truncation and movement are left to the
;; user's own settings.  What goes is the list below -- names from modules
;; that are not loaded cost nothing, so-long only touches a mode that is
;; bound and on.
(use-package so-long
  :ensure nil
  :hook (elpaca-after-init . global-so-long-mode)
  :config
  (setq so-long-threshold 6000
        so-long-action 'so-long-minor-mode)

  ;; configs, docs and patch files hold long lines too
  (dolist (mode '(text-mode conf-mode))
    (add-to-list 'so-long-target-modes mode))

  ;; keep: syntax highlighting (at level 1, see the overrides) and line numbers
  (dolist (mode '(font-lock-mode display-line-numbers-mode))
    (setq so-long-minor-modes (delq mode so-long-minor-modes)))

  ;; drop: everything of ours that walks or watches the buffer
  (dolist (mode '(;; structure and parentheses
                  smartparens-mode smartparens-strict-mode rainbow-delimiters-mode
                  electric-pair-local-mode
                  ;; gutters, margins and the mode-line map
                  git-gutter-mode svg-margin-mode poimap-mode blamer-mode
                  trailing-newline-indicator-mode display-fill-column-indicator-mode
                  ;; checkers and servers
                  lsp-mode lsp-ui-mode flycheck-mode flymake-mode eldoc-mode copilot-mode
                  ;; highlighting and overlays
                  hl-todo-mode highlight-indent-guides-mode symbol-overlay-mode
                  evil-search-highlight-persist anzu-mode auto-composition-mode
                  ;; folding and outlines
                  outline-minor-mode hs-minor-mode vimish-fold-mode treesit-fold-mode
                  ;; history and I/O
                  undo-tree-mode auto-revert-mode
                  ;; completion
                  corfu-mode yas-minor-mode))
    (add-to-list 'so-long-minor-modes mode))

  ;; Overrides.  The buffer stays writable; font-lock at the cheapest level
  ;; for both engines; save-place must not drag point along a long line.
  (dolist (cell '((buffer-read-only . nil)
                  (treesit-font-lock-level . 1)
                  (font-lock-maximum-decoration . 1)
                  (save-place-alist . nil)))
    (setf (alist-get (car cell) so-long-variable-overrides) (cdr cell)))
  ;; And truncation and movement are the user's: by default so-long forces
  ;; wrapping (`truncate-lines' nil) and visual movement, which is the
  ;; slower combination on a long line and not how these buffers are set
  ;; up here.  Dropped from the overrides rather than set, so each buffer
  ;; keeps whatever it had.
  (dolist (var '(truncate-lines line-move-visual))
    (setq so-long-variable-overrides
          (assq-delete-all var so-long-variable-overrides))))
;;; so-long.el ends here
