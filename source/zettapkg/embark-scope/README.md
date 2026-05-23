# embark-scope

Type-aware structural navigation, instance pickers, and per-type
actions on top of [embark](https://github.com/oantolin/embark).

## What it does

Once you've embark-acted on a target, three command families operate
on its TYPE (not just its specific instance):

| Family | What |
|---|---|
| `embark-scope-nav-*` | Move by current target's type: `nav-next` / `-prev` / `-beg` / `-end` |
| `embark-scope-pick-*` | Pick a TYPE (consult + preview, or single-key transient) or a visible INSTANCE of one (consult or avy) |
| `embark-scope-act-*` | Act on the captured target — `act-focus`, `act-highlight-instances`, `act-select-as-region`, `act-narrow` |

Plus two cycle-augmentation modes:

- `embark-scope-sort-by-bounds-mode` — innermost-first cycle order on `embark--targets`.
- `embark-scope-back-cycle-mode` — `C-,` cycles backward (paired with `C-.` forward).

Plus utilities:

- `embark-scope-deftap-finder` macro — wrap any `thing-at-point` thing as an embark target finder.
- Fast collectors: regex sweep for URL / email / uuid; per-position thing-scan as fallback; specialized bracketed-org-link scanner for `embark-org` types.
- `embark-scope-jump-to-type` / `-avy-jump-to-type` — pick a type at the top level (no embark-act required) and jump.

## Quick start

```elisp
(use-package embark-scope
  :ensure t
  :after embark
  :config (embark-scope-setup))
```

`embark-scope-setup` does:
1. Enables `embark-scope-capture-mode` (required by all nav/act commands)
2. Enables `embark-scope-sort-by-bounds-mode`
3. Enables `embark-scope-back-cycle-mode`
4. Installs the default bindings (see `embark-scope-default-bindings`) into `embark-general-map`
5. Registers `embark-scope-defun-map` for the `defun` target type

To disable everything: `(embark-scope-capture-mode -1)` etc.

## Install (in-tree, before MELPA)

```elisp
(use-package embark-scope
  :ensure nil
  :load-path "path/to/embark-scope"
  :after embark
  :config (embark-scope-setup))
```

## Default bindings (after `embark-scope-setup`)

In `embark-general-map`:

| Key | Command | Use case |
|---|---|---|
| `C-j` | `embark-scope-nav-next` | Next instance of current type |
| `C-k` | `embark-scope-nav-prev` | Previous instance |
| `C-a` | `embark-scope-nav-beg` | Start of current target's bounds |
| `C-e` | `embark-scope-nav-end` | End of current target's bounds |
| `C-t` | `embark-scope-act-set-current-thing` | Set `treesit-tap-current-thing` to target's type |
| `C-f` | `embark-scope-act-focus` | Activate focus-mode on type |
| `C-v` | `embark-scope-act-select-as-region` | Region over current target |
| `C-n` | `embark-scope-act-narrow` | Narrow to current target |
| `C-l` | `embark-scope-pick-target-type` | Consult menu of types at point + preview |
| `;` | `embark-scope-pick-target-type-key` | Single-key transient menu |
| `C-o` | `embark-scope-pick-instance` | Consult menu of visible instances of current type |
| `C-;` | `embark-scope-avy-pick-instance` | Avy on visible instances |
| `*` | `embark-scope-act-highlight-instances` | Highlight all other instances of current type |

## The `capture-mode` requirement

`embark-scope-capture-mode` maintains `embark-scope-last-target-type`
and `embark-scope-last-target-bounds`. Every `nav-*` and `act-*`
command depends on these. Without capture-mode on, those commands
signal a `user-error` telling you to enable it.

`pick-*` commands work without capture-mode (they don't depend on a
prior target — they invoke embark-act after the pick).

`capture-mode` installs TWO writers — a `:always` pre-action hook
AND a `:filter-return` advice on `embark--rotate` — because cycling
targets via `C-.` / `C-,` doesn't fire pre-action hooks. Toggling
the mode cleanly removes both.

## Soft dependencies

`embark-scope` hard-depends on `emacs 29.1`, `embark`, and
`treesit-tap`. Optional integrations fire when their packages are
loaded:

- `avy` — required by `embark-scope-avy-pick-instance` and `-avy-jump-to-type`
- `consult` — required by `embark-scope-pick-target-type` and `-pick-instance`
- `embark-org` — when loaded, the org-link collectors activate for `org-url-link` / `org-email-link` / `org-file-link` types
- `focus` — `embark-scope-act-focus` requires it

## Customization

| Variable | Purpose |
|---|---|
| `embark-scope-nav-type-map` | Embark type → thing-at-point thing (for nav) |
| `embark-scope-symbol-target-types` | Embark types treated as symbol-shaped |
| `embark-scope-default-bindings` | Default `embark-general-map` bindings |
| `embark-scope-word-finder-modes` | Modes where the `word` target finder fires |
| `embark-scope-url-regex` / `-email-regex` | Regexes for the fast collectors |
| `embark-scope-sort-by-bounds-p` | Default cycle direction (innermost first when t) |
| `embark-scope-other-instance-face` | Highlight face |

## Why "by-type"?

The package gives embark a unified vocabulary for acting on TYPES:
nav-by-type, pick-by-type, act-by-type. The name `embark-cycle` (an
earlier candidate) collides with an existing built-in embark command.

## Status

v0.1. Stable API; submit-to-MELPA candidate after dogfooding.
