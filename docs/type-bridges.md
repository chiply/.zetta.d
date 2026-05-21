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
  (put 'brick 'bounds-of-thing-at-point …)│
  (put 'brick 'forward-op …)             │
   ── used by tap.el                     │
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
                                        (target type = ts-<node>;
                                         all matching ancestors)

                                       Then beyond classification:

   all bounded targets   ──Bridge D──►  zetta-embark-expand-region
   at point                             zetta-embark-contract-region
                                        (C-e / C-S-e)

   active embark target  ──Bridge E──►  zetta-embark-nav-next / prev
                                        zetta-embark-nav-beg / end
                                        (C-j / C-k / C-a / C-e)

   active embark target  ──focus──────►  zetta-embark-focus-on-type
                                        zetta-tap-set-local sync
                                        (C-f in any embark map)

   active embark target  ──highlight──►  zetta-embark-highlight-other-instances
                                        (`*' in any embark map)
                                        refreshes on every cycle

   active embark target  ──region────►  zetta-embark-select-as-region
                                        (C-v -- activate + exit)

   prompt for type ──────────────────►  zetta-embark-jump-to-type
                                        (s-x j -- top-level command)
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
| Bridge A bounds providers (treesit → thing-at-point) | [`modules/completion/tap.el`](../modules/completion/tap.el) |
| Bridge A navigation helper (`zetta-tap-forward-thing`) | [`modules/completion/tap.el`](../modules/completion/tap.el) |
| Bridged thing symbols list (`zetta-treesit-bridged-things`) | [`modules/completion/tap.el`](../modules/completion/tap.el) |
| Per-language thing extras table (`zetta-treesit-language-extras`) | [`modules/lang/treesit.el`](../modules/lang/treesit.el) |
| Generic hook applying the extras | [`modules/lang/treesit.el`](../modules/lang/treesit.el) |
| Bridge B factory (`zetta-embark-deftap-finder`) | [`modules/completion/embark.el`](../modules/completion/embark.el) |
| Bridge C finder + node-type list | [`modules/completion/embark.el`](../modules/completion/embark.el) |
| Bridge D expand-/contract-region commands | [`modules/completion/embark.el`](../modules/completion/embark.el) |
| Bridge E per-target-type navigation + type map | [`modules/completion/embark.el`](../modules/completion/embark.el) |
| Embark target cycle sort (innermost first) | [`modules/completion/embark.el`](../modules/completion/embark.el) |
| `zetta-embark-act-contract` (reverse-cycle entry) | [`modules/completion/embark.el`](../modules/completion/embark.el) |
| `C-,` single-key in-prompt back-step | [`modules/completion/embark.el`](../modules/completion/embark.el) |
| Focus integration (`zetta-embark-focus-on-type`, `embark-expression` smart-bounds thing) | [`modules/completion/embark.el`](../modules/completion/embark.el), [`modules/ui/focus.el`](../modules/ui/focus.el) |
| Focus / tap sync (`zetta-tap-set-local` mirrors to `focus-current-thing`) | [`modules/completion/tap.el`](../modules/completion/tap.el) |
| Highlight all instances of a type | [`modules/completion/embark.el`](../modules/completion/embark.el) |
| Select-as-region (`C-v`) | [`modules/completion/embark.el`](../modules/completion/embark.el) |
| Set current thing from active target (`C-t`) | [`modules/completion/embark.el`](../modules/completion/embark.el) |
| Jump-to-type prompt (`zetta-embark-jump-to-type`, `s-x j`) | [`modules/completion/embark.el`](../modules/completion/embark.el) |
| Single-space sentence boundaries (so `sentence` works in prose) | [`modules/core/prose.el`](../modules/core/prose.el) |
| Tab-bar indicator (`zetta-tab-bar-current-thing`) | [`modules/core/tab-bar.el`](../modules/core/tab-bar.el) |
| Example user-defined thing (`brick`) | [`modules/completion/tap.el`](../modules/completion/tap.el) |

## Embark prompt commands

All bound in [`embark-general-map`](../modules/completion/embark.el)
so every action keymap inherits them. Aerospace owns the `alt-*`
(`Meta`) keyspace on macOS, so every binding here uses `Ctrl` or
single chars and is verified safe across embark's built-in maps.

| Key | Command | Effect |
|---|---|---|
| `C-.` | `embark-act` | Open prompt; cycle forward through targets (innermost → outermost via size sort) |
| `C-,` | `zetta-embark-back-cycle` | Cycle backward, one step. Single key, non-toggling |
| `C-j` | `zetta-embark-nav-next` | Next instance of the current target's type. Repeatable — embark stays open on the new target |
| `C-k` | `zetta-embark-nav-prev` | Previous instance. Repeatable |
| `C-a` | `zetta-embark-nav-beg` | Goto start of current target's bounds. Repeatable |
| `C-e` | `zetta-embark-nav-end` | Goto end (lands inside bounds, not past). Repeatable |
| `C-t` | `zetta-embark-set-current-thing` | Set `zetta-tap-current-thing` to the active target's type (drives `s-j` / `s-k` from here on). Repeatable |
| `C-f` | `zetta-embark-focus-on-type` | Activate `focus-mode` on the active target — dims everything else |
| `*` | `zetta-embark-highlight-other-instances` | Overlay every OTHER instance of the type. Repeatable — embark stays open AND highlights refresh on each cycle |
| `C-v` | `zetta-embark-select-as-region` | Mark+point over the bounds, activate region, exit embark |
| `C-SPC` | `mark` *(embark built-in)* | Like `C-v` but stays in the prompt with type `region` |
| `C-l` | `zetta-embark-pick-target-type` | `consult--read` over every bounded target at point; preview paints the focused candidate's bounds in the buffer. Pick to dispatch `embark-act` filtered to that type |
| `C-o` | `zetta-embark-pick-instance` | `consult--read` over every instance of the active target's type in the buffer (document order, rotated to start from point onward). Preview moves point and paints the focused candidate. Pick to jump and re-enter `embark-act` on that target |

Outside the prompt, [`zetta-embark-jump-to-type`](../modules/completion/embark.el)
(bound to `s-x j` in the tap keymap list) prompts for a type, jumps
to the nearest instance, and opens `embark-act` there.

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

The existing `brick` thing (defined in `modules/completion/tap.el`)
uses exactly this pattern and is registered with embark via Bridge B
in `modules/completion/embark.el`.

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

Note on Bridge C ancestors: the Bridge C finder returns *every*
matching AST ancestor as a separate bounded target (innermost
first), not just the innermost. This is what feeds the `embark-act`
cycle when stepping through structural scopes (identifier → string
→ argument_list → call → function …). The default action stays on
the innermost because the cycle is sorted ascending by bounds size
(see "Cycling order" below).

## Bridge D — expand-region using embark targets

`zetta-embark-expand-region` (bound to `C-e` in normal/visual states
of `tap.el`'s curated keymap list) grows the active region to the
next-smallest bounds that strictly contains the current region (or
point). `zetta-embark-contract-region` (`C-S-e`) walks back through
a buffer-local history. `er/expand-region` itself is still available
on `C-M-e` for comparison.

Algorithm per press of `C-e`:

1. Collect bounded targets via every `embark-target-finders` entry,
   plus every treesit ancestor whose node type is in
   `zetta-embark-treesit-types` (the AST ancestor walk fills in
   intermediate structural scopes that Bridge C's finder only
   surfaces as separate targets, not as bounds-of-anything).
2. Filter to bounds that strictly contain the current region.
3. Pick the smallest; tie-break by closeness of `start` to current
   `start` (minimises visible jump).
4. Push prior region onto the history; set mark + point to the new
   bounds.

The history clears on buffer modification (`after-change-functions`
hook installed on first push).

Difference from `er/expand-region`: the "what units exist at point"
question is answered by embark's classifier stack, not a hand-curated
per-mode try-list. So Bridge D grows uniformly over every Bridge A /
B / C target without per-mode tuning -- but it lacks expand-region's
specialised inside-vs-outside-quotes / pair distinctions and its
arbitration that minimises point/mark movement. Both tools have a
role; the bindings keep them side-by-side.

## Bridge E — per-target-type navigation in the prompter

In any embark prompter, four repeatable nav keys step around inside
the active target's bounds and through other instances of the same
type. All bound in [`embark-general-map`](../modules/completion/embark.el)
so every action keymap inherits them.

| Key | Command | What it does |
|---|---|---|
| `C-j` | `zetta-embark-nav-next` | Next instance of the same type |
| `C-k` | `zetta-embark-nav-prev` | Previous instance |
| `C-a` | `zetta-embark-nav-beg` | Start of the current bounds |
| `C-e` | `zetta-embark-nav-end` | End of the current bounds (lands inside, not past — so embark's repeat re-prompts on the same target) |

All four are in `embark-repeat-actions`, so the prompt stays open
on the new target after each press — pick an action key when you
land where you want.

Wiring:

- `zetta-embark-nav-type-map` (defcustom) maps embark target types
  to thing-at-point things. Missing entries fall through to the type
  itself (works if the type is already a thing).
- An `:always` hook on `embark-pre-action-hooks` captures the
  active target's `:type` and `:bounds` into buffer-local vars
  before each action invocation. Used by every action that needs
  the current target metadata (nav, focus, highlight, set-thing,
  select-as-region).
- The nav commands read those vars, look up the thing, and call
  `zetta-tap-forward-thing`.

Effects:

- On a `ts-call` target, `C-j` jumps to the next call expression in
  the buffer.
- On a `defun` target, `C-j` jumps to the next defun.
- On a target whose type has no nav entry (e.g. `file`, `buffer`,
  `project`), the command messages and does nothing.

## Cycling order

The default `embark-act` cycle in this config walks targets
**innermost → outermost** -- a filter-return advice on
`embark--targets` sorts bounded targets by size, ascending. Targets
without bounds (minibuffer candidates, project paths, etc.) keep
their relative order at the end of the list.

So on a point inside `foo("hello")` inside `def alpha(...)`:

```
identifier "hello"    (smallest, default)
ts-string  "\"hello\""
expression "\"hello\""
ts-argument_list  ("hello")
ts-call            foo("hello")
ts-function_definition  def alpha(...)
defun               (same bounds as above)
```

`C-.` repeatedly steps to the next-larger scope. The size sort plus
Bridge C's all-ancestors finder is what makes this cycle complete.

### Reversing direction

Three options for going the other way:

1. **`C-,` (single key)** inside an active embark prompt: bound to
   `zetta-embark-back-cycle`, a marker function intercepted by an
   `:around` advice on `embark-keymap-prompter` that substitutes
   `embark-cycle` with `prefix-arg = -1`. One press = one step back.
2. **`zetta-embark-act-contract`** as a top-level entry point: opens
   `embark-act` with the cycle pre-reversed so the *default* target
   is the outermost scope. Repeated cycling then walks inward.
3. **`C-u -N <cycle-key>`** -- embark's built-in prefix-arg path
   (`negative-argument` family is handled by the keymap prompter).

The reason the first one needs special handling: bare
`negative-argument` is a *toggle* on repeated invocations
(nil → `'-` → nil → …), and the prompter does not reset `prefix-arg`
between cycle iterations, so a bare `C-,` binding to
`negative-argument` would alternate direction every other press. The
marker + advice approach forces `prefix-arg = -1` unconditionally,
and an after-advice on `embark--rotate` resets `prefix-arg` to nil
after consumption so direction is per-press rather than sticky.

## Focus-mode integration

`focus-mode` (the [focus](https://github.com/larstvei/Focus) package,
configured in [`modules/ui/focus.el`](../modules/ui/focus.el)) dims
everything except a designated thing-at-point thing at point, given
by `focus-current-thing`. Two integration points:

**Sync from `zetta-tap-set-local`** ([`tap.el`](../modules/completion/tap.el)) —
when you set the buffer's current thing via `M-x zetta-tap-set-local`
(or `s-x t`), `focus-current-thing` is mirrored in the same call.
So changing your nav thing (`s-j` / `s-k`) also retargets
focus-mode. The forward-declaration of `focus-current-thing` in
`focus.el` lets this work even before the (lazy) focus package
loads.

**Embark `C-f` action** — `zetta-embark-focus-on-type` in
[`embark.el`](../modules/completion/embark.el):

- Resolves the active embark target type via
  `zetta-embark-nav-type-map` to a thing (e.g. `ts-call` → `call`).
- Special-case for `expression`: focus uses a custom
  `embark-expression` thing whose `bounds-of-thing-at-point` calls
  embark's `embark-target-expression-at-point` (smart enclosing-form
  bounds). Plain `bounds-of-thing-at-point 'sexp` would shrink to
  the sub-sexp at point as you move inside; the smart version keeps
  the dim region stable on the enclosing form. Nav uses plain `sexp`
  separately, where `forward-sexp` is reliable.
- Sets both `zetta-tap-current-thing` (nav) and
  `focus-current-thing` (focus) to the resolved thing.
- Snaps point to bounds.start before enabling focus-mode, so the
  initial focus region matches what embark captured.

`C-f` is unbound in every embark built-in map and unaffected by
aerospace's bindings (which only take `alt-*` and `cmd-*`).

## Highlight all instances of a type

`zetta-embark-highlight-other-instances` (bound to `*` in
[`embark-general-map`](../modules/completion/embark.el)) walks the
buffer and overlays every other instance of the active target's
resolved nav-thing with `zetta-embark-other-instance-face` (light
yellow / dark amber, distinct from embark's highlight). The current
target itself is skipped.

The action is in `embark-repeat-actions`, so the prompt stays open
after `*`. Two coordinated advice keep highlights live across
cycling and clear them on exit:

- **`:filter-return` on `embark--rotate`** — `embark-cycle` is
  dispatched inline in the act loop and does NOT route through
  `embark--act`, so pre/post-action hooks never fire on a cycle.
  The advice catches the rotation, reads the new head target's
  `:type` / `:bounds`, and re-paints highlights against the new
  type. This is what makes the highlight set update as you press
  `C-.` to cycle.
- **`:around` on `embark-act`** — wraps the whole prompt session in
  `unwind-protect`. Whenever `embark-act` exits (action picked,
  `C-g`, completion), overlays are deleted and the enabled flag is
  reset. Catches every exit path, including actions that happen to
  be in `embark-repeat-actions` (where a post-action-hook would
  not reliably distinguish "still cycling" from "final action").

`M-x zetta-embark-clear-highlights` clears manually.

## Jump-to-type and select-as-region

Two more embark-integrated commands worth flagging:

- **`zetta-embark-jump-to-type`** (bound to `s-x j` via
  [`tap.el`](../modules/completion/tap.el)) — a top-level command
  (not an embark action). Prompts for a type via `consult--read`
  over the union of `zetta-embark-nav-type-map` keys/values,
  `zetta-embark-symbol-target-types`, and `zetta-tap--things`,
  filtered by `zetta-embark--jump-type-applicable-p` (drops org-*
  outside org-mode, ts-* without a treesit parser). Preview
  highlights every instance of the focused type and moves point
  to the closest; on commit, jumps and dispatches `embark-act`.
  `unwind-protect` restores point on `C-g`.

- **`zetta-embark-select-as-region`** (bound to `C-v` in
  [`embark-general-map`](../modules/completion/embark.el)) — sets
  mark at the active target's `bounds.end`, point at `bounds.start`,
  activates the region, and exits embark. The selection is
  immediately usable for any region-based command. Distinct from
  `C-SPC` (embark's built-in `mark`) which stays in the prompt with
  type `region` so you can chain another action.

## Symbol-target types (function / command / variable / …)

Embark's `embark-target-identifier-at-point` labels an elisp symbol
with one or more of `function`, `command`, `variable`, `face`,
`library`, `package`, `symbol`, `identifier` depending on what the
symbol *is* (via `embark--identifier-types`). These are labels on
the same underlying symbol target — bounds are the symbol's
bounds, not a definition's.

For these types, walking via `bounds-of-thing-at-point` / `forward-
thing` makes no sense (no such thing-at-point). The
`zetta-embark-symbol-target-types` defcustom names the set;
`zetta-embark--collect-symbols-of-embark-type` walks every identifier
in the buffer and keeps those whose embark types include the captured
type. Both `C-o` (`pick-instance`) and `s-x j` (`jump-to-type`) branch
on this list: when the type is symbol-shaped, they use the symbol
collector; otherwise they fall back to the thing/treesit walker.

So on a `function` target: `C-o` lists every callable symbol referenced
in the buffer; `s-x j` → pick `function` highlights every callable.
On a `variable` target: every variable. Etc.

A per-call memo cache in the walker makes classification cheap
(~ms on large elisp files), since the same identifiers repeat many
times. A custom `zetta-embark--cheap-identifier-types` mirrors
embark's classifier but skips the `ffap-el-mode` library probe to
keep the walk fast.

### `zetta-embark--collect-instances-of-thing` (treesit-aware)

For non-symbol types, the walker branches on
`treesit-thing-defined-p`: if the resolved thing is a defined
treesit thing for the buffer's language, it iterates via
`treesit-navigate-thing` (since `forward-thing` is a no-op for
treesit-only things). Otherwise it falls back to the
`forward-thing` loop.

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

### Why the minimal indicator instead of which-key

`embark-which-key-indicator` redraws the popup on every cycle of
`embark-act`. With Bridges B/C and the size-sort surfacing many
targets per point, repeated `C-.` presses produce visible popup
jitter as the keymap, type, and target string all change. The
minimal indicator just updates the echo area -- no popup redraw, no
visual flicker. Discoverability moves to `embark-bindings` (`C-h B`),
which opens a static buffer listing every action keymap binding for
the current target.

### Why deftap-finders gate on `(not (minibufferp))`

`zetta-embark-deftap-finder` generates target finders that call
`bounds-of-thing-at-point`. In completion UIs (the minibuffer,
`embark-collect-mode`, etc.) some bounds functions (e.g.
`brick-bounds-of-brick-at-point`) happily compute bounds against
candidate text, so the brick target would steal the default
cycle slot from the project/file/buffer target that the user
actually wants. Gating completion contexts out lets embark's own
minibuffer finders classify them correctly.

### Why finder bounds are clamped to the buffer

The generated finder clamps `(car bnds)` to `point-min` and `(cdr
bnds)` to `point-max` before calling `buffer-substring-no-properties`.
Some user-defined bounds functions (notably `brick`) compute
`(+ 1 point-max)` after `end-of-thing 'paragraph` runs to end of
buffer; without the clamp, the substring call crashes with
"Args out of range".

### Why the embark cycle is sorted innermost → outermost

A filter-return advice on `embark--targets` sorts bounded targets by
size ascending; unbounded targets retain their relative order at the
end. The default action runs on the *smallest* (most specific) target,
and repeated `embark-act` cycles outward to larger scopes -- matching
how a user usually thinks about "the thing here" (innermost first,
zoom out as needed). `zetta-embark-act-contract` flips the sort
dynamically when an outermost-first opening is wanted.

### Why `prefix-arg` is reset after every `embark--rotate`

After-advice on `embark--rotate` sets `prefix-arg` to nil once a
rotation has consumed it. Without this, `C-,` (which forces
`prefix-arg = -1`) would leave the value lingering across the
remaining cycle iterations, so subsequent `C-.` presses would also
rotate backward. One-shot prefix-arg semantics restore the
"direction is per-press" intuition.

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

This is the path that broke when the `brick` finder was not gated
out of completion UIs. If `f` says "not bound to an
action", the finder guard in `zetta-embark-deftap-finder` regressed.

### Test 10 — `C-h B` survey

Inside any function, `C-h B` opens a buffer listing every embark
action available at point, grouped by target type. Useful to confirm
which keymaps are participating (`ts-call`, `ts-string`, `defun`,
etc.).

### Test 11 — expand-region via embark (Bridge D)

1. Point inside a string literal, e.g. `"hello"` inside a call.
2. `C-e` repeatedly grows the active region:
   inner content → full string → argument list → call → function.
3. `C-S-e` walks back through the history.
4. `C-M-e` runs the classic `er/expand-region` for comparison.

Failure mode: if `C-e` does nothing or jumps too far, the
buffer's mode probably lacks treesit bridging *and* doesn't have a
useful thing-at-point provider for the relevant unit.

### Test 12 — embark cycle order is innermost → outermost

1. Point inside a string literal.
2. `C-.` (embark-act). Indicator should say `Act on identifier '…'`
   (the smallest scope -- the symbol).
3. `C-.` again (cycle) → `ts-string`.
4. `C-.` → `expression` → `ts-argument_list` → `ts-call` →
   `ts-function_definition` → `defun` → `brick`.

Each press of `C-.` reveals the next-larger structural scope.

### Test 13 — backward cycle (`C-,`) is one-shot

1. Inside an active embark-act prompt, cycle forward a few times
   with `C-.`.
2. `C-,` once → step back one scope.
3. `C-,` again → step back another scope.
4. `C-.` → forward one (direction is NOT sticky; each press is
   independent).

If `C-,` makes the cycle alternate directions rather than stepping
back, the `negative-argument` toggle bug is back -- check that
`zetta-embark-back-cycle` is bound to `C-,` in `embark-general-map`
and that the `:around` advice on `embark-keymap-prompter` is active.

### Test 14 — `zetta-embark-act-contract` as an alternative entry

1. `M-x zetta-embark-act-contract` (or your bound key) with point
   inside a string literal.
2. The prompt should open with `brick` (or whatever is *outermost*)
   as the default, not `identifier`.
3. Repeated `C-.` walks inward, opposite of the default forward cycle.

### Test 15 — `C-j` / `C-k` navigate by current target's type (Bridge E)

1. Point inside one of several functions in the buffer.
2. `C-.` (embark-act) on a function target.
3. `C-j` → point jumps to start of next function. Embark STAYS OPEN
   on the new function (the nav commands are repeatable).
4. `C-j` again → next function, prompt still open.
5. `C-k` → previous function, prompt still open.
6. Press an action key (or `C-g`) → embark exits.

Repeat for other types: on a call target, `C-j` walks calls; on a
string target, `C-j` walks strings; on a defun, `C-j` walks defuns.

### Test 16 — `C-a` / `C-e` jump to bounds start / end

1. `C-.` on a long target (e.g. a function definition).
2. `C-a` → point at the function's start. Prompt still open on the
   same function (because `C-e` lands inside bounds, not past it,
   the repeat re-prompts on the same target).
3. `C-e` → point at the function's end character.

### Test 17 — `C-t` sets current thing from active target

1. `C-.` on a `sentence` target.
2. `C-t` → echo area says `zetta-tap-current-thing = `sentence'`.
3. Exit embark, then `s-j` / `s-k` outside the prompt — now walks
   sentences (was probably `defun` before).
4. Confirm via the tab-bar indicator: it should now show `[sentence]`.

### Test 18 — `*` highlights all instances; auto-refresh on cycle

1. `C-.` on a sentence target in prose. `*` → all OTHER sentences
   in the buffer get a distinct overlay. Embark stays open.
2. `C-.` again (cycle) → if the new target is a `paragraph`, the
   overlays automatically refresh to highlight all paragraphs.
3. Press any action key (or `C-g`) → overlays clear automatically.

### Test 19 — `C-v` selects region

1. `C-.` on any bounded target.
2. `C-v` → embark exits; region is active over the captured bounds.
3. Apply any region-based command (e.g. `M-w` to copy).

### Test 20 — `C-f` focus on active target

1. `C-.` on an expression in code. `C-f` → focus-mode activates;
   the expression stays focused (smart enclosing-form bounds) even
   as you move point inside it.
2. Move point to a sibling expression — focus tracks to the new
   enclosing form.
3. `M-x focus-mode` to disable.

### Test 21 — `s-x j` jump-to-type

1. `M-x zetta-embark-jump-to-type` (or `s-x j` in the mapped keymap
   list). Pick a type at the completing-read prompt.
2. Point jumps to the nearest instance of that type. `embark-act`
   opens on it.
3. Cancel with `C-g` either at the read or the action prompt —
   point returns to its original position.

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

(lookup-key embark-general-map (kbd "C-,"))
;; -> zetta-embark-back-cycle if Bridge D's back-step is bound

(lookup-key embark-general-map (kbd "C-j"))
;; -> zetta-embark-nav-next if Bridge E's nav is bound

(zetta-embark--bounded-targets-at-point)
;; -> list of (BEG . END) bounds Bridge D would consider for expansion

(lookup-key embark-general-map (kbd "C-f"))
;; -> zetta-embark-focus-on-type if the focus action is bound

(lookup-key embark-general-map (kbd "*"))
;; -> zetta-embark-highlight-other-instances if highlight is bound

(lookup-key embark-general-map (kbd "C-v"))
;; -> zetta-embark-select-as-region if select-region is bound

zetta-embark--highlights-enabled
;; -> non-nil while the highlight overlay set is active

(memq 'zetta-embark-highlight-other-instances embark-repeat-actions)
;; -> non-nil if highlight is repeatable (prompt stays open)

(advice-member-p 'embark--rotate@zetta-refresh-highlights
                 'embark--rotate)
;; -> the :filter-return advice that refreshes highlights on cycle
```

## References

- [GNU Emacs Lisp Reference Manual — User-defined Things](https://www.gnu.org/software/emacs/manual/html_node/elisp/User_002ddefined-Things.html)
- [Embark manual on ELPA](https://elpa.gnu.org/devel/doc/embark.html)
- [Focus package on GitHub](https://github.com/larstvei/Focus)
- [Tree-sitter in Emacs 30 — Yuan Fu](https://archive.casouri.cc/note/2024/emacs-30-tree-sitter/)
- Emacs source: `lisp/thingatpt.el` — `forward-thing`, `bounds-of-thing-at-point`, the provider-alist machinery
- Emacs source: `lisp/treesit.el` — `treesit-thing-settings`, `treesit-navigate-thing`, `treesit-thing-at-point`
- Local source:
  - [`modules/completion/embark.el`](../modules/completion/embark.el) — all bridges, target-finders, embark commands
  - [`modules/completion/tap.el`](../modules/completion/tap.el) — `zetta-tap-*` nav helpers, `zetta-treesit-bridged-things`
  - [`modules/lang/treesit.el`](../modules/lang/treesit.el) — per-language thing extras and apply hook
  - [`modules/ui/focus.el`](../modules/ui/focus.el) — focus-mode integration and faces
  - [`modules/core/prose.el`](../modules/core/prose.el) — `sentence-end-double-space = nil` default
  - [`modules/core/tab-bar.el`](../modules/core/tab-bar.el) — `[<thing>]` indicator
