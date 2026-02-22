;;; awesome-tray.el --- Configure mode-line styles -*- lexical-binding: t; -*-

(use-package celestial-mode-line)
(use-package awesome-tray
  :ensure (awesome-tray :type git :host github :repo "manateelazycat/awesome-tray")
  :config
  ;;;; NOTE this does actually work, but will actually result in
  ;;;; growing and shrinking of the echo area when going into and out
  ;;;; of consult, or anything that uses the minibuffer to prompt.
  ;;;; this snapping rarely results in rendering issues where the
  ;;;; modeline get's halved when the echo area regrows coming out of
  ;;;; a minibuffer interaction.  leaving on the default to avoid that
  ;;;; for now.
  ;;(setq awesome-tray-second-line t)
  ;;(setq awesome-tray-position 'center)

  (setq awesome-tray-hide-mode-line nil)
  ;; only gets so instantaneous, remove things that benefit from
  ;; instant feedback (like location, na)
  (setq awesome-tray-refresh-idle-delay 0.01)
  (setq awesome-tray-update-interval 1)
  (setq awesome-tray-belong-update-duration 0.1)
  (setq awesome-tray-active-modules
        ;; NOTE update
        '("last-command" "belong" "hostname" "file-path" "mode-name"
          "battery" "date" "celestial" "pdf-view-page" "input-method"
          "buffer-read-only"))
  ;; TODO may interfere with which key help
  ;;(awesome-tray-mode 1)
  )
;;; awesome-tray.el ends here
