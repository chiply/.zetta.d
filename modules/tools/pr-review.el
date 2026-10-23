;;; pr-review.el --- Configure pr-review -*- lexical-binding: t; -*-

;; Deferred to its commands: loaded eagerly, it pulled magit, forge and
;; ghub into every startup (OPTIMIZATIONS.org "145 eager use-package
;; blocks").  The tab-switch unbinds it used to carry belong to magit and
;; are installed when magit loads, whether or not pr-review ever does.
(with-eval-after-load 'magit
  (dolist (key '("C-<tab>" "C-S-<tab>" "M-<tab>" "M-S-<tab>"))
    (general-unbind :keymaps 'magit-status-mode-map :states 'normal key)
    (general-unbind :keymaps 'magit-mode-map :states 'normal key)
    (general-unbind :keymaps 'magit-section-mode-map :states 'normal key)))

(use-package pr-review
  :commands (pr-review pr-review-open pr-review-open-url pr-review-notification
             pr-review-search pr-review-search-open)
  :config
  (general-define-key
   :keymaps '(pr-review-mode-map)
   "C-<tab>" 'tab-line-switch-to-next-tab
   "C-S-<tab>" 'tab-line-switch-to-prev-tab
   "M-S-<tab>" 'space-tree-switch-space-by-name
   "M-<tab>" 'space-tree-go-to-last-space))
;;; pr-review.el ends here
