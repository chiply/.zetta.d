(use-package jsonian
  :general
  (
   :keymaps '(jsonian-mode-map)
   "C-c C-j" 'jsonian-find
   )
  :hook (json-mode . jsonian-mode)
  )
