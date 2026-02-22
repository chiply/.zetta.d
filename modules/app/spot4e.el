;;; spot4e.el --- Configure spot4e -*- lexical-binding: t; -*-

;; spotify
(use-package spot4e
  :ensure nil
  :load-path "source/zettapkg/spot4e"
  :commands (hydra-spot4e/body spot4e-refresh)

  :config
  (run-with-timer 0 (* 60 59) 'spot4e-refresh)

  :general
  (
   :keymaps 'evil-insert-state-map
   (general-chord ",q") 'hydra-spot4e/body
   )
  (
   :states '(normal visual)
   :keymaps 'override
   :prefix ","
   "q" 'hydra-spot4e/body
   )

  )
;;; spot4e.el ends here
