;; spotify
(use-package spot
  :ensure nil
  :load-path "~/.zetta.d/source/zettapkg/spot"
  :after (consult consult-omni ht marginalia embark)
  :demand t
  :config
  (run-with-timer 0 (* 60 59) 'spot-refresh)
  (spot--start-update-timer))
