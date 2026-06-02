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

## Commands

The primary interface is evil text-object keys (`vif` / `daf` / `2vac`
/ &c.), not standalone commands.  The keys come from the `i` and `a`
prefixes in `evil-inner-text-objects-map` / `-outer-text-objects-map`
combined with the per-thing key from `treesit-textobj-keys`.

| Command | What |
|---|---|
| `treesit-textobj-mode` (buffer-local minor mode) | Self-gates the generated text-object commands.  Turn on per `:hook` (see install snippet) |
| `treesit-textobj-install-bindings` | Re-install bindings into `evil-{inner,outer}-text-objects-map`.  Run after customizing `treesit-textobj-keys` or `treesit-textobj-things` |
| `treesit-textobj-find-ancestor THING [COUNT]` | Public helper.  Returns the COUNT-th tree-sitter ancestor at point matching THING, or nil.  Useful for building your own commands (e.g. movement) without duplicating the lookup logic |

Generated text-object commands (named `treesit-textobj-inner-<thing>`
and `treesit-textobj-outer-<thing>`) are wired into evil's maps under
the keys in `treesit-textobj-keys`.  You normally invoke them via
operator/visual state (`vif`, `dac`, etc.), not by name.

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
