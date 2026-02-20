(use-package sh-script
  :ensure nil
  :mode (("\\.env\\'" . sh-mode)
         ("\\.env.template\\'" . sh-mode)
         ("\\.env.sample\\'" . sh-mode))

  :general
  (
   :states '(normal visual)
   :keymaps '(sh-mode-map)
   "C-e" 'er/expand-region
   )
  
  )
