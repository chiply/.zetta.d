;;; spot4e.el --- Configure spot4e -*- lexical-binding: t; -*-

;; spotify
(use-package spot4e
  :ensure nil
  :load-path "source/zettapkg/spot4e"
  :commands (hydra-spot4e/body spot4e-refresh)

  :init
  ;; url.el messages "Contacting host: …" for every request, which the
  ;; recurring spot4e refresh turns into constant echo-area noise (and
  ;; minibuffer jitter).  Failures still surface via spot4e's own
  ;; messages (e.g. "spot: 401 …").
  (setq url-show-status nil)

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
