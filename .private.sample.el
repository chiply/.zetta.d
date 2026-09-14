;;; .private.sample.el --- Template for ~/.private.el  -*- lexical-binding: t; -*-
;;
;; Copy this file to ~/.private.el and fill in your credentials.
;; ~/.private.el is loaded early in init.el and is NOT tracked by git.
;;
;; Where the values come from is decided per machine by
;; `zetta-secrets-backend' in ~/.zetta.el (secrets.md has the table):
;;
;;   (a) authinfo — no cache.  Put values in ~/.authinfo.gpg and let the
;;       packages read auth-source, or paste literals below (the YOUR_X
;;       placeholders) if you must.
;;
;;   (b) op — 1Password CLI.  Populate the template (source/op-secrets.env.tpl,
;;       or `zetta-op-template-file' pointed at an untracked one) with
;;       item references, call (zetta-secrets-load) once and
;;       (zetta-secrets-read "KEY") per value.  `zetta-op-load' and
;;       `zetta-op-read' are aliases of the same functions.
;;
;;   (c) command — any vault that prints KEY=VALUE lines, e.g. in ~/.zetta.el:
;;         (setq zetta-secrets-backend 'command
;;               zetta-secrets-command "pass show emacs/env")
;;       then the same (zetta-secrets-load) / (zetta-secrets-read "KEY").
;;
;; For (b) and (c) the `zetta-op-auth-source-entries' block at the end is
;; the auth-source bridge: it maps the (host, user) a package asks for to
;; a cache key.
;;
;; (zetta-secrets-load)   ; uncomment for (b) and (c)

;; IRC (erc)
(setq erc-nick "YOUR_IRC_NICK")
(setq erc-user-full-name "Your Name")

;; Mastodon
(setq mastodon-instance-url "https://mastodon.social"
      mastodon-active-user "YOUR_MASTODON_HANDLE")

;; Signal (signel) — your registered Signal phone number, E.164 format
(setq signel-account "+15551234567")

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
;; Work tools.  The modules ship with these nil and stay inert until the
;; private file supplies values -- an employer's host, project key or
;; workspace never lives in a tracked module (work-security-audit.org S3).
;; ──────────────────────────────────────────────────────────────────

;; Jira (modules/tools/jira.el): the instance and the saved queries.
;; (setq zetta-jira-url  "https://example.atlassian.net"
;;       zetta-jira-jqls '((:jql "assignee = currentUser() and sprint in openSprints() ORDER BY priority DESC, created ASC"
;;                          :limit 200 :filename "My sprint")))

;; Slack (modules/tools/slack.el): one plist per workspace; the token and
;; cookie live in auth-source under :host / :user (slack.md).
;; (setq zetta-slack-teams '((:name "example" :host "example.slack.com"
;;                            :user "alice@example.com" :default t)))

;; Hosts for `zetta-ssh' / `zetta-ssh-shell' (modules/core/remote.el).  The
;; default is the Host aliases of ~/.ssh/config; set this to override.
;; (setq zetta-ssh-hosts '("dev-box" "bastion"))

;; ──────────────────────────────────────────────────────────────────
;; Mail sending (mu4e / message-mode via msmtp)
;;
;; mu4e accounts/contexts are personal, so they are not shown here —
;; define your own `mu4e-contexts' (per-account `user-mail-address',
;; maildirs, etc.).  This block only covers the OUTGOING path, which
;; hands off to the external `msmtp' binary:
;;
;;   1. brew install msmtp
;;   2. create ~/.msmtprc (NOT tracked; lives in $HOME) — see example below
;;   3. store passwords with msmtp's `passwordeval' + the `op' CLI (mode (b)),
;;      the same source mbsync uses — no secrets in any tracked file.
;; ──────────────────────────────────────────────────────────────────

;; A static signature is just a string.  NB: if you use a FORM here (e.g.
;; `(format ...)'), message-mode evaluates it — the format string's
;; %-directives must match the argument count, or `message-insert-signature'
;; dies with "Not enough arguments for format string" on every compose.
(setq message-signature "Cheers,\nYour Name")

;; Send via msmtp.  The `(or ... "abs/path")' fallback guards against a nil
;; `sendmail-program' (→ "Wrong type argument: stringp, nil" when sending) if
;; msmtp is not yet on `exec-path' as the daemon starts.
(setq send-mail-function         'message-send-mail-with-sendmail
      message-send-mail-function 'message-send-mail-with-sendmail
      sendmail-program           (or (executable-find "msmtp")
                                      "/opt/homebrew/bin/msmtp"))

;; Pick the msmtp account from the From: header before each send.
;; The account names must match the `account' blocks in ~/.msmtprc.
(defun zetta/set-msmtp-account ()
  (when (message-mail-p)
    (save-excursion
      (let* ((from (save-restriction
                     (message-narrow-to-headers)
                     (message-fetch-field "from")))
             (account (cond
                       ((string-match "you@example.com"   from) "example-account")
                       ((string-match "other@example.org" from) "other-account"))))
        (when account
          (setq message-sendmail-extra-arguments (list "-a" account)))))))
(add-hook 'message-send-mail-hook #'zetta/set-msmtp-account)

;; Example ~/.msmtprc (one `account' block per address; passwords via `op'):
;;
;;   defaults
;;   auth           on
;;   tls            on
;;   tls_starttls   on
;;   tls_trust_file /opt/homebrew/etc/ca-certificates/cert.pem
;;
;;   account example-account
;;   host    smtp.gmail.com
;;   port    587
;;   from    you@example.com
;;   user    you@example.com
;;   passwordeval "op read 'op://Dev/Example/app-password'"
;;
;;   account default : example-account

;; ──────────────────────────────────────────────────────────────────
;; Cache-backed auth-source entries (backends (b) and (c) above).
;; Maps (host, user, port) tuples to cache keys.
;; Used by forge, gptel, erc, mastodon, etc. via auth-source-search.
;; ──────────────────────────────────────────────────────────────────
;; (setq zetta-op-auth-source-entries
;;       '((:host "api.openai.com"    :user "apikey"           :key "OPENAI_API_KEY")
;;         (:host "api.anthropic.com" :user "apikey"           :key "ANTHROPIC_API_KEY")
;;         (:host "api.github.com"    :user "your-user^forge"  :key "GITHUB_FORGE_TOKEN")))
