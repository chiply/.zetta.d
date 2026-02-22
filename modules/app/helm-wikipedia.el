;;; helm-wikipedia.el --- Configure helm-wikipedia -*- lexical-binding: t; -*-

(use-package helm-wikipedia
  :general
  (
   :keymaps '(helm-wikipedia-map)
   "<return>" 'helm-wikipedia-show-summary-action
   )
  (
   :keymaps 'menu-lookup-map
   "w" 'helm-wikipedia-suggest
   )
  )
;;; helm-wikipedia.el ends here
