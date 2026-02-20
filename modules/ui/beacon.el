(use-package beacon
  :config
  ;; one less than hl-line, otherwise there is a weird lag
  (setq beacon-color 0.1) ;; subtle, subtle, subtle
  (setq beacon-blink-duration 0.2) ;; fast blink
  (setq beacon-blink-when-window-scrolls nil) ;; distracting, so remove
  (setq beacon-blink-when-point-moves-vertically nil)
  (setq beacon-blink-when-point-moves-horizontally nil)
  ;; NOTE stops working after a while, laggy
  (beacon-mode -1))
