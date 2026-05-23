# tap-fold

Overlay-based folding of any `thing-at-point` thing. Universal:
paragraph, sentence, defun, sexp, word, line, function, class, call,
or any custom thing.

Unlike line-snapped folding (`hideshow`, `outline`, `treesit-fold`),
this layer hides arbitrary bounds. A sentence inside a line can be
folded with the rest of the line still visible (ellipsis in place of
the hidden span).

## Quick start

```elisp
(use-package tap-fold
  :ensure t
  :bind (("s-x f"   . tap-fold-thing-at-point)
         ("s-x F"   . tap-fold-unfold-at-point)
         ("s-x M-f" . tap-fold-unfold-all)))
```

Then `s-x f` at any point: pick from things that have bounds at point
(consult preview shows what gets folded), commit to fold.

## Commands

| Command | What |
|---|---|
| `tap-fold-thing-at-point` | Pick a thing at point + fold (with consult preview) |
| `tap-fold-thing THING` | Non-interactive: fold THING at point |
| `tap-fold-region BEG END` | Fold an arbitrary region |
| `tap-fold-toggle-thing-at-point THING` | Unfold if at fold, else fold THING |
| `tap-fold-unfold-at-point` | Remove the fold at point |
| `tap-fold-unfold-all` | Clear every fold in buffer |
| `tap-fold-current-thing` | Fold `treesit-tap-current-thing` (requires `treesit-tap`) |
| `tap-fold-embark-target` | Fold the captured embark target's bounds (requires `embark-by-type-capture-mode` on) |

## Customization

| Variable | Purpose |
|---|---|
| `tap-fold-things` | Things to offer in `tap-fold-thing-at-point` (default: paragraph / sentence / defun / sexp / word / line) |
| `tap-fold-preview-face` | Face used for the consult preview |

Extend `tap-fold-things` with any custom thing:

```elisp
(push 'orgtree tap-fold-things)
(push 'brick tap-fold-things)
```

## Soft integrations

`tap-fold` itself depends only on Emacs 29.1. Three optional
integrations fire when the relevant package is loaded:

- **consult** — preview UI in `tap-fold-thing-at-point` highlights
  exactly what gets folded as you narrow through candidates. Without
  consult: plain `completing-read`, no preview.
- **treesit-tap** — `tap-fold-current-thing` folds the buffer-local
  `treesit-tap-current-thing`. Useful when you've set the current
  thing via `treesit-tap-set-local` and want to fold instances of it.
- **embark-by-type** — `tap-fold-embark-target` folds the captured
  embark target's bounds. Requires `embark-by-type-capture-mode` to
  be on; signals a `user-error` with a clear message otherwise.

## Why "tap-fold"?

`thing-at-point` is the universal API for typed regions; "tap" is
the conventional abbreviation. Distinct from `treesit-fold` (the
existing tree-sitter-specific folder) which is structural and
line-snapped.

## Status

v0.1.
