# Secrets Management

Zetta never keeps a credential in a tracked file. Every secret comes from a
**backend** chosen per machine in `~/.zetta.el`, and reaches Elisp two ways:
`zetta-secrets-read` for variables set in `~/.private.el`, and an
`auth-source` bridge for packages (forge, gptel, slack, erc, mastodon,
bluesky) that call `auth-source-search`.

## Architecture

```
~/.zetta.el          (setq zetta-secrets-backend 'op | 'command | 'authinfo | 'none)
        |
bootstrap-secrets.el  zetta-secrets-load  --[op inject | zetta-secrets-command]-->  zetta-op--cache
(loaded by init.el                                                                      |
 after ~/.zetta.el)                                                    +----------------+----------------+
                                                                       |                                 |
                                                            zetta-secrets-read               auth-source backend `zetta-op'
                                                          (used in ~/.private.el)          (forge, gptel, slack, erc, ...)
```

- **`source/bootstrap/bootstrap-modules.el`** — the decision variables:
  `zetta-secrets-backend`, `zetta-op-template-file`, `zetta-secrets-command`,
  and `zetta-secrets-effective-backend`, which applies the nil rule.
- **`source/bootstrap/bootstrap-secrets.el`** — the cache, `zetta-secrets-load`,
  `zetta-secrets-read`, the `zetta-op` auth-source backend, and the setting of
  `auth-sources` per backend. Loaded by `init.el` *after* `~/.zetta.el`, so
  the profile's choice is honoured, and *before* `~/.private.el`, which
  consumes it.
- **`~/.private.el`** — calls `(zetta-secrets-load)` once, then
  `(zetta-secrets-read "KEY")` per value, and sets
  `zetta-op-auth-source-entries` for the bridge. The older names
  `zetta-op-load` / `zetta-op-read` are aliases, so a private file written
  before the backend switch works unchanged.
- **`source/op-secrets.env.tpl`** — the template the `op` backend resolves:
  `KEY={{ op://Vault/Item/field }}` lines. References and item ids, not
  secrets.

## The backends

| `zetta-secrets-backend` | What happens at startup                                                                      | `auth-sources`                                        |
|-------------------------|----------------------------------------------------------------------------------------------|-------------------------------------------------------|
| `nil` (default)         | `op` when the `op` binary **and** `zetta-op-template-file` both exist, otherwise `authinfo`   | as the chosen one                                     |
| `'op`                   | one `op inject -i <template>` fills the cache (one Touch ID prompt, or none with a service-account token) | `(zetta-op)` — the cache only               |
| `'command`              | `zetta-secrets-command` runs once and must print `KEY=VALUE` lines                           | `(zetta-op)`                                          |
| `'authinfo`             | nothing runs; no cache, no subprocess                                                        | left at Emacs's default (`~/.authinfo.gpg`, `~/.authinfo`, `~/.netrc`) or whatever `~/.zetta.el` set |
| `'none`                 | nothing runs                                                                                 | `nil` — no backend is ever consulted (CI, the headless hub) |

The default rule is the behaviour from before the variable existed, so a
personal machine with the 1Password CLI needs no edit. Standard error of the
backend command is discarded, never parsed: a vault's error text must not
become a value.

## Adopting another vault

Any vault that can print `KEY=VALUE` lines plugs in by editing `~/.zetta.el`
and `~/.private.el` only — `init.el` is never touched.

| Vault                | `~/.zetta.el`                                                                                                                  | Where the references live                                              |
|----------------------|--------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------|
| none issued          | `(setq zetta-secrets-backend 'authinfo)` (the work template's default)                                                          | `~/.authinfo.gpg`                                                      |
| 1Password (another account) | `(setq zetta-secrets-backend 'op zetta-op-template-file "~/.config/zetta/secrets.env.tpl")`                              | that untracked template, `op://<Vault>/...`; `op signin` with that account (desktop-app unlock, no service token) |
| Bitwarden            | `'command`, `zetta-secrets-command` = `bw get item emacs-secrets --raw \| jq -r '.fields[] \| "\(.name)=\(.value)"'`            | a Bitwarden item with custom fields                                    |
| HashiCorp Vault      | `'command`, `vault kv get -format=json secret/emacs \| jq -r '.data.data \| to_entries[] \| "\(.key)=\(.value)"'`              | a KV secret                                                            |
| AWS Secrets Manager  | `'command`, `aws secretsmanager get-secret-value --secret-id emacs --query SecretString --output text \| jq -r 'to_entries[] \| "\(.key)=\(.value)"'` | a JSON secret                                         |
| `pass`               | `'command`, `pass show emacs/env`                                                                                              | one entry holding `KEY=VALUE` lines                                    |

The auth-source bridge (`zetta-op-auth-source-entries` in `~/.private.el`)
is what lets forge, gptel and slack find a token in any of these: the
inventory tables below are the same for every vault; only the column that
says where the value lives changes.

## Never on a managed machine

The personal 1Password **service-account token** (`OP_SERVICE_ACCOUNT_TOKEN`
in `~/.zshenv.local`) unlocks every personal credential without a prompt.
It is for personal machines only. An employer-managed computer — MDM, EDR,
backup agents — must never hold it: install nothing personal there, set
`zetta-secrets-backend` to `'authinfo` (the work template does), and put
work credentials in `~/.authinfo.gpg` or the employer's own vault through
the table above. `bin/zetta doctor` reports the effective backend and
whether it resolves, and warns when a credential file is wider than mode
600 or a plaintext `~/.authinfo` exists. work-security-audit.org and
work-profile.org carry the reasoning.

## Prerequisites for the `op` backend

1. **1Password CLI** — `brew install --cask 1password-cli`
2. **Authentication** — either the desktop app's CLI integration (Touch ID
   at the one `op inject`), or, on a personal machine only, a service
   account token exported from `~/.zshenv.local` (not tracked; mode 600):
   ```sh
   export OP_SERVICE_ACCOUNT_TOKEN="ops_..."
   ```
3. **`~/.zshenv`** (tracked in `.files`) sources `~/.zshenv.local`

## Adding a new secret (used directly in Elisp)

1. Create the item in the vault, e.g. for 1Password:
   ```sh
   op item create --vault Dev --title MyService --category "API Credential" \
     "api-key=the-secret-value"
   ```

2. Add a line to the template (`op` backend), or make the command print it:
   ```
   MY_SERVICE_API_KEY={{ op://Dev/MyService/api-key }}
   ```

3. Reference it in `~/.private.el`:
   ```elisp
   (setq my-service-api-key (zetta-secrets-read "MY_SERVICE_API_KEY"))
   ```

Under the `authinfo` backend there is no cache: put the value in
`~/.authinfo.gpg` and read it with `auth-source-pick-first-password`, or
let the consuming package do so.

## Adding a new auth-source entry (for packages that use `auth-source-search`)

1. Create the item and its `KEY=VALUE` line as above.

2. Add an entry to `zetta-op-auth-source-entries` in `~/.private.el`:
   ```elisp
   (:host "my-service.example.com" :user "myuser" :key "MY_SERVICE_PASSWORD")
   ```
   The `:host`, `:user`, and `:port` fields must match what the consuming
   package passes to `auth-source-search`.

## Current inventory (the personal machine)

### Direct Elisp variables (via `zetta-secrets-read`)

| Cache Key | 1Password Item | Used By |
|---|---|---|
| `SPOTIFY_CLIENT_ID` | Dev/Spotify | spot4e, spot |
| `SPOTIFY_CLIENT_SECRET` | Dev/Spotify | spot4e, spot |
| `SPOTIFY_REFRESH_TOKEN` | Dev/Spotify | spot4e |
| `WALLABAG_PASSWORD` | Dev/Wallabag | wombag |
| `WALLABAG_CLIENT_ID` | Dev/Wallabag | wombag |
| `WALLABAG_CLIENT_SECRET` | Dev/Wallabag | wombag |
| `MINIFLUX_PASSWORD` | Dev/Miniflux | elfeed-protocol |
| `MINIFLUX_API_KEY` | Dev/Miniflux | elfeed.org -> Miniflux sync |
| `POSTGRESQL_LOCAL_PASSWORD` | Dev/PostgreSQL-Local | lsp-sqls |
| `REDDIT_CLIENT_ID` | Dev/Reddit | md4rd |
| `REDDIT_CLIENT_SECRET` | Dev/Reddit | md4rd |
| `REDDIT_REFRESH_TOKEN` | Dev/Reddit | md4rd |
| `REDDIT_ACCESS_TOKEN` | Dev/Reddit | md4rd |
| `PUBMED_API_KEY` | Dev/PubMed | consult-omni |
| `OPENAI_API_KEY` | Dev/OpenAI | openai, consult-omni |
| `GOOGLE_CUSTOMSEARCH_API_KEY` | Dev/Google-CustomSearch | consult-omni |
| `GOOGLE_CUSTOMSEARCH_CX` | Dev/Google-CustomSearch | consult-omni |
| `BRAVE_API_KEY` | Dev/Brave-Search | consult-omni |
| `BRAVE_AUTOSUGGEST_API_KEY` | Dev/Brave-Search | consult-omni |
| `STACKEXCHANGE_API_KEY` | Dev/StackExchange | consult-omni |
| `GOOGLE_YOUTUBE_API_KEY` | Dev/Google-YouTube | consult-omni |
| `GITHUB_NOTIFIER_TOKEN` | Dev/GitHub-Notifier | github-notifier |

### Auth-source entries (via `auth-source-search`)

| Host | User | Cache Key | Used By |
|---|---|---|---|
| `mastodon.social` | `your-mastodon-handle` | `MASTODON_PASSWORD` | mastodon.el |
| `debian_droplet` | `root` | `DEBIAN_DROPLET_PASSWORD` | ssh/tramp |
| `api.openai.com` | `apikey` | `OPENAI_API_KEY` | gptel |
| `api.anthropic.com` | `apikey` | `ANTHROPIC_API_KEY` | gptel |
| `api.github.com` | `your-github-user^forge` | `GITHUB_FORGE_TOKEN` | forge |
| `irc.libera.chat` | `your-irc-nick` | `LIBERA_CHAT_PASSWORD` | erc |
| `<workspace>.slack.com` | `you@example.com` | `SLACK_TOKEN` | emacs-slack |
| `<workspace>.slack.com` | `you@example.com^cookie` | `SLACK_COOKIE` | emacs-slack |

### External tools (via `op read` directly)

These are called by external programs (not Emacs) using `PassCmd` or similar:

| 1Password Item | Used By | Config File |
|---|---|---|
| `Dev/<mail account>/app-password` | mbsync (IMAP), msmtp (SMTP) | `~/.mbsyncrc`, `~/.msmtprc` |

They use `op read 'op://Dev/Item/field'` in the config, not the Emacs
cache, since mbsync and msmtp run outside Emacs.

## Setting up a new machine

- **Personal machine**: install the CLI, authenticate (above), leave
  `zetta-secrets-backend` nil. Verify with
  `op inject -i source/op-secrets.env.tpl | grep -c '='` (a count, so no
  value is printed) and `bin/zetta doctor`.
- **Work or shared machine**: copy `templates/zetta.work.el` to `~/.zetta.el`
  (its backend is `authinfo`), write work credentials to `~/.authinfo.gpg`
  (mode 600), and adopt the employer's vault, if any, from the table above.
  `bin/zetta doctor` must show the backend you chose and no mode warning.
- **Headless / CI**: `templates/zetta.headless.el` sets `'none`;
  `~/.private.el` can be a single `;;`.
