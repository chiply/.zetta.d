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
   "M-S-<tab>" 'st-switch-space-by-name
   "M-<tab>" 'st-go-to-last-space
   )
  )
