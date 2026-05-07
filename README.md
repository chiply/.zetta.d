# Zetta Emacs

A batteries-included Emacs distribution built on [Elpaca](https://github.com/progfolio/elpaca), with 320+ packages organized into 9 module categories.

## Highlights

- **Triple-modal editing** — Switch between Evil, Meow, and vanilla Emacs with `s-z e` / `s-z m` / `s-z E`
- **brushup** — Parametric, theme-aware color gradient system. Faces auto-update when you change themes.
- **repeatable-lite** — Repeatable prefix commands integrated with which-key
- **Module system** — Enable/disable entire categories or individual packages via `~/.zetta.el`
- **Reproducible** — Elpaca lockfile pins every package to an exact commit

## Requirements

- **Emacs 29+** (30+ recommended)
- **Git**
- **ripgrep** (for consult-ripgrep)
- Optional: Node.js (LSP servers), Python 3 (python-ts-mode, pytest), fd (fast file search)

## Installation

```bash
git clone https://github.com/chiply/.zetta.d ~/.zetta.d
cd ~/.zetta.d
bin/zetta install
```

**Important:** Run `bin/zetta install` before launching Emacs for the first time. This builds everything ahead of time so the UI renders correctly on first launch. Without it, Emacs will try to install, byte-compile, and native-compile ~320 packages on startup, resulting in a broken modeline, missing tab bar, and other visual glitches while it catches up.

The install command will:
1. Create `~/.zetta.el` (your config) and `~/.private.el` (API keys)
2. Install and byte-compile all packages via Elpaca
3. Native-compile everything for runtime performance (this takes a few minutes)

### With chemacs2

If you use [chemacs2](https://github.com/plexus/chemacs2), add to `~/.emacs-profiles.el`:

```elisp
("zetta" . ((user-emacs-directory . "~/.zetta.d")))
```

Then launch with `emacs --with-profile zetta`.

## Quick Start

Edit `~/.zetta.el` to customize:

```elisp
;; Choose your theme
(setq zetta-theme 'modus-vivendi)

;; Choose your font
(setq zetta-font "JetBrains Mono")

;; Select which modules to load
(zetta-modules!
 :core
 :completion
 :ui (-nyan-mode -parrot)        ; skip nyan-mode and parrot
 :editor
 :lang (python yaml typescript-ts-mode)  ; only these languages
 :tools (magit lsp docker flycheck)
 :org
 :term)
```

API keys and credentials go in `~/.private.el` (see `.private.sample.el` for the template).

## CLI

```
bin/zetta <command>

  install          Install packages and native-compile
  sync             Re-evaluate config, install new packages
  freeze [--commit]  Write lockfile (optionally commit it)
  update           Pull all packages (backs up lockfile first)
  doctor           Diagnose environment and configuration
  test             Start test daemon and verify startup
```

## Modules

| Category      | Files | Description                                                          |
|---------------|-------|----------------------------------------------------------------------|
| `:core`       | 24    | Emacs defaults, buffers, projects, persistence, keybindings          |
| `:completion` | 20    | Vertico, consult, orderless, corfu, embark, marginalia               |
| `:ui`         | 54    | Themes, modeline, icons, treemacs, window management, visual aids    |
| `:editor`     | 29    | Evil + extensions, smartparens, snippets, undo-tree, avy, ace-window |
| `:lang`       | 25    | Python, TypeScript, YAML, Terraform, SQL, web-mode, tree-sitter      |
| `:tools`      | 50    | Magit, LSP, Docker, flycheck, dired, compile, git utilities          |
| `:app`        | 30    | Elfeed, bookmarks, Spotify, Mastodon, ERC, EWW, word lookup          |
| `:org`        | 11    | Org-mode, org-ref, citar, pdf-tools, org-capture, org-remark         |
| `:term`       | 4     | Vterm, shell, foreman                                                |

See [docs/modules.md](docs/modules.md) for detailed descriptions.

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

See [docs/keybindings.md](docs/keybindings.md) for the full reference.

## Package Management

Packages are pinned via `elpaca-lock.el`. To update:

```bash
bin/zetta update    # pull latest versions
bin/zetta freeze    # regenerate lockfile
```

Or set `(setq zetta-use-lockfile nil)` in `~/.zetta.el` for bleeding-edge.

## Structure

```
.zetta.d/
├── bin/zetta              # CLI wrapper
├── init.el                # Entry point
├── early-init.el          # Startup optimization
├── elpaca-lock.el         # Package version lockfile
├── templates/             # User config templates
│   └── zetta.example.el
├── source/
│   ├── bootstrap/         # Core initialization
│   ├── init-data/         # Default module file list
│   └── zettapkg/          # Bundled custom packages
├── modules/               # Package configurations
│   ├── core/
│   ├── completion/
│   ├── ui/
│   ├── editor/
│   ├── lang/
│   ├── tools/
│   ├── app/
│   ├── org/
│   └── term/
└── docs/                  # Documentation
```

## License

GPL-3.0
