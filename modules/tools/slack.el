;;; slack.el --- Configure emacs-slack -*- lexical-binding: t; -*-

(use-package slack
  :commands (slack-start slack-select-rooms slack-select-unread-rooms)
  :custom
  (slack-prefer-current-team t)
  (slack-quick-update t)
  :config
  ;; note username is arbitrary
  (slack-register-team
   :name "myworkspace"
   :token (auth-source-pick-first-password
           :host "app.slack.com"
           :user "you@example.com")
   :cookie (auth-source-pick-first-password
            :host "app.slack.com"
            :user "you@example.com^cookie")
   :full-and-display-names t
   :default t)

  (slack-register-team
   :name "dagster"
   :token (auth-source-pick-first-password
           :host "dagster.slack.com"
           :user "you@example.com")
   :cookie (auth-source-pick-first-password
            :host "dagster.slack.com"
            :user "you@example.com^cookie")
   :full-and-display-names t))
;;; slack.el ends here
