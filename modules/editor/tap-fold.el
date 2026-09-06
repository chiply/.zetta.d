;;; tap-fold.el --- tap-fold wrapper -*- lexical-binding: t; -*-

;; Thin wrapper around the in-tree `tap-fold' package (under
;; `source/zettapkg/').  When the package is factored out to its own
;; repo, swap `:ensure nil' + `:load-path' for `:ensure t'.
;;
;; Adds zetta-specific bits the upstream package deliberately omits:
;; - `brick' and `orgtree' added to `tap-fold-things' (so the picker
;;   offers them in this config's prose buffers).
;; - C-z in `embark-general-map' bound to `tap-fold-embark-target'.
;; - s-x prefix bindings for the top-level fold commands.

(use-package tap-fold
  :brushup
  ;; `tap-fold-preview-face' ships a fixed light/dark pair (#fff3b0 / #3a2a00).
  ;; That flips with the background but is otherwise a fixed yellow, so the
  ;; consult preview highlight clashed with any themed palette.  Re-tint it
  ;; as a faint wash of the theme's warning colour.
  (add-to-list
   'brushup-styles
   '(when (and (facep 'tap-fold-preview-face)
               (fboundp 'zetta-svg-line--dim))
      (set-face-attribute 'tap-fold-preview-face nil
                          :background (zetta-svg-line--dim
                                       (zetta-theme-color 'warning) 0.78)))
   t)

  :ensure nil
  :load-path "source/zettapkg/tap-fold"
  :config
  ;; Zetta-flavored things in the picker.
  (dolist (thing '(brick orgtree))
    (add-to-list 'tap-fold-things thing t))

  ;; Embark integration: C-z folds the active target's bounds.
  (with-eval-after-load 'embark
    (define-key embark-general-map (kbd "C-z") #'tap-fold-embark-target))

  ;; Top-level bindings on the launch-map (s-x prefix).
  (with-eval-after-load 'general
    (general-define-key
     :keymaps '(sql-mode-map lisp-mode-map lisp-interaction-mode-map
                emacs-lisp-mode-map elisp python-ts-mode-map
                yaml-mode-map sh-mode-map shell-command-mode-map
                lark-mode-map org-mode-map text-mode-map)
     "s-x f"   #'tap-fold-thing-at-point
     "s-x F"   #'tap-fold-unfold-at-point
     "s-x M-f" #'tap-fold-unfold-all
     "s-x C-f" #'tap-fold-current-thing)))

;;; tap-fold.el ends here
