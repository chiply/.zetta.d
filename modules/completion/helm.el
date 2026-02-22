;;; helm.el --- Configure helm -*- lexical-binding: t; -*-

(use-package helm
  :ensure t

  :general
  (
   :keymaps 'helm-map
   "C-j" 'helm-next-line
   "C-k" 'helm-previous-line
   "C-S-j" 'helm-next-source
   "C-S-k" 'helm-previous-source
   "C-M-e" 'zetta-helm-ag-edit
   )
  )
;;; helm.el ends here
