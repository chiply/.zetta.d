# Secrets Management

Zetta uses 1Password CLI (`op`) to manage secrets. All secrets are stored in a
**Dev** vault and loaded into Emacs at startup via a single `op inject` call.

## Architecture

```
op-secrets.env.tpl   --[op inject]-->   zetta-op--cache (hash table)
                                            |
                              +-------------+-------------+
                              |                           |
                       zetta-op-read              auth-source backend
                    (used in .private.el)      (used by forge, erc, slack, etc.)
```

- **`source/op-secrets.env.tpl`** — Template file with `{{ op://Dev/Item/field }}` references
- **`init.el`** — Runs `op inject` once at startup, populates an in-memory cache
- **`~/.private.el`** — Calls `zetta-op-read` to set Elisp variables from cache
- **`zetta-op-auth-source-parser`** — Custom `auth-source` backend that serves
  credentials from the same cache, replacing `~/.authinfo`

## Prerequisites

1. **1Password CLI** — `brew install --cask 1password-cli`
2. **Service account token** — Set in `~/.zshenv.local` (not tracked in git):
   ```sh
   export OP_SERVICE_ACCOUNT_TOKEN="ops_..."
   ```
3. **`~/.zshenv`** (tracked in `.files`) sources `~/.zshenv.local`

The service account authenticates silently — no Touch ID prompts, no 1Password
app required.

## Adding a new secret (used directly in Elisp)

1. Create the item in 1Password:
   ```sh
   op item create --vault Dev --title MyService --category "API Credential" \
     "api-key=the-secret-value"
   ```

2. Add a line to `source/op-secrets.env.tpl`:
   ```
   MY_SERVICE_API_KEY={{ op://Dev/MyService/api-key }}
   ```

3. Reference it in `~/.private.el`:
   ```elisp
   (setq my-service-api-key (zetta-op-read "MY_SERVICE_API_KEY"))
   ```

## Adding a new auth-source entry (for packages that use `auth-source-search`)

Packages like forge, erc, slack, and gptel look up credentials via Emacs's
`auth-source` framework. Zetta provides a 1Password-backed auth-source backend
so no `~/.authinfo` file is needed.

1. Create the item in 1Password (same as above).

2. Add a line to `source/op-secrets.env.tpl`:
   ```
   MY_SERVICE_PASSWORD={{ op://Dev/MyService/password }}
   ```

3. Add an entry to `zetta-op-auth-source-entries` in `init.el`:
   ```elisp
   (:host "my-service.example.com" :user "myuser" :key "MY_SERVICE_PASSWORD")
   ```
   The `:host`, `:user`, and `:port` fields must match what the consuming
   package passes to `auth-source-search`.

## Current secrets inventory

### Direct Elisp variables (via `zetta-op-read`)

| Cache Key | 1Password Item | Used By |
|---|---|---|
| `SPOTIFY_CLIENT_ID` | Dev/Spotify | spot4e, spot |
| `SPOTIFY_CLIENT_SECRET` | Dev/Spotify | spot4e, spot |
| `SPOTIFY_REFRESH_TOKEN` | Dev/Spotify | spot4e |
| `WALLABAG_PASSWORD` | Dev/Wallabag | wombag |
| `WALLABAG_CLIENT_ID` | Dev/Wallabag | wombag |
| `WALLABAG_CLIENT_SECRET` | Dev/Wallabag | wombag |
| `MINIFLUX_PASSWORD` | Dev/Miniflux | elfeed-protocol |
| `POSTGRESQL_LOCAL_PASSWORD` | Dev/PostgreSQL-Local | lsp-sqls |
| `REDDIT_CLIENT_ID` | Dev/Reddit | md4rd |
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
| `mastodon.social` | `charliebholland` | `MASTODON_PASSWORD` | mastodon.el |
| `debian_droplet` | `root` | `DEBIAN_DROPLET_PASSWORD` | ssh/tramp |
| `api.openai.com` | `apikey` | `OPENAI_API_KEY` | gptel |
| `api.anthropic.com` | `apikey` | `ANTHROPIC_API_KEY` | gptel |
| `api.anthropic.com` | `personal` | `ANTHROPIC_API_KEY` | gptel |
| `api.github.com` | `chiply^forge` | `GITHUB_FORGE_TOKEN` | forge |
| `irc.libera.chat` | `charlieholland` | `LIBERA_CHAT_PASSWORD` | erc |
| `app.slack.com` | `you@example.com` | `SLACK_TOKEN` | emacs-slack |
| `app.slack.com` | `you@example.com^cookie` | `SLACK_COOKIE` | emacs-slack |

### External tools (via `op read` directly)

These are called by external programs (not Emacs) using `PassCmd` or similar:

| 1Password Item | Used By | Config File |
|---|---|---|
| `Dev/Gmail-misterchiply/app-password` | mbsync (IMAP) | `~/.mbsyncrc` |
| `Dev/Gmail-charliebkr707/app-password` | mbsync (IMAP) | `~/.mbsyncrc` |
| `Dev/Gmail-charliechristopherbaker/app-password` | mbsync (IMAP) | `~/.mbsyncrc` |

These use `op read 'op://Dev/Item/field'` directly in the config (not the
Emacs cache), since mbsync runs outside Emacs. The service account token in the
environment ensures no prompts.

## Setting up on a new machine

1. Install the CLI: `brew install --cask 1password-cli`
2. Create `~/.zshenv.local` with your service account token:
   ```sh
   export OP_SERVICE_ACCOUNT_TOKEN="ops_..."
   ```
3. Verify: `op inject -i source/op-secrets.env.tpl` should output all resolved values
