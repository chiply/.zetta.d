# Type Bridges: thing-at-point, embark, tree-sitter

How "types of things at point" are sourced across `thing-at-point`,
`embark`, and `tree-sitter`, and how to add a new type so it flows
through all three.

## TL;DR

There are four type-sourcing paths flowing into one dispatcher
(`embark`). Pick the path that matches the kind of type you want, then
read the matching scenario below.

| Type lives as… | Use Scenario |
|---|---|
| regex / function on text (e.g. a custom comment block) | 1 |
| a tree-sitter AST node you want navigable and selectable | 2 |
| a tree-sitter AST node you only want as an embark action target | 3 |

## Architecture

```
   How the type is defined                   What it becomes

  symbol-property mechanism          ──┐
  (put 'block 'bounds-of-thing-at-point …)│
  (put 'block 'forward-op …)             │
   ── used by tap-block.el / tap.el      │
                                         ├─►  bounds-of-thing-at-point
  provider-alist mechanism               │     forward-thing
  (setf (alist-get 'X                    │     beginning-of-thing
        bounds-of-thing-at-point-        │     end-of-thing
        provider-alist) …)               │
                                         │
  treesit-thing-settings                 │
  (function "\\`function_definition\\'") ─┘
   ── consumed by Bridge A in tap.el
      gated on `treesit-thing-defined-p`

                                       Then to embark:

   thing-at-point thing  ──Bridge B──►  embark-target-finders
                                        (target type = <thing>)

   raw treesit node type ──Bridge C──►  embark-target-finders
                                        (target type = ts-<node>)
```

The three thing-at-point sources are equivalent at the *consumer* end:
`bounds-of-thing-at-point` does not care how a type was registered.
They differ in ergonomics for different kinds of types.

The two embark paths are also equivalent at the consumer end: both
produce dotted `(TYPE TARGET START . END)` targets that `embark-act`
cycles through.

## Where each piece lives

| Concept | File |
|---|---|
| Bridge A bounds providers (treesit → thing-at-point) | `modules/completion/tap.el` |
| Bridge A navigation helper (`zetta-tap-forward-thing`) | `modules/completion/tap.el` |
| Bridged thing symbols list (`zetta-treesit-bridged-things`) | `modules/completion/tap.el` |
| Per-language thing extras table (`zetta-treesit-language-extras`) | `modules/lang/treesit.el` |
| Generic hook applying the extras | `modules/lang/treesit.el` |
| Bridge B factory (`zetta-embark-deftap-finder`) | `modules/completion/embark.el` |
| Bridge C finder + node-type list | `modules/completion/embark.el` |
| Example user-defined things (`block`, `brick`) | `modules/completion/tap-block.el`, `tap.el` |

## Scenario 1 — text- or regex-defined thing

Use when your type is text-shaped or regex-recognizable (custom
comment block, fold boundary, doc-string-style marker). Nothing to do
with the AST.

```elisp
;; in some .el file
(defun my-thing-bounds ()
  "Return (BEG . END) of my-thing at point, or nil."
  …)

(defun my-thing-forward (n)
  "Move N my-things forward (negative for back)."
  …)

(put 'my-thing 'bounds-of-thing-at-point #'my-thing-bounds)
(put 'my-thing 'forward-op             #'my-thing-forward)
```

Then in `modules/completion/embark.el`:

```elisp
(zetta-embark-deftap-finder my-thing)
```

That is the whole integration. `(thing-at-point 'my-thing)`,
`(bounds-of-thing-at-point 'my-thing)`, `s-j` / `s-k` with
`zetta-tap-current-thing` set to `'my-thing`, and `C-.` action menus
all work.

The existing `block` (defined in `modules/completion/tap-block.el:104`)
and `brick` (defined in `modules/completion/tap.el:237`) use exactly
this pattern. Both are registered with embark via Bridge B in
`modules/completion/embark.el`.

## Scenario 2 — tree-sitter AST node usable everywhere

Use when the type is a tree-sitter construct you want to navigate,
select, *and* dispatch actions on (function, class, parameter, loop).

### Step 1 — pick a thing symbol

It **must not collide with the name of a built-in function**.
`treesit-node-match-p` (a C function) tries to call a symbol as a
predicate before consulting `treesit-thing-settings`, so symbols like
`string` or `list` (when newly added) crash with a `characterp` error.

Check with `(functionp 'your-symbol)` — must be `nil`. If it is `t`,
pick a different name (e.g. `str-lit` instead of `string`).

### Step 2 — add to the bridged list

In `modules/completion/tap.el`, add the symbol to
`zetta-treesit-bridged-things`. Pushing here is free — the symbol
becomes active only once some language defines it.

### Step 3 — define it per language

In `modules/lang/treesit.el`, add a regex entry under each language's
section of `zetta-treesit-language-extras`. Regexes should be anchored
with `\\` `` ` `` (regex beginning-of-string) and `\\'` (regex end-of-string):

```elisp
;; under python
(return-stmt "\\`return_statement\\'")

;; under typescript / tsx
(return-stmt "\\`return_statement\\'")
```

### Step 4 — register an embark target finder

In `modules/completion/embark.el`:

```elisp
(zetta-embark-deftap-finder return-stmt)
```

Optionally bind a keymap:

```elisp
(defvar-keymap embark-return-stmt-map
  :parent embark-general-map
  "k" #'kill-region
  "n" #'narrow-to-region)
(setf (alist-get 'return-stmt embark-keymap-alist) 'embark-return-stmt-map)
```

The bounds provider in `tap.el` is keyed on the symbol and gates on
`treesit-thing-defined-p` per buffer-language, so once both sides
agree the bounds/navigation/embark paths all light up automatically.
No per-thing wiring code.

## Scenario 3 — AST-precise embark target only

Use when the type is a raw AST node you only want as an `embark-act`
target — you are not going to navigate it with `s-j`/`s-k`.

In `modules/completion/embark.el`:

```elisp
(add-to-list 'zetta-embark-treesit-types "return_statement")
```

Bridge C walks up from `treesit-node-at` until a node type is in
`zetta-embark-treesit-types`, then reports it as `ts-return_statement`.

Optionally bind a map:

```elisp
(setf (alist-get 'ts-return_statement embark-keymap-alist) 'my-map)
```

No thing-at-point or `treesit-thing-settings` involvement. Cheapest
path when you don't need normalization across languages.

## Which scenario when

- **Scenario 1**: text- or regex-shaped. No AST involved.
- **Scenario 2**: conceptually shared across languages (function,
  class, parameter). You want one symbol that means the same thing
  everywhere. Cost: one regex per language. Hides language-specific
  node-name variation behind a stable name.
- **Scenario 3**: language-specific and embark-only. `ts-call_expression`
  vs `ts-method_definition` etc. — distinct types you can act on
  differently. Cost: just a node-type string.

The reason Scenarios 2 and 3 both exist: **2 normalizes** across
languages (`'function` ≡ `function_definition` in python ∧
`arrow_function` in typescript ∧ `method_declaration` in go);
**3 surfaces raw types** so you can dispatch on language-specific
constructs (`ts-interface_declaration` only exists in typescript).

## Discovering tree-sitter node names

Drop a sample buffer in the target mode and harvest the type names:

```elisp
(with-current-buffer (current-buffer)
  (let ((root (treesit-buffer-root-node))
        types)
    (treesit-search-subtree root
                            (lambda (n)
                              (push (treesit-node-type n) types)
                              nil))
    (sort (delete-dups types) #'string<)))
```

Returns all node types appearing in the buffer. Useful for filling in
a new language's section of `zetta-treesit-language-extras`.

## Design notes

### Why bounds providers are global but forward navigation is direct

Bridge A registers bounds providers in
`bounds-of-thing-at-point-provider-alist` *globally* — safe because
`bounds-of-thing-at-point` treats a nil-returning provider as a miss
and falls through to legacy mechanisms.

Bridge A does **not** register `forward-thing-provider-alist`
providers. `forward-thing`'s contract is "if any provider is
registered for THING, never fall back to legacy; if no provider moves
point, jump to `(point-min)` / `(point-max)`." A registered provider
for an absent thing (e.g. `(forward-thing 'class)` in a class-less
buffer) would dump point at EOF. There is no provider-side workaround.

Forward navigation therefore goes through `zetta-tap-forward-thing`,
which calls `treesit-navigate-thing` directly — it returns nil cleanly
when there is no destination and we simply do not move.

Consequence: `(forward-thing 'function)` does **not** become treesit-
aware. `(zetta-tap-forward-thing N)` (bound to `s-j`/`s-k`) does. If
you must make bare `forward-thing` treesit-aware for a specific type,
register a buffer-local provider in the buffer's mode hook for that
one type only — and accept the limit-jump for absent things.

### Why the per-language table lives in `lang/treesit.el`

A single hook on `after-change-major-mode-hook` iterates every parser
in the current buffer, looks up its language in
`zetta-treesit-language-extras`, and appends the extras to
`treesit-thing-settings`. Adding a language is pure data — push an
`(LANG . EXTRAS)` entry and the wiring happens automatically. No
per-mode hook needed.

## Manual testing walkthrough

Use this to exercise the bridges end-to-end after changes or to
diagnose regressions. Each step is something to type/press; the
expected behaviour is what proves the bridge is wired.

A test fixture lives at `/tmp/zetta-bridge-test.py` (regenerate from
this doc if `/tmp` was cleared on reboot). Open it with
`C-x C-f /tmp/zetta-bridge-test.py` — `python-ts-mode` should
auto-activate.

### Setup checks

1. `M-:` then `(treesit-parser-list)` — should return a non-nil list.
2. `M-:` then `(memq 'zetta-treesit-apply-language-extras after-change-major-mode-hook)` — non-nil means the per-language extras hook is wired.

### Test 1 — navigate by `function` (Bridge A treesit extra)

1. `s-x t` → at prompt type `function` → `RET`
2. Move point to the top of the buffer.
3. `s-j` → cursor jumps to the start of the first function.
4. `s-j` repeatedly → walks through every function in the buffer,
   including methods inside classes.
5. `s-j` past the last function → should stay put (the
   limit-jump-fix in `zetta-tap-forward-thing`).
6. `s-k` → previous function.
7. `s-x v` (pulse) → flashes the **entire** function body, end to
   end, not just one line.

Failure mode: cursor lands mid-function or jumps to end of buffer →
the treesit extras did not load for python, or
`zetta-tap-forward-thing` is using the legacy path.

### Test 2 — navigate by `class`

1. `s-x t` → `class` → `RET`
2. `s-j` → jumps to the first class definition.
3. `s-x v` → pulses the entire class body.
4. `s-j` past the last class → stays put.

### Test 3 — navigate by `call`

1. `s-x t` → `call` → `RET`
2. `s-j` repeatedly → walks through every call expression
   (`foo(...)`, `print(...)`, `range(...)`, etc.).

### Test 4 — embark on a string literal (Bridge C)

1. Move point inside a string literal (e.g. a URL).
2. `C-.` — the embark indicator should read `Act on ts-string '"…"'`.
3. Press `u` → opens the URL in the browser (`browse-url`).
4. Cancel with `C-g`, retry, press `w` → copies the literal to the
   kill-ring.

If the indicator says `Act on str-lit '…'` instead, that is Bridge
B's path firing first. Press `C-.` again to cycle to `ts-string`.

### Test 5 — embark on a call expression

1. Point on the callee identifier of a call (e.g. `foo` in `foo(99)`).
2. `C-.` — indicator says `Act on ts-call 'foo(99)'`.
3. Press `d` → `xref-find-definitions` runs on the call site.

### Test 6 — embark on a function definition

1. Point anywhere inside a function body.
2. `C-.` — should show `Act on ts-function_definition …` or
   `Act on defun …`.
3. Press `n` → narrows to just that function.
4. `s-n` → widens back.

### Test 7 — `defun` (python stock thing, should still work)

1. `s-x t` → `defun` → `RET`
2. `s-j` / `s-k` → same walk as Test 1.

Confirms the pre-existing `defun` path is not regressed by the
extras.

### Test 8 — `statement` (generalised extra)

1. `s-x t` → `statement` → `RET`
2. `s-j` → steps through each return / if / for / while / yield /
   assignment / definition.

### Test 9 — completion UI still works (regression check)

1. `, p p` (project leader → project switch).
2. Highlight a project candidate.
3. `C-.` — indicator should say `Act on project '/path/to/project'`,
   **not** `Act on brick …` or similar.
4. Press `f` → opens find-file scoped to that project.

This is the path that broke when the `block`/`brick` finders were
not gated out of completion UIs. If `f` says "not bound to an
action", the finder guard in `zetta-embark-deftap-finder` regressed.

### Test 10 — `C-h B` survey

Inside any function, `C-h B` opens a buffer listing every embark
action available at point, grouped by target type. Useful to confirm
which keymaps are participating (`ts-call`, `ts-string`, `defun`,
etc.).

### Diagnostic one-liners

Paste any of these into `M-:`:

```elisp
(treesit-thing-defined-p 'function (treesit-language-at (point)))
;; -> regex string in a treesit buffer where `function' is defined; nil otherwise

(bounds-of-thing-at-point 'function)
;; -> (BEG . END) when point is inside a function

(thing-at-point 'str-lit t)
;; -> string text when point is inside a string literal

zetta-tap-current-thing
;; -> symbol that s-j / s-k will navigate next

(memq 'zetta-treesit-apply-language-extras after-change-major-mode-hook)
;; -> non-nil if the per-language extras hook is wired
```

## References

- [GNU Emacs Lisp Reference Manual — User-defined Things](https://www.gnu.org/software/emacs/manual/html_node/elisp/User_002ddefined-Things.html)
- [Embark manual on ELPA](https://elpa.gnu.org/devel/doc/embark.html)
- [Tree-sitter in Emacs 30 — Yuan Fu](https://archive.casouri.cc/note/2024/emacs-30-tree-sitter/)
- Emacs source: `lisp/thingatpt.el` — `forward-thing`, `bounds-of-thing-at-point`, the provider-alist machinery
- Emacs source: `lisp/treesit.el` — `treesit-thing-settings`, `treesit-navigate-thing`, `treesit-thing-at-point`
