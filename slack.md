# Slack Setup (emacs-slack)

Each Slack **workspace** you want to use in emacs-slack needs its own token and cookie stored in your auth-source (`~/.authinfo.gpg`, or the 1Password bridge described in `secrets.md`).

## Getting credentials for a workspace

1. Open the workspace in your **browser** (not the desktop app) at `https://<workspace>.slack.com`
2. Open Developer Tools (F12 or Cmd+Option+I)
3. Go to the **Network** tab
4. Perform any action in Slack (e.g. switch channels) to trigger an API call
5. Find a request to `https://<workspace>.slack.com/api/...`
6. From the **request headers**, grab:
   - **Token**: the `token` form field in the request body — starts with `xoxc-`
   - **Cookie**: the `d` cookie value from the `Cookie` header — starts with `d=`

Many workspace policies forbid browser-token clients.  Check with the workspace's administrators before setting this up on a machine they manage.

## Adding credentials to auth-source

Add two entries per workspace to `~/.authinfo.gpg`:

```
machine <workspace>.slack.com login <your-email> password xoxc-<token>
machine <workspace>.slack.com login <your-email>^cookie password d=<cookie-value>
```

For example, for a workspace at `example.slack.com`:

```
machine example.slack.com login alice@example.com password xoxc-1234567890-...
machine example.slack.com login alice@example.com^cookie password d=xoxd-abc123...
```

## Registering the workspace in ~/.private.el

`modules/tools/slack.el` registers every team listed in `zetta-slack-teams`; the module itself names no workspace.  Add the variable to `~/.private.el`:

```elisp
(setq zetta-slack-teams
      '((:name "example" :host "example.slack.com"
         :user "alice@example.com" :default t)
        ;; a second workspace, if any
        (:name "other" :host "other.slack.com"
         :user "alice@example.com")))
```

`:host` and `:user` must match the auth-source entries above (the module appends `^cookie` to `:user` for the cookie lookup).  Set `:default t` on whichever workspace you want as primary.  With `zetta-slack-teams` nil the package is neither installed nor loaded.

## Notes

- Tokens and cookies are **workspace-specific** — you need a separate pair for each workspace
- Tokens expire periodically; if you get `invalid_auth`, re-extract from the browser
- The `:name` is a label for your reference — it can be anything
- The `:host` must match the workspace's Slack domain
