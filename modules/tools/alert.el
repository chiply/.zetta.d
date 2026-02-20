(use-package alert
  :config
  (setq alert-default-style 'osx-notifier)

  ;; override
  (defun alert-osx-notifier-notify (info)
    (apply #'call-process "osascript" nil nil nil "-e"
           (list (format "display notification %S with title %S sound name %S"
                         (alert-encode-string (plist-get info :message))
                         (alert-encode-string (plist-get info :title))
                         "Frog")))
    (alert-message-notify info)))


