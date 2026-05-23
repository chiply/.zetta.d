# embark-by-type

Type-aware structural navigation, instance pickers, and per-type
actions on top of [embark](https://github.com/oantolin/embark).

## What it does

Once you've embark-acted on a target, three command families operate
on its TYPE (not just its specific instance):

| Family | What |
|---|---|
| `embark-by-type-nav-*` | Move by current target's type: `nav-next` / `-prev` / `-beg` / `-end` |
| `embark-by-type-pick-*` | Pick a TYPE (consult + preview, or single-key transient) or a visible INSTANCE of one (consult or avy) |
| `embark-by-type-act-*` | Act on the captured target — `act-focus`, `act-highlight-instances`, `act-select-as-region`, `act-narrow` |

Plus two cycle-augmentation modes:

- `embark-by-type-sort-by-bounds-mode` — innermost-first cycle order on `embark--targets`.
- `embark-by-type-back-cycle-mode` — `C-,` cycles backward (paired with `C-.` forward).

Plus utilities:

- `embark-by-type-deftap-finder` macro — wrap any `thing-at-point` thing as an embark target finder.
- Fast collectors: regex sweep for URL / email / uuid; per-position thing-scan as fallback; specialized bracketed-org-link scanner for `embark-org` types.
- `embark-by-type-jump-to-type` / `-avy-jump-to-type` — pick a type at the top level (no embark-act required) and jump.

## Quick start

```elisp
(use-package embark-by-type
  :ensure t
  :after embark
  :config (embark-by-type-setup))
```

`embark-by-type-setup` does:
1. Enables `embark-by-type-capture-mode` (required by all nav/act commands)
2. Enables `embark-by-type-sort-by-bounds-mode`
3. Enables `embark-by-type-back-cycle-mode`
4. Installs the default bindings (see `embark-by-type-default-bindings`) into `embark-general-map`
5. Registers `embark-by-type-defun-map` for the `defun` target type

To disable everything: `(embark-by-type-capture-mode -1)` etc.

## Install (in-tree, before MELPA)

```elisp
(use-package embark-by-type
  :ensure nil
  :load-path "path/to/embark-by-type"
  :after embark
  :config (embark-by-type-setup))
```

## Default bindings (after `embark-by-type-setup`)

In `embark-general-map`:

| Key | Command | Use case |
|---|---|---|
| `C-j` | `embark-by-type-nav-next` | Next instance of current type |
| `C-k` | `embark-by-type-nav-prev` | Previous instance |
| `C-a` | `embark-by-type-nav-beg` | Start of current target's bounds |
| `C-e` | `embark-by-type-nav-end` | End of current target's bounds |
| `C-t` | `embark-by-type-act-set-current-thing` | Set `treesit-tap-current-thing` to target's type |
| `C-f` | `embark-by-type-act-focus` | Activate focus-mode on type |
| `C-v` | `embark-by-type-act-select-as-region` | Region over current target |
| `C-n` | `embark-by-type-act-narrow` | Narrow to current target |
| `C-l` | `embark-by-type-pick-target-type` | Consult menu of types at point + preview |
| `;` | `embark-by-type-pick-target-type-key` | Single-key transient menu |
| `C-o` | `embark-by-type-pick-instance` | Consult menu of visible instances of current type |
| `C-;` | `embark-by-type-avy-pick-instance` | Avy on visible instances |
| `*` | `embark-by-type-act-highlight-instances` | Highlight all other instances of current type |

## The `capture-mode` requirement

`embark-by-type-capture-mode` maintains `embark-by-type-last-target-type`
and `embark-by-type-last-target-bounds`. Every `nav-*` and `act-*`
command depends on these. Without capture-mode on, those commands
signal a `user-error` telling you to enable it.

`pick-*` commands work without capture-mode (they don't depend on a
prior target — they invoke embark-act after the pick).

`capture-mode` installs TWO writers — a `:always` pre-action hook
AND a `:filter-return` advice on `embark--rotate` — because cycling
targets via `C-.` / `C-,` doesn't fire pre-action hooks. Toggling
the mode cleanly removes both.

## Soft dependencies

`embark-by-type` hard-depends on `emacs 29.1`, `embark`, and
`treesit-tap`. Optional integrations fire when their packages are
loaded:

- `avy` — required by `embark-by-type-avy-pick-instance` and `-avy-jump-to-type`
- `consult` — required by `embark-by-type-pick-target-type` and `-pick-instance`
- `embark-org` — when loaded, the org-link collectors activate for `org-url-link` / `org-email-link` / `org-file-link` types
- `focus` — `embark-by-type-act-focus` requires it

## Customization

| Variable | Purpose |
|---|---|
| `embark-by-type-nav-type-map` | Embark type → thing-at-point thing (for nav) |
| `embark-by-type-symbol-target-types` | Embark types treated as symbol-shaped |
| `embark-by-type-default-bindings` | Default `embark-general-map` bindings |
| `embark-by-type-word-finder-modes` | Modes where the `word` target finder fires |
| `embark-by-type-url-regex` / `-email-regex` | Regexes for the fast collectors |
| `embark-by-type-sort-by-bounds-p` | Default cycle direction (innermost first when t) |
| `embark-by-type-other-instance-face` | Highlight face |

## Why "by-type"?

The package gives embark a unified vocabulary for acting on TYPES:
nav-by-type, pick-by-type, act-by-type. The name `embark-cycle` (an
earlier candidate) collides with an existing built-in embark command.

## Status

v0.1. Stable API; submit-to-MELPA candidate after dogfooding.
