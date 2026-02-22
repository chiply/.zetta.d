;;; mastodon.el --- Configure mastodon -*- lexical-binding: t; -*-

(use-package mastodon
  ;;:ensure (mastodon :host codeberg :repo "martianh/mastodon.el")
  :config
    (setq mastodon-instance-url "https://mastodon.social"
          mastodon-active-user "charliebholland")
  )
;;; mastodon.el ends here
