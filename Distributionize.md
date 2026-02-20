# Turning .zetta.d into an Emacs Distribution

A plan for transforming this personal Emacs configuration into a distributable Emacs framework, in the spirit of Spacemacs and Doom Emacs.

---

## Current Architecture Assessment

### Fully Distributable Components

| Component | Notes |
|---|---|
| `early-init.el` | Pure startup optimization, zero personal code |
| `bootstrap-elpaca.el` | Standard Elpaca package manager setup |
| `bootstrap-utils.el` | Just installs utility libraries (dash, s, f, ht, ts) |
| `bootstrap-keys.el` | Generic keybinding framework — excellent `launch-map` abstraction over evil/meow/emacs |
| `bootstrap-brushup.el` | Theme-aware parametric gradient system — fully parameterized, reusable |
| `bootstrap-evil.el` | Standard evil configuration |
| `repeatable-lite/` (zettapkg) | Well-designed repeatable keymap system |
| `space-tree/` (zettapkg) | Clean workspace management — MELPA-ready |
| `convention/` (zettapkg) | Docker container workflow, well-modularized |
| `gha/` (zettapkg) | GitHub Actions integration, generic workflow |
| `zetta-load-config-file()` | Generic file loading mechanism |

### Partially Distributable (Need Abstraction)

| Component | Issue |
|---|---|
| `init.el` | Logic is generic; hardcoded personal paths (bookmarks, tramp profiles) |
| `init-data.el` | List structure is sound; 276-entry list contents are personal |
| `bootstrap-display.el` | Framework (`zetta-side`) is generic; dimension configs are personal |
| `bootstrap-org.el` | Core setup generic; custom variables and paths mixed in |
| `bootstrap-zettafn.el` | Half utility library, half personal tools |
| `spot4e/` (zettapkg) | **Exposes hardcoded Spotify API credentials — must remove before any distribution** |

### Not Distributable (Personal)

- `~/.private.el` — API keys and secrets
- Most of `config/` — personal workflow configurations
- Bookmarks, elfeed subscriptions, forge database
- Tramp connection profiles

---

## Differentiators

These are the unique strengths that would define this distro's identity:

1. **brushup** — No other distro has parametric theme-aware color gradients. Packages register styles in `brushup-styles` and faces auto-update on theme change.
2. **repeatable-lite** — Unique repeatable prefix command system integrated with which-key.
3. **Triple-modal support** — Evil, Meow, and vanilla Emacs editing in one config, switchable with `s-z m/e/E`.

---

## Key Architectural Changes

### 1. Introduce a Module System

The flat `user-files` list in `init-data.el` (~276 entries) must become an opt-in module system. Group config files into modules:

```elisp
;; User's config file (~/.zetta.el):
(zetta-modules!
 :core        ; emacs.el, files.el, buffers.el — always loaded
 :completion  ; vertico, consult, orderless, corfu
 :ui          ; themes, modeline, treemacs, dashboard
 :editor      ; evil, snippets, multiple-cursors
 :lang        ; python, rust, go, javascript...
 :tools       ; magit, docker, lsp, dap
 :app         ; elfeed, spotify, mu4e
)
```

Each module is a directory containing `config.el` (package configurations) and optionally `packages.el` (declarations). Users enable/disable modules in a single init file rather than editing the distro's files.

**Implementation:** Write a `zetta-modules!` macro that:
- Accepts a keyword list of module categories
- Each category maps to a directory under `modules/`
- Loads `config.el` from each enabled module
- Replaces the current `user-files` list in `init-data.el`

### 2. Separate Framework from Opinion

Split into three tiers:

- **Core framework** (non-optional): early-init, Elpaca bootstrap, config loading, brushup, keybinding infrastructure
- **Default modules** (enabled by default, can be disabled): evil, vertico, magit, org, etc.
- **Optional modules** (disabled by default): spot4e, convention, elfeed, etc.

### 3. Abstract Personal Paths into a User Config File

Create a user-facing config entry point:

```elisp
;; ~/.zetta.el (or ~/.config/zetta/config.el)
(setq zetta-leader-key ","
      zetta-org-directory "~/org/"
      zetta-font "JetBrains Mono"
      zetta-theme 'modus-vivendi)

(zetta-modules!
 :lang (python rust go)
 :tools (magit docker lsp))
```

This replaces the current pattern of editing `init-data.el` directly. The distro's own files are never modified by users.

### 4. Create a CLI Installer

Like `doom install` or Crafted Emacs' setup:

```bash
git clone https://github.com/you/zetta ~/.zetta.d
~/.zetta.d/bin/zetta install   # install packages, build native comp
~/.zetta.d/bin/zetta sync      # after config changes
~/.zetta.d/bin/zetta doctor    # diagnose issues
~/.zetta.d/bin/zetta freeze    # write lockfile (see below)
```

---

## Reproducibility with Elpaca

### Lock File Support

Elpaca has functional (if minimal) lockfile support, already present in the installed version.

**Key pieces:**

- `elpaca-write-lock-file` — Interactive command that snapshots every queued package's exact commit SHA into an elisp alist file.
- `elpaca-lock-file` — Variable pointing to that file. When set, `elpaca-menu-lock-file` (already first in the default `elpaca-menu-functions` list) uses those exact commits when installing.

**Setup (add to bootstrap-elpaca.el):**

```elisp
(setq elpaca-lock-file
      (expand-file-name "elpaca-lock.el" user-emacs-directory))
```

**Workflow:**

1. Develop and test with latest packages.
2. When stable, run `M-x elpaca-write-lock-file` — commit the resulting `elpaca-lock.el` into the repo.
3. Users clone the distro and get the lockfile — Elpaca installs those exact versions.
4. Users who want bleeding edge can set `elpaca-lock-file` to `nil`.

Step 2 should be wrapped into the CLI: `bin/zetta freeze`.

### Per-Package Pinning

Three recipe keywords, all of which mark the package as "pinned" (skipped by `elpaca-fetch-all` / `elpaca-pull-all`):

```elisp
;; Pin to exact commit (highest precision):
(use-package some-pkg :ensure (:ref "a76ca0a"))

;; Pin to a git tag (release-level control):
(use-package some-pkg :ensure (:tag "v2.1"))

;; Freeze at whatever is currently installed:
(use-package some-pkg :ensure (:pin t))
```

### Comparison with straight.el

| | straight.el | elpaca |
|---|---|---|
| Freeze all versions | `straight-freeze-versions` | `M-x elpaca-write-lock-file` |
| Restore from lockfile | `straight-thaw-versions` | Set `elpaca-lock-file`, delete + restart |
| Lockfile format | elisp alist | elisp alist |
| Pin single package | `:pin` in recipe | `:ref`, `:tag`, or `:pin` in recipe |
| Single-command restore | Yes | **No** — weakest point |

### The Gap

The restore workflow is the rough edge. With straight.el you run `straight-thaw-versions` and you're done. With Elpaca, restoring means: delete affected packages, set `elpaca-lock-file`, restart Emacs. There is no single "thaw" command yet. This is functional but less polished.

---

## Task List

### Phase 1: Security & Cleanup

Tasks 1-3 can be done in parallel. All must complete before Phase 2.

- [x] **Task 1: Remove hardcoded credentials from config files**

  CRITICAL. Multiple files contain plaintext credentials:

  | File | Line(s) | Content | Severity |
  |------|---------|---------|----------|
  | `source/zettapkg/spot4e/spot4e.el` | 28-29 | Spotify client ID and secret | CRITICAL |
  | `source/config/wombag.el` | 7-11 | Wallabag username, plaintext password, OAuth client ID and secret | CRITICAL |
  | `source/config/elfeed.el` | 43-45 | Miniflux username in URL, plaintext password | CRITICAL |
  | `source/config/lsp.el` | 70 | Database connection string with password | MEDIUM |

  For each: replace with a `defvar` defaulting to `nil`, add a comment pointing to `~/.private.el`, move actual values into `~/.private.el`. Create a `.private.sample.el` template showing what users need to set.

  After fixing, **rotate/regenerate all exposed credentials** (Spotify, Wallabag, Miniflux).

- [x] **Task 2: Audit and remove personal identifiers**

  Remove or abstract personal identifiers:

  | File | Line(s) | Content |
  |------|---------|---------|
  | `init.el` | 30 | Tramp machine hostname `WQN4T69J6P` |
  | `source/config/erc.el` | 10-11 | Hardcoded nick `REDACTED` and full name |
  | `source/config/erc.el` | 1 | Google Drive share link in comment |
  | `fetch_mail.sh` | 14 | Username `REDACTED` in mbsync command |

  Make these configurable via `defcustom` or user config variables.

- [x] **Task 3: Replace hardcoded paths with portable alternatives**

  ~30 files use `~/.files/.zetta.d/` or other absolute paths. Replace with `user-emacs-directory` and `expand-file-name`. Define a `zetta-dir` variable for the distro root.

  Files to fix:

  | File | Line(s) | Path |
  |------|---------|------|
  | `source/bootstrap/bootstrap-config.el` | 5 | `straight-base-dir` |
  | `source/bootstrap/bootstrap-repeatable-lite.el` | 6 | `:load-path` |
  | `source/bootstrap/bootstrap-zettafn.el` | 79, 89 | `keybindings.org`, `read.org` |
  | `source/bootstrap/bootstrap-menu.el` | 6 | `:load-path` |
  | `source/zettapkg/spot4e/spot4e.el` | 5 | `:load-path` |
  | `source/config/convention.el` | 3 | `:load-path` |
  | `source/config/foreman.el` | 3 | `:load-path` |
  | `source/config/desktop.el` | 16 | desktop path |
  | `source/config/elfeed.el` | 239 | `elfeed.org` path |
  | `source/config/biblio.el` | 3 | bibliography path |
  | `source/config/org-ref.el` | 9-11 | bibliography paths |
  | `source/config/citar.el` | 19, 25 | bibliography paths |
  | `source/config/utility.el` | 9, 25, 45 | bibliography and history paths |
  | `source/config/simple.el` | 19, 24 | `.zsh_history` path |
  | `source/config/multi-compile.el` | 613 | tmuxinator path |

---

### Phase 2: Module System

Sequential. Task 4 blocked by 1-3. Task 5 blocked by 4. Task 6 blocked by 5.

- [x] **Task 4: Create module directory structure** *(blocked by: 1, 2, 3)*

  Reorganize the flat `source/config/` directory (~268 files) into module directories:

  ```
  modules/
  ├── core/       (17 files) — emacs, simple, utility, interface, desktop, remote,
  │                             security, keys, xref, project, persist, smerge-mode,
  │                             repeat-mode, saveplace, savehist, comint, cleanup
  ├── completion/ (19 files) — completion, cape, dabbrev, helm, marginalia, orderless,
  │                             embark, embark-consult, consult, tap, tap-block, vertico,
  │                             prescient, mono-complete, consult-gh, consult-omni,
  │                             consult-lsp, consult-dash, consult-ls-git
  ├── ui/         (48 files) — display, hud, themes, modeline, treemacs, icons, fonts,
  │                             rainbow, window, tab-line, breadcrumb, etc.
  ├── editor/     (28 files) — evil extensions, smartparens, snippets, ace-window, avy,
  │                             undo-tree, iedit, move-text, text-manipulation, etc.
  ├── lang/       (23 files) — python, web-mode, js2-mode, typescript, yaml, terraform,
  │                             sql, csv-mode, sh-script, json-mode, etc.
  ├── tools/      (60 files) — magit, docker, lsp, dap, flycheck, compile, dired, grep,
  │                             git-link, git-timemachine, pr-review, devdocs, etc.
  ├── app/        (31 files) — elfeed, spotify, wombag, bookmarks, olivetti, mastodon,
  │                             erc, nov, whisper, define-word, etc.
  ├── org/        (11 files) — org, org-ql, org-capture, org-ref, pdf-tools, citar,
  │                             org-remark, org-tree-slide, org-transclusion, etc.
  └── term/       (4 files)  — shell, vterm, foreman, foreman_conf
  ```

  Each module directory gets a `config.el` that loads its constituent files.

- [x] **Task 5: Write `zetta-modules!` macro** *(blocked by: 4)*

  Write the core macro that replaces the flat `user-files` list in `init-data.el`.

  Requirements:
  - Accept keyword-based module spec: `(zetta-modules! :core :completion :ui :editor :lang (python rust) :tools (magit lsp docker))`
  - Categories without sub-lists load all files in that module directory
  - Categories with sub-lists load only the specified files
  - Respect bootstrap load order (core first)
  - Support disabling defaults: `(:ui -treemacs -nyan-mode)`
  - Integrate with `zetta-load-config-file` for actual file loading

  Lives in a new `bootstrap-modules.el`, called from the user's `~/.zetta.el`.

- [x] **Task 6: Create user config template (`~/.zetta.el`)** *(blocked by: 5)*

  Create a template user config file as the entry point for customization:

  - `defcustom`-style variables: `zetta-leader-key`, `zetta-org-directory`, `zetta-font`, `zetta-theme`, `zetta-modal-system` (evil/meow/emacs)
  - A `zetta-modules!` declaration with sensible defaults
  - Comments explaining each option
  - Sections for user's own `use-package` declarations and keybinding overrides

  Deliverables:
  1. `templates/zetta.example.el` — shipped with distro, documented
  2. Logic in `init.el` to load `~/.zetta.el` if it exists, falling back to bundled defaults

---

### Phase 3: Reproducibility & Tooling

Tasks 7 and 8 can run in parallel. Task 9 blocked by 5 and 7.

- [x] **Task 7: Enable Elpaca lockfile and generate initial lock** *(blocked by: 5)*

  1. Add to `bootstrap-elpaca.el`:
     ```elisp
     (setq elpaca-lock-file (expand-file-name "elpaca-lock.el" user-emacs-directory))
     ```
  2. Start Emacs, let all packages install/build
  3. Run `M-x elpaca-write-lock-file` to generate initial lockfile
  4. Commit `elpaca-lock.el` into the repo
  5. Add `defcustom zetta-use-lockfile` (default `t`) so users can opt out

- [x] **Task 8: Extract standalone packages to separate repos** *(independent)*

  Extract the three most distribution-worthy packages from `source/zettapkg/`:

  | Package | Status | Needs |
  |---------|--------|-------|
  | `space-tree` | Has proper package headers | LICENSE, README, CI |
  | `repeatable-lite` | Functional | Package headers, LICENSE, README, CI |
  | `brushup` | Currently in `bootstrap-brushup.el` | Extract to own `.el`, package headers, LICENSE, README, CI |

  For each:
  - Create repo at `~/source_code/<package-name>/`
  - Add GPL-3.0 LICENSE, README with usage examples
  - Set up GitHub Actions for byte-compilation testing
  - Update distro to reference via `:ensure (:host github :repo "you/<pkg>")`
  - Keep local dev path in personal `~/.zetta.el` via `:ensure nil` + `load-path`

- [x] **Task 9: Write `bin/zetta` CLI wrapper** *(blocked by: 5, 7)*

  Shell script with subcommands:

  | Command | Purpose |
  |---------|---------|
  | `zetta install` | Clone repo, run Emacs batch mode to install packages, native-compile |
  | `zetta sync` | Re-evaluate config, install new packages, remove orphans |
  | `zetta freeze` | Run `elpaca-write-lock-file` in batch mode, commit result |
  | `zetta update` | `elpaca-pull-all` in batch mode (with lockfile backup) |
  | `zetta doctor` | Diagnose: Emacs version, missing deps, broken packages, credential files |
  | `zetta test` | Start daemon, verify startup, check for errors |

  Written in bash/zsh. Calls `emacs --batch` or `emacsclient` as needed. Model after Doom's `bin/doom`.

---

### Phase 4: Polish

- [x] **Task 10: Write README and module documentation** *(blocked by: 4, 5, 9)*

  1. **`README.md`** (repo root):
     - Elevator pitch (brushup, triple-modal, repeatable-lite)
     - Screenshots/GIFs
     - Installation (`git clone` + `bin/zetta install`)
     - Quick start (editing `~/.zetta.el`, choosing modules)
     - Requirements (Emacs 29+, git, ripgrep, etc.)

  2. **`docs/modules.md`** — Reference for each module category

  3. **`docs/keybindings.md`** — Cheat sheet for `launch-map`, modal switching, key bindings

  4. **Module headers** — Each module's `config.el` gets a comment block explaining purpose and required external tools

- [x] **Task 11: Rename `z-` prefix to `zetta-` namespace** *(blocked by: 4, 5)*

  Repo-wide find-and-replace of `z-` prefixed functions and variables to `zetta-`. Must only rename custom definitions, not built-in Emacs functions.

  This is optional but recommended for a public distro. **Do last** as it touches every file.

- [ ] **Task 12: Rotate exposed credentials** *(independent)*

  Credentials for the following services were previously committed to git history and must be regenerated:

  | Service | What to rotate |
  |---------|----------------|
  | Spotify | Client ID and secret at [developer.spotify.com](https://developer.spotify.com/dashboard) |
  | Wallabag | Password + regenerate OAuth client at your Wallabag instance |
  | Miniflux | Password at your Miniflux instance |

  After rotating, update the new values in `~/.private.el`. Consider running `git filter-repo` or BFG Repo-Cleaner to scrub the old values from git history before making the repo public.

---

## Managing Self-Authored Packages

Several packages in `source/zettapkg/` (space-tree, repeatable-lite, brushup, convention, gha, etc.) are original work worth publishing independently. This section covers how to structure them for both local development and public distribution.

### Separate Repos vs. Keeping zettapkg

**Separate repos is the right move for packages you want others to use.** Here's why:

- MELPA requires each package to live in its own Git repository.
- Independent repos get their own issue trackers, stars, CI, and versioning.
- Other users (including non-distro users) can install them standalone.
- Your distro declares them as dependencies rather than bundling them.

However, **not everything needs to be extracted.** Use this rule of thumb:

| Package | Extract? | Reason |
|---|---|---|
| `space-tree` | **Yes** | Novel, general-purpose, MELPA candidate |
| `repeatable-lite` | **Yes** | Useful standalone, clean API |
| `brushup` | **Yes** | Unique color system, any config can use it |
| `convention` | Maybe | Docker workflow — niche but self-contained |
| `gha` | Maybe | GitHub Actions — small, could be a gist or package |
| `spot` / `spot4e` | Maybe | Spotify integration — niche audience |
| `j`, `menu` | Probably not | Tightly coupled to distro internals |
| `foreman` | Probably not | Likely too specific |

**Recommended directory layout:**

```
~/source_code/
├── space-tree/           # standalone repo → github.com/you/space-tree
│   ├── space-tree.el
│   ├── README.md
│   ├── LICENSE
│   └── .github/          # CI for byte-compilation, testing
├── repeatable-lite/      # standalone repo
│   └── ...
└── brushup/              # standalone repo
    └── ...

~/.zetta.d/
└── source/zettapkg/
    ├── j/                # stays here — distro-internal
    ├── menu/             # stays here — distro-internal
    └── foreman/          # stays here — distro-internal
```

### Local Development vs. Public Distribution

The core problem: you want to hack on `space-tree` locally in `~/source_code/space-tree/` while your distro tells users to install it from GitHub. Elpaca handles this cleanly.

#### How It Works

**In your distro's module config (what users get):**

```elisp
;; modules/ui/config.el — public recipe, fetches from GitHub
(use-package space-tree
  :ensure (:host github :repo "you/space-tree"))
```

**In your personal `~/.zetta.el` (overrides the distro recipe):**

```elisp
;; Point to your local checkout for development
(use-package space-tree
  :ensure (:host github :repo "you/space-tree"
           :local-path "~/source_code/space-tree"))
```

Elpaca's `:local-path` recipe keyword tells it to symlink to your local directory instead of cloning from the remote. You edit files in `~/source_code/space-tree/`, changes take effect immediately (after `eval-buffer` or restart), and the remote repo is never touched until you push.

#### Alternative: :repo with a local file path

If `:local-path` is unavailable in your Elpaca version, you can use the `load-path` approach:

```elisp
;; In your personal ~/.zetta.el, before the distro loads:
(push "~/source_code/space-tree" load-path)

;; Then override the ensure to skip remote install:
(use-package space-tree
  :ensure nil)   ; don't fetch — already on load-path
```

This is simpler but less integrated with Elpaca's update machinery.

#### Workflow Summary

```
┌─────────────────────────────────────────────────────┐
│ Your machine (developer)                            │
│                                                     │
│  ~/source_code/space-tree/  ← you edit here         │
│         │                                           │
│         │ symlink or load-path                      │
│         ▼                                           │
│  ~/.zetta.d/ loads space-tree from local path       │
│         │                                           │
│         │ git push                                  │
│         ▼                                           │
│  github.com/you/space-tree  ← public repo           │
│                                                     │
├─────────────────────────────────────────────────────┤
│ User's machine                                      │
│                                                     │
│  ~/.zetta.d/ loads space-tree via Elpaca from       │
│  github.com/you/space-tree (pinned by lockfile)     │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Publishing to MELPA

For packages you extract, the MELPA submission process:

1. Ensure the package has a proper header (`;;; space-tree.el --- ...`), `Version:`, `Package-Requires:`, and autoloads (`;;;###autoload`).
2. Add a `LICENSE` file (GPL-3.0 is standard for Emacs packages).
3. Submit a PR to [melpa/melpa](https://github.com/melpa/melpa) with a recipe file.
4. Once accepted, users can install via `M-x package-install` or any package manager.

Your distro can then reference the MELPA version, and Elpaca will fetch it from there — no `:host github` needed.

### Packages That Stay in zettapkg

For distro-internal packages that don't warrant their own repo, keep them in `source/zettapkg/` and load with `:ensure nil`:

```elisp
(use-package menu
  :ensure nil
  :demand t
  :load-path "source/zettapkg/menu")
```

These ship with the distro and are loaded directly from the tree. No separate install step for users.

---

## Reference: Distributions to Study

- **Doom Emacs** (`doomemacs/doomemacs`) — Best module system, CLI tooling, and lockfile approach. Study `lisp/doom-modules.el` and `lisp/doom-packages.el`.
- **Spacemacs** (`syl20bnr/spacemacs`) — Layer system is the original approach, but more complex. Study the "layer" concept.
- **Crafted Emacs** (`SystemCrafters/crafted-emacs`) — Simpler, more modern take. Good model for a lighter-weight distro.

---

## Naming

The internal prefix is `zetta-` for all custom functions and variables. This was renamed from the original `z-` prefix for clarity and to avoid namespace collisions.
