;;; .private.sample.el --- Template for ~/.private.el  -*- lexical-binding: t; -*-
;;
;; Copy this file to ~/.private.el and fill in your credentials.
;; ~/.private.el is loaded early in init.el and is NOT tracked by git.
;;
;; Two ways to supply secrets:
;;
;;   (a) Manual — paste literal values below (the YOUR_X placeholders).
;;
;;   (b) 1Password CLI — populate `op-secrets.env.tpl` with item refs,
;;       then call `(zetta-op-read "KEY")` here.  See `secrets.md` for
;;       the full setup.  The `zetta-op-auth-source-entries` block
;;       below is the auth-source bridge for that mode.

;; IRC (erc)
(setq erc-nick "YOUR_IRC_NICK")
(setq erc-user-full-name "Your Name")

;; Mastodon
(setq mastodon-instance-url "https://mastodon.social"
      mastodon-active-user "YOUR_MASTODON_HANDLE")

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

;; ──────────────────────────────────────────────────────────────────
;; 1Password auth-source entries (only needed if using mode (b) above)
;; Maps (host, user, port) tuples to 1Password cache keys.
;; Used by forge, gptel, erc, mastodon, etc. via auth-source-search.
;; ──────────────────────────────────────────────────────────────────
;; (setq zetta-op-auth-source-entries
;;       '((:host "api.openai.com"    :user "apikey"           :key "OPENAI_API_KEY")
;;         (:host "api.anthropic.com" :user "apikey"           :key "ANTHROPIC_API_KEY")
;;         (:host "api.github.com"    :user "your-user^forge"  :key "GITHUB_FORGE_TOKEN")))
