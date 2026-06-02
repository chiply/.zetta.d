# Keybindings Reference

## Leader Key

The leader key is `,` (comma) in Evil normal/visual states and Meow non-insert states. In insert state, use `C-,` (Control+comma).

Press `,` and wait for which-key to show available keys, or press `C-h` after the leader to see all bindings.

## Leader Menus

| Key | Menu | Purpose |
|-----|------|---------|
| `, g` | Version control | Magit status, log, blame, git-link, timemachine |
| `, p` | Project | Find file, switch project, search in project |
| `, w` | Window | Split, delete, balance, ace-window |
| `, l` | Lookup | Consult search, devdocs, dash docsets |
| `, o` | Org | Capture, agenda, org-ql, refile |
| `, r` | Run | Compile, multi-compile, shell, messages |
| `, t` | Theme | Switch theme, brushup refresh |
| `, h` | Help | Describe key/function/variable, info |
| `, d` | Smerge | Navigate and resolve merge conflicts |
| `, i` | iedit | Edit all occurrences of symbol |

Each menu opens a which-key popup showing all available subkeys.

## Modal Editing

Zetta supports three modal editing systems, switchable at runtime:

| Key | Command | Mode |
|-----|---------|------|
| `s-z e` | `zetta-state-evil` | Evil mode (vim emulation) |
| `s-z m` | `zetta-state-meow` | Meow mode (selection-first editing) |
| `s-z E` | `zetta-state-emacs` | Vanilla Emacs (no modal editing) |

`s-` is the Super key (Command on macOS, Windows key on Linux).

Evil mode is active by default.

## Package Management

| Key | Command | Description |
|-----|---------|-------------|
| `s-u` | `elpaca-fetch-all` | Fetch updates for all packages |
| `s-U` | `elpaca-pull-all` | Pull (install) updates for all packages |

## Side Window Display

The `zetta-side` system manages side windows for buffers like Messages, compilation output, and help.

Run menu commands (`**, r m` etc.) use the `**` repeatable macro for quick toggling:

| Key | Command | Description |
|-----|---------|-------------|
| `, r m` | Messages | Show/focus *Messages* buffer |
| `, r M` | Close Messages | Close Messages side window |
| `, r c` | Calendar | Open calendar |
| `, r i` | Info | Open Info documentation |
| `, r I` | Close Info | Close Info side window |

## Evil Mode Essentials

Standard vim keybindings apply. Zetta adds:

| Key | Package | Description |
|-----|---------|-------------|
| `g s SPC` | evil-surround | Surround text objects |
| `g x` | evil-exchange | Exchange text regions |
| `g ;` | evil-anzu | Search count indicator |
| `> i` / `< i` | evil-indent-plus | Select by indentation |

## Navigation

| Key | Package | Description |
|-----|---------|-------------|
| `C-'` | avy | Jump to character on screen |
| `M-o` | ace-window | Switch between windows |
| `C-c C-j` | dumb-jump | Jump to definition (no LSP needed) |

## Repeatable Commands

The `repeatable` system wraps commands so they can be repeated with a single key after the first invocation. Look for the `**` indicator in the tab bar when a repeatable command is active.

## Customizing Keybindings

Add to `~/.zetta.el`:

```elisp
;; Add a binding to the leader map
(general-define-key
 :keymaps 'launch-map
 "x" 'my-custom-command)

;; Add to a specific menu
(general-define-key
 :keymaps 'menu-vc-map
 "X" 'my-git-command)

;; Global binding
(global-set-key (kbd "C-c x") 'my-command)

;; Evil-state-specific binding
(general-define-key
 :states '(normal visual)
 "gz" 'my-command)
```

Available prefix maps for `:keymaps`:
- `launch-map` — the top-level leader menu
- `menu-window-map` — `, w`
- `menu-project-map` — `, p`
- `menu-vc-map` — `, g`
- `menu-lookup-map` — `, l`
- `menu-org-map` — `, o`
- `menu-run-map` — `, r`
- `menu-theme-map` — `, t`
- `menu-help-map` — `, h`
- `menu-smerge-map` — `, d`
- `menu-iedit-map` — `, i`
