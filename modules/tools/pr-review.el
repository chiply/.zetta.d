;;; pr-review.el --- Configure pr-review -*- lexical-binding: t; -*-

(use-package pr-review

  :config
  (general-unbind :keymaps 'magit-status-mode-map :states 'normal "C-<tab>")
  (general-unbind :keymaps 'magit-mode-map :states 'normal "C-<tab>")
  (general-unbind :keymaps 'magit-section-mode-map :states 'normal "C-<tab>")

  (general-unbind :keymaps 'magit-status-mode-map :states 'normal "C-S-<tab>")
  (general-unbind :keymaps 'magit-mode-map :states 'normal "C-S-<tab>")
  (general-unbind :keymaps 'magit-section-mode-map :states 'normal "C-S-<tab>")

  (general-unbind :keymaps 'magit-status-mode-map :states 'normal "M-<tab>")
  (general-unbind :keymaps 'magit-mode-map :states 'normal "M-<tab>")
  (general-unbind :keymaps 'magit-section-mode-map :states 'normal "M-<tab>")

  (general-unbind :keymaps 'magit-status-mode-map :states 'normal "M-S-<tab>")
  (general-unbind :keymaps 'magit-mode-map :states 'normal "M-S-<tab>")
  (general-unbind :keymaps 'magit-section-mode-map :states 'normal "M-S-<tab>")

  (general-define-key
   :keymaps '(pr-review-mode-map)
   "C-<tab>" 'tab-line-switch-to-next-tab
   "C-S-<tab>" 'tab-line-switch-to-prev-tab
   "M-S-<tab>" 'space-tree-switch-space-by-name
   "M-<tab>" 'space-tree-go-to-last-space
   )
  )
;;; pr-review.el ends here
