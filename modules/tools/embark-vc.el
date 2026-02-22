;;; embark-vc.el --- Configure embark-vc -*- lexical-binding: t; -*-

(use-package embark-vc
  :after (pr-review consult-gh)
  :config
  (setq embark-vc-review-provider 'pr-review)
  (general-define-key
   :keymaps '(consult-gh-embark-prs-edit-menu-map)
   "R" 'embark-vc-start-review)
  )
;;; embark-vc.el ends here
