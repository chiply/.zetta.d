# treesit-textobj

Tree-sitter text objects for `evil-mode`, backed by Emacs's built-in
tree-sitter parsers. No external query files, no structural-edit
operators — just `vif` / `vaf` / `dif` / `daf`-style selections for
language constructs.

## Things and keys

| Key | Thing     |
|-----|-----------|
| `f` | function  |
| `c` | class     |
| `g` | parameter |
| `/` | call      |
| `q` | string    |
| `C` | comment   |

So in operator or visual state: `vaf` selects the enclosing function,
`dif` deletes its body, `2vaf` jumps up to the next enclosing function
or class.

## Languages out of the box

`python-ts-mode`, `typescript-ts-mode`, `tsx-ts-mode`,
`javascript-ts-mode`, `rust-ts-mode`, `c-ts-mode`, `c++-ts-mode`,
`go-ts-mode`. Derived modes inherit via `derived-mode-parent`.

## Install

In-tree (as part of a larger config):

```elisp
(use-package treesit-textobj
  :ensure nil
  :load-path "path/to/treesit-textobj"
  :after evil
  :hook ((python-ts-mode typescript-ts-mode tsx-ts-mode
          javascript-ts-mode rust-ts-mode
          c-ts-mode c++-ts-mode go-ts-mode)
         . treesit-textobj-mode))
```

After MELPA release (future):

```elisp
(use-package treesit-textobj
  :ensure t
  :hook ((python-ts-mode typescript-ts-mode ...) . treesit-textobj-mode))
```

## Customization

- `treesit-textobj-things` — alist of `(THING . ((MAJOR-MODE . NODE-TYPES) …))`.
  Add languages or override node types here.
- `treesit-textobj-keys` — alist of `(THING . KEY)`. Change the suffix
  pressed after `i` / `a`.
- `treesit-textobj-inner-body-fields` — alist of `(THING . FIELD)`.
  When set, the inner range uses the bounds of the named field's child,
  stripping outer braces/parens. Defaults: function/class → `"body"`,
  call → `"arguments"`.

After customizing keys or things, run `M-x
treesit-textobj-install-bindings` (or toggle the mode) to refresh.

## Status

v0.1: evil entry points only, per-buffer activation via the
`treesit-textobj-mode` minor mode. No movement (`]f` / `[f`), no
structural operators, no meow integration. The name is editor-agnostic
to leave room for those.
