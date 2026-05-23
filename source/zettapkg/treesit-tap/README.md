# treesit-tap

Two related features for working with `thing-at-point` on top of
Emacs 30+'s built-in tree-sitter:

1. **Bridge** — a `bounds-of-thing-at-point` provider for any
   `treesit-thing-settings` entry. Register thing predicates per
   language (function, class, call, loop, ...) and everything that
   calls `bounds-of-thing-at-point` transparently gets AST-accurate
   bounds in treesit buffers. Per-language extension table ships
   minimal defaults for python / typescript / tsx.

2. **Current-thing nav** — a per-buffer `treesit-tap-current-thing`
   variable and commands (`treesit-tap-next` / `-prev` / `-beg` /
   `-end` / `-pulse` / `-select` / `-comment`) that operate on it.
   `treesit-tap-set-local` switches the current thing with an optional
   `consult--read` preview that highlights an instance of each
   candidate in the buffer.

## Quick start

```elisp
(use-package treesit-tap
  :ensure t
  :config (treesit-tap-setup))

;; Optional: embark integration (require to enable; mirrors
;; embark-consult / embark-org convention).
(use-package treesit-tap-embark
  :ensure treesit-tap
  :after embark)
```

Bind the nav commands to your taste:

```elisp
(global-set-key (kbd "s-j") #'treesit-tap-next)
(global-set-key (kbd "s-k") #'treesit-tap-prev)
(global-set-key (kbd "s-h") #'treesit-tap-beg)
(global-set-key (kbd "s-l") #'treesit-tap-end)
(global-set-key (kbd "s-x t") #'treesit-tap-set-local)
```

## Install (in-tree, before MELPA)

```elisp
(use-package treesit-tap
  :ensure nil
  :load-path "path/to/treesit-tap"
  :config (treesit-tap-setup))
```

## Bridge: how it works

`treesit-tap-mode` installs a `bounds-of-thing-at-point` provider for
every symbol in `treesit-tap-bridged-things` (defaults cover defun,
sexp, list, sentence, function, class, method, loop, conditional,
decorator, call, parameter, argument_list, str-lit, statement, ...).

A symbol becomes navigable when SOME language defines it in
`treesit-thing-settings`. The shipped `treesit-tap-language-extras`
table extends `treesit-thing-settings` for python / typescript / tsx
automatically on `after-change-major-mode-hook` — so you get
`(bounds-of-thing-at-point 'function)` working in a python buffer
out of the box.

Extending to a new language is a one-liner:

```elisp
(push '(rust
        (function "\\`function_item\\'")
        (class "\\`impl_item\\'")
        (call "\\`call_expression\\'"))
      treesit-tap-language-extras)
```

## Current-thing nav: how it works

`treesit-tap-current-thing` is buffer-local. `treesit-tap-set-local`
prompts (with `consult--read` preview if consult is loaded — moving
through candidates highlights an instance in the buffer so you can
see what each thing matches) and updates the value. Then:

- `treesit-tap-next` / `-prev` step by one instance
- `treesit-tap-beg` / `-end` jump to the bounds of the enclosing one
- `treesit-tap-pulse` flashes the current instance
- `treesit-tap-select` activates the region over it
- `treesit-tap-comment` toggles comment on it

Navigation is dispatched through `treesit-navigate-thing` in treesit
buffers (AST-accurate), falling back to `forward-thing` elsewhere.

## Embark integration

Loading `treesit-tap-embark` installs a target finder that walks every
tree-sitter ancestor at point and surfaces each one whose node-type
is in `treesit-tap-embark-types`. So `embark-act` inside a function
offers: `ts-call`, `ts-argument_list`, `ts-function_definition`,
... innermost first.

Three keymaps wire useful actions:

| Target type | Map | Actions |
|---|---|---|
| `ts-function_definition` &c. | `embark-defun-map` (from embark) | `e` eval, `n` narrow, `m` mark |
| `ts-string` / `ts-string_literal` | `treesit-tap-embark-string-map` | `u` browse-url, `f` find-file, `w` kill-new |
| `ts-call` / `ts-call_expression` | `treesit-tap-embark-call-map` | `d` find-def, `r` find-refs, `w` kill-new |

## Customization

| Variable | Purpose |
|---|---|
| `treesit-tap-bridged-things` | Things bridged to treesit-thing-settings |
| `treesit-tap-language-extras` | Per-language thing → node-type map |
| `treesit-tap-things` | Candidates offered by `treesit-tap-set-local` |
| `treesit-tap-default-thing` | Default `treesit-tap-current-thing` |
| `treesit-tap-embark-types` | AST node types exposed as embark targets |

## Soft dependencies

`treesit-tap` itself depends only on Emacs 30.1. Optional integrations
fire when their packages are loaded:

- `consult` — preview UI in `treesit-tap-set-local`
- `focus` — mirror current-thing into `focus-current-thing`
- `embark` — required by the companion `treesit-tap-embark` file

## Why "tap"?

`thing-at-point` is the API; "tap" is the conventional Emacs
abbreviation. Naming it `treesit-thing` would have invited confusion
with the built-in `treesit-thing-settings`.

## Status

v0.1. Stable API; submit-to-MELPA candidate after dogfooding.
