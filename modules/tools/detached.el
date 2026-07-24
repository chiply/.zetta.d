;;; detached.el --- Configure detached -*- lexical-binding: t; -*-

;; chiply/detached.el is a push-mirror of git.sr.ht/~niklaseklund/detached.el:
;; sr.ht throttles GitHub Actions runners, which made the upstream clone
;; the last chronic cold-run flake (detached "[cloning]" hang failed the
;; v0.1.36 release snapshot job, 2026-07-23).  Commit SHAs are identical
;; to upstream, so the lockfile pin holds.  Re-sync the mirror
;; (git push --mirror) only when deliberately bumping the pin.
(use-package detached
  :ensure (detached :host github :repo "chiply/detached.el")
  :config
  ;; this avoids a cryptic error.  For whatever reason I'm able to
  ;; proceed with using detached despite ignoring the error in
  ;; detached-init
  (condition-case nil (detached-init) (error nil))
  (add-hook 'detached-log-mode-hook
            '(lambda ()
               (progn
                 (compilation-minor-mode t)
                 (zetta-highlight-phrases)
                 )))
  ;;(detached-init)
  (defun zetta-detached-alert-notification (session) (ignore))

  (advice-add 'detached-shell-command :after
            (lambda (&rest args)
              (append-to-zsh-history (car args))))

  :custom ((detached-show-output-on-attach t)
           (detached-terminal-data-command system-type)
           (detached-notification-function #'zetta-detached-alert-notification))

  :general
  (
   :keymaps '(detached-log-mode-map)
   "S-<tab>" 'compilation-previous-error
   )
  )
;;; detached.el ends here
