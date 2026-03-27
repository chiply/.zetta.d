# Slack Setup (emacs-slack)

Each Slack **workspace** you want to use in emacs-slack needs its own token and cookie stored in your auth-source (`~/.authinfo.gpg`).

## Getting credentials for a workspace

1. Open the workspace in your **browser** (not the desktop app) at `https://<workspace>.slack.com`
2. Open Developer Tools (F12 or Cmd+Option+I)
3. Go to the **Network** tab
4. Perform any action in Slack (e.g. switch channels) to trigger an API call
5. Find a request to `https://<workspace>.slack.com/api/...`
6. From the **request headers**, grab:
   - **Token**: the `token` form field in the request body — starts with `xoxc-`
   - **Cookie**: the `d` cookie value from the `Cookie` header — starts with `d=`

## Adding credentials to auth-source

Add two entries per workspace to `~/.authinfo.gpg`:

```
machine <workspace>.slack.com login <your-email> password xoxc-<token>
machine <workspace>.slack.com login <your-email>^cookie password d=<cookie-value>
```

For example, for a workspace called "dagster":

```
machine dagster.slack.com login alice@example.com password xoxc-1234567890-...
machine dagster.slack.com login alice@example.com^cookie password d=xoxd-abc123...
```

## Registering the workspace in slack.el

Add a `slack-register-team` block in `modules/tools/slack.el`:

```elisp
(slack-register-team
 :name "dagster"
 :token (auth-source-pick-first-password
         :host "dagster.slack.com"
         :user "alice@example.com")
 :cookie (auth-source-pick-first-password
          :host "dagster.slack.com"
          :user "alice@example.com^cookie")
 :full-and-display-names t)
```

Set `:default t` on whichever workspace you want as primary.

## Notes

- Tokens and cookies are **workspace-specific** — you need a separate pair for each workspace
- Tokens expire periodically; if you get `invalid_auth`, re-extract from the browser
- The `:name` in `slack-register-team` is a label for your reference — it can be anything
- The `:host` in auth-source must match the workspace's Slack domain
