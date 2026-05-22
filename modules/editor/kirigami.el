;;; kirigami.el --- Configure kirigami unified folding -*- lexical-binding: t; -*-

;; Kirigami is a unified frontend for code folding.  It dispatches its
;; six commands to whichever folding backend is active in the current
;; buffer (outline-minor-mode, org-mode, treesit-fold-mode,
;; hs-minor-mode, markdown-mode, etc).
;;
;; Backends are enabled separately:
;;   - outline-minor-mode hooks below (lispy/conf/markdown/diff)
;;   - treesit-fold-mode hooks in modules/tools/treesit-fold.el
;;   - org-mode and markdown-mode provide their own folding natively

(use-package kirigami
  :commands (kirigami-open-fold
             kirigami-open-fold-rec
             kirigami-open-folds
             kirigami-close-fold
             kirigami-close-folds
             kirigami-toggle-fold)
  :init
  (setq kirigami-preserve-visual-position t)

  (add-hook 'emacs-lisp-mode-hook #'outline-minor-mode)
  (add-hook 'lisp-interaction-mode-hook #'outline-minor-mode)
  (add-hook 'lisp-mode-hook #'outline-minor-mode)
  (add-hook 'conf-mode-hook #'outline-minor-mode)
  (add-hook 'markdown-mode-hook #'outline-minor-mode)
  (add-hook 'diff-mode-hook #'outline-minor-mode)

  :general
  (
   :states '(normal visual)
   :prefix "z"
   "o" 'kirigami-open-fold
   "O" 'kirigami-open-fold-rec
   "c" 'kirigami-close-fold
   "a" 'kirigami-toggle-fold
   "r" 'kirigami-open-folds
   "m" 'kirigami-close-folds
   ))
;;; kirigami.el ends here
