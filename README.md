# Zetta

_A reproducible, batteries-included Emacs distribution. Pick what you want via a small DSL; pin everything via lockfile; switch modal systems on the fly._

[![CI](https://github.com/chiply/.zetta.d/actions/workflows/ci.yml/badge.svg)](https://github.com/chiply/.zetta.d/actions/workflows/ci.yml)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
[![Emacs](https://img.shields.io/badge/Emacs-29.4%20%7C%2030.2%20%7C%2031--snapshot-purple.svg)](https://www.gnu.org/software/emacs/)

> **Status:** This is my personal Emacs config, published in the open. Use at your own risk; expect breaking changes whenever I want them.

## Highlights

- **Triple-modal editing** — Switch between Evil, Meow, and vanilla Emacs with `s-z e` / `s-z m` / `s-z E`. No restart.
- **brushup** — Parametric, theme-aware color gradient system. Faces auto-update when you change themes. ([chiply/brushup](https://github.com/chiply/brushup))
- **repeatable-lite** — Repeatable prefix commands integrated with which-key. ([chiply/repeatable-lite](https://github.com/chiply/repeatable-lite))
- **Module DSL** — Enable/disable categories or individual packages via the `zetta-modules!` macro in `~/.zetta.el`.
- **Reproducible** — Elpaca lockfile pins every package to an exact commit.
- **Compiled by default** — `bin/zetta install` byte-compiles modules and native-compiles packages ahead of first launch.

## How does this compare to…

- **Doom Emacs** — Doom is Evil-only with a framework around use-package. Zetta supports Evil, Meow, and vanilla side-by-side, and the module loader is plain Elisp around use-package — no DSL to learn beyond `zetta-modules!`.
- **Vanilla / `init.el`** — Zetta gives you ~320 packages already wired up; turn off any module category you don't want.
- **Crafted Emacs / Prelude** — Similar modular philosophy. Zetta is more opinionated, ships a custom theme engine (`brushup`), and uses Elpaca with a real lockfile.

## Requirements

- **Emacs 29+** (30+ recommended). CI tests 29.4, 30.2, and the 31 snapshot.
- **Git**, **ripgrep** (for consult-ripgrep)
- Optional: Node.js (LSP servers), Python 3 (python-ts-mode, pytest), `fd` (fast file search)

## Installation

```bash
git clone https://github.com/chiply/.zetta.d ~/.zetta.d && cd ~/.zetta.d && bin/zetta install
```

> **Important:** Run `bin/zetta install` before launching Emacs for the first time. It byte-compiles and native-compiles everything up front so the UI renders correctly on first launch. Without it, Emacs will install ~320 packages on startup, leading to a broken modeline, missing tab bar, and other glitches while it catches up.

The install command will:
1. Create `~/.zetta.el` (your config) and `~/.private.el` (API keys)
2. Install and byte-compile all packages via Elpaca
3. Native-compile everything (a few minutes)

### With chemacs2

If you use [chemacs2](https://github.com/plexus/chemacs2), add to `~/.emacs-profiles.el`:

```elisp
("zetta" . ((user-emacs-directory . "~/.zetta.d")))
```

Then launch with `emacs --with-profile zetta`.

## Quick Start

Edit `~/.zetta.el` to customize:

```elisp
(setq zetta-theme 'modus-operandi)         ; default
(setq zetta-font  "Terminus (TTF)")        ; default

(zetta-modules!
 :core
 :completion
 :ui (-nyan-mode -parrot)                   ; load all of :ui except these
 :editor
 :lang (python yaml typescript-ts-mode)     ; load only these
 :tools (magit lsp docker flycheck)
 :org
 :term)
```

API keys and credentials go in `~/.private.el` (see [`.private.sample.el`](.private.sample.el)). For 1Password-backed secrets, see [`secrets.md`](secrets.md).

## Documentation

- [`docs/modules.md`](docs/modules.md) — every module file and what it configures
- [`docs/keybindings.md`](docs/keybindings.md) — full keybinding reference
- [`COMPILATION.md`](COMPILATION.md) — byte-compile, native-compile, compile-angel architecture
- [`secrets.md`](secrets.md) — 1Password CLI secrets management
- [`slack.md`](slack.md) — emacs-slack token + cookie setup
- [`CHANGELOG.md`](CHANGELOG.md) — release notes

## CLI

```
bin/zetta <command>

  install            Install packages and native-compile
  sync               Re-evaluate config, install new packages
  freeze [--commit]  Write lockfile (optionally commit it)
  update             Pull all packages (backs up lockfile first)
  doctor             Diagnose environment and configuration
  test               Start test daemon and verify startup
```

## Modules

| Category      | Description                                                          |
|---------------|----------------------------------------------------------------------|
| `:core`       | Emacs defaults, buffers, projects, persistence, keybindings          |
| `:completion` | Vertico, consult, orderless, corfu, embark, marginalia               |
| `:ui`         | Themes, modeline, icons, treemacs, window management, visual aids    |
| `:editor`     | Evil + extensions, smartparens, snippets, undo-tree, avy, ace-window |
| `:lang`       | Python, TypeScript, YAML, Terraform, SQL, web-mode, tree-sitter      |
| `:tools`      | Magit, LSP, Docker, flycheck, dired, compile, git utilities          |
| `:app`        | Elfeed, bookmarks, Spotify, Mastodon, ERC, EWW, word lookup          |
| `:org`        | Org-mode, org-ref, citar, pdf-tools, org-capture, org-remark         |
| `:term`       | Vterm, shell, foreman                                                |

See [`docs/modules.md`](docs/modules.md) for per-file descriptions.

## Keybindings

The leader key is `,` (comma) in non-insert states, `C-,` in insert state.

| Key   | Menu            | Purpose                                  |
|-------|-----------------|------------------------------------------|
| `, g` | Version control | Magit, git-link, git-timemachine, blamer |
| `, p` | Project         | Project-scoped operations                |
| `, w` | Window          | Window management, ace-window            |
| `, l` | Lookup          | Search, devdocs, consult                 |
| `, o` | Org             | Org-mode commands, capture, agenda       |
| `, r` | Run             | Compile, run, shell commands             |
| `, t` | Theme           | Theme switching                          |
| `, h` | Help            | Help, documentation                      |
| `, d` | Smerge          | Merge conflict resolution                |
| `, i` | iedit           | Multi-occurrence editing                 |

See [`docs/keybindings.md`](docs/keybindings.md) for the full reference.

## Updating

```bash
bin/zetta update    # pull latest packages, back up lockfile
bin/zetta freeze    # rewrite lockfile from current state
```

To run on bleeding-edge instead of pinned: `(setq zetta-use-lockfile nil)` in `~/.zetta.el`.

## Uninstalling

```bash
rm -rf ~/.zetta.d ~/.zetta.el ~/.private.el
```

If you used chemacs2, also remove the `("zetta" ...)` entry from `~/.emacs-profiles.el`.

## Structure

```
.zetta.d/
├── bin/zetta              # CLI wrapper
├── init.el                # Entry point
├── early-init.el          # Startup optimization
├── elpaca-lockfile.el     # Package version lockfile
├── templates/             # User config templates
├── source/
│   ├── bootstrap/         # Core initialization
│   ├── init-data/         # Default module file list
│   └── zettapkg/          # Bundled custom packages
├── modules/               # Package configurations (9 categories)
└── docs/                  # Documentation
```

## Bundled custom packages

Several packages are written specifically for Zetta and live as separate public repos:

- [`brushup`](https://github.com/chiply/brushup) — theme-aware parametric face gradients
- [`repeatable-lite`](https://github.com/chiply/repeatable-lite) — which-key-integrated repeatable prefix commands
- [`spot`](https://github.com/chiply/spot) / [`spot4e`](https://github.com/chiply/spot4e) — Spotify control from Emacs
- [`magneto`](https://github.com/chiply/magneto) — buffer/window magnetism
- [`touchtype`](https://github.com/chiply/touchtype) — typing-speed practice
- [`space-tree`](https://github.com/chiply/space-tree) — workspace tree navigation

## Acknowledgements

- [Elpaca](https://github.com/progfolio/elpaca) — the package manager Zetta is built on
- [Doom Emacs](https://github.com/doomemacs/doomemacs) — inspiration for the modular layout and use-package conventions
- [general.el](https://github.com/noctuid/general.el) — keybinding system
- [Meow](https://github.com/meow-edit/meow) and [Evil](https://github.com/emacs-evil/evil) — both modal editing systems Zetta wires up

## Contributing / Issues

Issues and PRs are welcome at [chiply/.zetta.d/issues](https://github.com/chiply/.zetta.d/issues). Bear in mind the status above — this is primarily a personal config, and I make decisions accordingly.

## License

GPL-3.0 — see [LICENSE](LICENSE).
