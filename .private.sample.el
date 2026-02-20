;;; .private.sample.el --- Template for ~/.private.el  -*- lexical-binding: t; -*-
;;
;; Copy this file to ~/.private.el and fill in your credentials.
;; ~/.private.el is loaded early in init.el and is NOT tracked by git.

;; IRC (erc)
(setq erc-nick "YOUR_IRC_NICK")
(setq erc-user-full-name "Your Name")

;; Spotify (spot4e)
(setq spot4e-client-id "YOUR_SPOTIFY_CLIENT_ID")
(setq spot4e-client-secret "YOUR_SPOTIFY_CLIENT_SECRET")
(setq spot4e-refresh-token "YOUR_SPOTIFY_REFRESH_TOKEN")

;; Wallabag (wombag)
(setq wombag-host "https://your-wallabag-instance.example.com"
      wombag-username "YOUR_USERNAME"
      wombag-password "YOUR_PASSWORD"
      wombag-client-id "YOUR_WALLABAG_CLIENT_ID"
      wombag-client-secret "YOUR_WALLABAG_CLIENT_SECRET")

;; Miniflux / Elfeed (elfeed-protocol)
(setq elfeed-protocol-feeds '(("fever+https://YOUR_USERNAME@your-miniflux-instance.example.com"
                               :api-url "https://your-miniflux-instance.example.com/fever/"
                               :password "YOUR_PASSWORD")))

;; SQL connections (lsp-sqls)
(setq lsp-sqls-connections
      '(((driver . "sqlite3") (dataSourceName . "test.db"))
        ((driver . "postgresql") (dataSourceName . "host=127.0.0.1 port=5432 user=YOUR_USER password=YOUR_PASSWORD dbname=YOUR_DB sslmode=disable"))))

;; OpenAI
(setq openai-api-key "YOUR_OPENAI_API_KEY")

;; PubMed
(setq pubmed-api-key "YOUR_PUBMED_API_KEY")

;; GitHub notifications
(setq github-notifier-token "YOUR_GITHUB_TOKEN")
