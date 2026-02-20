(use-package detached
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


