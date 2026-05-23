# present

CLIM-style presentation types for Emacs. Open a minibuffer that expects
a typed value (URL, file, function name, ...). Press `M-i`. Every visible
"presentation" of a matching type lights up with an avy label. Pick one;
it gets inserted into the prompt.

The model comes from the Common Lisp Interface Manager (CLIM), where
every visible piece of output carries a type and is clickable from any
input prompt that accepts that type or a supertype.

## What it does

You're at `M-x browse-url RET`. A buffer next to you has the line
`See https://anthropic.com/ for details.` Press `M-i`. The URL gets an
avy label. Pick it. The minibuffer fills with `https://anthropic.com/`.

`M-x find-file RET`. A `dired` window is showing your home directory.
Press `M-i`. Every visible filename gets a label. Pick one. The minibuffer
fills with the full path.

`M-x describe-function RET`. Your code buffer has `(message "hi")`.
Press `M-i`. `message` gets a label. Pick it. `describe-function` runs.

## Install

In-tree (as part of a larger config):

```elisp
(use-package present
  :ensure nil
  :load-path "path/to/present"
  :bind (:map minibuffer-local-map
              ("M-i"   . present-pick-avy)
              ("C-c i" . present-pick-completing-read)))
```

After MELPA release (future):

```elisp
(use-package present
  :ensure t
  :bind (:map minibuffer-local-map
              ("M-i"   . present-pick-avy)
              ("C-c i" . present-pick-completing-read)))
```

## Standalone, plays well with others

`present` has zero required dependencies beyond Emacs 29.1. It
transparently uses these packages when they happen to be loaded:

| Package      | What it adds                                            |
|--------------|---------------------------------------------------------|
| `avy`        | Single-keystroke labels on visible presentations.       |
| `embark`     | Pull-mode finders (URL, file, function, command, ...).  |
| `consult`    | Preview when picking via `completing-read`.             |
| `marginalia` | Type + source annotation on completing-read candidates. |

Without `avy` the picker falls back to home-row letter labels and
`read-char`. Without `embark` the package uses built-in regex + symbol
predicates instead — coverage is narrower but URL/email/uuid/integer/
filename/function/variable/command-name all still work.

## How the picker chooses what to look for

When you press `M-i`, `present` infers the **expected type** in this order:

1. An explicit override set by `(present-with-expected-type 'TYPE …)`
   or by `present-read` / `present-accept`.
2. `completion-metadata`'s `category` symbol mapped through
   `present-category-type-map` (the default covers `file`, `buffer`,
   `function`, `variable`, `command`, `symbol`, `url`, `email`).
3. (Optional, opt-in) keyword regex on the minibuffer prompt text, when
   `present-heuristic-prompt-detection` is non-nil.
4. Nothing — all visible presentations are offered.

The picker then scans every visible non-minibuffer window for
presentations whose type is the expected type or a subtype. Type
membership is a lattice — `url` is a subtype of `string`, so a `string`
prompt accepts `url` picks.

## Built-in types

```
string
├── url             (regex + embark target 'url)
├── file-path       (thing 'filename + embark target 'file)
│   └── existing-file  (filter: file-exists-p)
├── buffer-name     (embark target 'buffer)
├── symbol          (embark target 'identifier)
│   ├── function-name  (predicate: fboundp)
│   ├── variable-name  (predicate: boundp)
│   └── command-name   (predicate: commandp)
├── number          (regex)
│   └── integer
├── email           (regex + embark target 'email)
├── uuid            (regex)
├── line / sentence / paragraph  (thing-at-point)
```

Adding more:

```elisp
(present-deftype http-url :parent url)
(present-deftype port-number
                 :parent integer
                 :predicate (lambda (s) (let ((n (string-to-number s)))
                                          (and (>= n 0) (< n 65536)))))
```

## Picker keys

Bound in `minibuffer-local-map` by the install snippet above:

| Key     | Command                          |
|---------|----------------------------------|
| `M-i`   | `present-pick-avy`               |
| `C-c i` | `present-pick-completing-read`   |

Both pickers work outside a minibuffer too — they will simply insert
the chosen value at point in the current buffer.

## Type-aware reads (CLIM-style)

For prompts you write yourself:

```elisp
(let ((url (present-read 'url "URL: ")))
  (browse-url url))
```

For un-instrumented callers (e.g., `read-string` in third-party code):

```elisp
(present-with-expected-type 'url
  (call-some-function-that-reads-a-string))
```

The override flows through dynamic binding into the recursive minibuffer
session.

## Push-mode: declare typed presentations in output

By default `present` *finds* presentations in visible text. If you want
to *declare* them (more precise, no scanning), use text properties:

```elisp
;; Simplest — text is the value, type is 'url.
(insert (propertize "https://anthropic.com" 'present-type 'url))

;; Convenience wrapper.
(present-insert-typed "https://anthropic.com" 'url)

;; Display text differs from value (CLIM-style).
(present-insert-typed "Anthropic" 'url "https://anthropic.com")
```

Push-mode presentations are checked before regex/embark/thing scans.
They are cheap (single text-property lookup) and exact.

## Customization

| Variable                              | Purpose                                              |
|---------------------------------------|------------------------------------------------------|
| `present-types`                       | The lattice (see above for default).                 |
| `present-category-type-map`           | `completion-metadata` category → presentation type. |
| `present-heuristic-prompt-detection`  | Enable keyword-on-prompt heuristics (default off).   |
| `present-prompt-keyword-map`          | Heuristic keywords → presentation type.              |
| `present-collect-extra-fn`            | Hook for plugging in an extra collector.            |

For zetta-d's `embark` bridges, the wrapper in
`modules/completion/present.el` wires `present-collect-extra-fn` to
`zetta-embark--collect-visible-instances`, so AST-typed picks (tree-sitter
node types) work out of the box.

## Status

v0.1. Pickers, accept API, push-mode opt-in. No translators yet (so
type `url` picks only when a `url` is visible — there's no automatic
`string → url` conversion). Highlight-on-prompt overlay mode
(`present-highlight-mode`) ships off by default; turn it on to see CLIM
highlighting on every prompt.
