;;; bootstrap-gcmh.el --- GC management via gcmh -*- lexical-binding: t; -*-

;; The intermittent ~1s buffer-switch lag in long sessions is garbage
;; collection: with `gc-cons-threshold' reset to 16MB after init, GC fires
;; often, and on a large heap (a day-long session, many buffers, lots of SVG
;; margin/modeline images) a single collection costs 141ms-1.5s.  Roughly a
;; third of switches trip one mid-redisplay -> the hitch.
;;
;; gcmh keeps `gc-cons-threshold' high during activity so GC almost never
;; fires mid-command, and collects during idle instead -- moving the pause
;; off the interaction path.  gcmh owns GC from here, so the early-init
;; `zetta--restore-gc' (which would reset to 16MB) is cancelled.

(use-package gcmh
  :ensure t
  :init
  ;; Cancel the early-init reset to 16MB and hold a safe baseline until
  ;; `gcmh-mode' takes over (this also covers the case where gcmh fails to
  ;; build -- the threshold stays sane rather than 16MB or unbounded).
  (when (fboundp 'zetta--restore-gc)
    (remove-hook 'emacs-startup-hook #'zetta--restore-gc))
  (setq gc-cons-threshold (* 128 1024 1024))
  :config
  (setq gcmh-idle-delay 'auto                 ; scale idle delay to GC cost
        gcmh-auto-idle-delay-factor 10
        gcmh-high-cons-threshold (* 256 1024 1024))
  (gcmh-mode 1))

(provide 'bootstrap-gcmh)
;;; bootstrap-gcmh.el ends here
