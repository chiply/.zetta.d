# Plan: `treesit-textobj` — minimal tree-sitter text objects

## Context

Two existing tree-sitter / evil text-object packages have proven unsuitable for this config:

- `evil-textobj-tree-sitter` ships helix/nvim query files that fail Emacs's stricter `treesit-query-compile` (anchor `.` before optional group, quantifier on string literal). Patching is per-language `.scm` file surgery, gets clobbered on package update.
- `evil-ts-obj` works on Emacs treesit but bundles structural-edit operators (drag/swap/raise/slurp/barf) that fight aerospace's `alt-*` keyspace and bring a lot of surface area the user doesn't want.

Goal: a small, focused, **MELPA-ready** package that does only one thing well — bind `vif` / `vaf` / `dif` / `daf`-style text objects for tree-sitter-recognised units (function, class, parameter, call, string, comment). No structural operators. No M-prefix bindings. Lives initially under `source/zettapkg/treesit-textobj/` so it can be developed in-place; structured so a `git subtree split` (or equivalent) can lift it cleanly into its own MELPA-bound repo later.

The name **`treesit-textobj`** (not `evil-...`) is deliberately editor-agnostic so a future minor version can add meow integration or a plain-Emacs `region-of-thing`-style helper without a rename. The initial sketch ships evil entry points only.

Critical constraint: **no dependencies on user-private config**. All per-language node-type data ships inside the package as a defcustom with portable defaults. The user's existing `zetta-treesit-language-extras` table in `modules/lang/treesit.el` informs the defaults but is not a runtime dependency.

## Architecture

### Public API

A single file `treesit-textobj.el` with:

1. **Buffer-local minor mode** `treesit-textobj-mode` — installs the bindings into `evil-inner-text-objects-map` / `evil-outer-text-objects-map` (via `evil-define-key` scoped to the mode, so they activate only where this mode is on). User adds `treesit-textobj-mode` to each language hook themselves — no global mode in v1 (keeps surface tiny, leaves activation explicit).

2. **Three defcustoms** the user can rebind:

   - **`treesit-textobj-things`** — alist mapping logical thing name → alist of `(MAJOR-MODE . LIST-OF-NODE-TYPE-STRINGS)`. Default ships entries for `function` / `class` / `parameter` / `call` / `string` / `comment` across `python-ts-mode`, `typescript-ts-mode`, `tsx-ts-mode`, `javascript-ts-mode`, `rust-ts-mode`, `c-ts-mode`, `c++-ts-mode`, `go-ts-mode`.

   - **`treesit-textobj-keys`** — alist mapping logical thing name → key string. Default: `((function . "f") (class . "c") (parameter . "g") (call . "/") (string . "q") (comment . "C"))`. All keys verified free in stock `evil-inner-text-objects-map` and `evil-outer-text-objects-map`. `g` for parameter is a weak mnemonic but it's safe (no collision with built-in evil text objects or common leaders).

   - **`treesit-textobj-inner-body-fields`** — alist `((THING . FIELD-NAME) …)`. When computing "inner" range, prefer `(treesit-node-child-by-field-name node FIELD-NAME)` if it exists; fall back to shrink-by-one for things without a body field. Default: `((function . "body") (class . "body") (call . "arguments"))`.

3. **Public functions** (for the `(autoload …)` cookies and for users wiring it themselves):

   - `treesit-textobj-mode` — the buffer-local minor mode.
   - `treesit-textobj-find-ancestor` — helper exposed so users can build their own bindings (e.g. movement) without copying internal logic.

### Internals (private, `--`-prefixed)

- `treesit-textobj--node-types-for (thing mode)` → list-of-strings or nil. Looks up the thing in `-things`; falls back through `derived-mode-parent` so derived modes inherit (e.g. an entry under `c-ts-mode` covers `c++-ts-mode` if no explicit override is present).
- `treesit-textobj--find-ancestor (thing &optional count)` → tree-sitter node or nil. Wraps `treesit-parent-until` with a predicate matching node-type ∈ types-for-thing; `count` walks `count - 1` more levels up to support `2vaf` (the second enclosing function/class).
- `treesit-textobj--inner-range (node thing)` → `(BEG . END)` or nil. Tries `--inner-body-fields`; falls back to `(node-start + 1, node-end - 1)` for things like `string` that have no body field (skip the quotes); falls back to full node otherwise.
- `treesit-textobj--outer-range (node)` → `(BEG . END)` straight from `treesit-node-start` / `treesit-node-end`.
- `treesit-textobj--define-objects ()` — runs at mode-init time. Iterates `treesit-textobj-things`, generates one inner and one outer `evil-define-text-object` form per thing, names them `treesit-textobj-inner-THING` / `-outer-THING`, binds via `evil-define-key 'operator 'treesit-textobj-mode KEY …` and same for `visual`. Keyed off `treesit-textobj-keys` so rebinding the defcustom and toggling the mode rebinds cleanly.

### Wiring (in user's config, not in package)

`modules/editor/treesit-textobj.el`:

```elisp
(use-package treesit-textobj
  :ensure nil
  :load-path "source/zettapkg/treesit-textobj"
  :after evil
  :hook ((python-ts-mode typescript-ts-mode tsx-ts-mode
          javascript-ts-mode rust-ts-mode
          c-ts-mode c++-ts-mode go-ts-mode)
         . treesit-textobj-mode))
```

zettapkg convention (`:ensure nil` + `:load-path "source/zettapkg/PKG"`) followed exactly, so the MELPA factor-out is a one-line edit (`:ensure t` and drop `:load-path`).

## Files to create

1. **`source/zettapkg/treesit-textobj/treesit-textobj.el`** — main file. ~180 lines including header and node-type defaults.

   Header (MELPA-mandatory):

   ```elisp
   ;;; treesit-textobj.el --- Tree-sitter text objects for evil -*- lexical-binding: t; -*-
   ;;
   ;; Author: Charlie Holland <charliebkr707@gmail.com>
   ;; URL: https://github.com/<TBD>/treesit-textobj
   ;; Version: 0.1.0
   ;; Package-Requires: ((emacs "30.1") (evil "1.15"))
   ;; Keywords: convenience, tools, languages
   ;;
   ;;; Commentary:
   ;;
   ;; Adds evil text objects backed by Emacs's built-in tree-sitter.
   ;; ... (couple of paragraphs of usage + customization pointer)
   ;;
   ;;; Code:
   …
   (provide 'treesit-textobj)
   ;;; treesit-textobj.el ends here
   ```

2. **`source/zettapkg/treesit-textobj/README.md`** — short. What it is, install snippet (both zettapkg-local and future MELPA forms), defcustom reference, default-keys table.

3. **`modules/editor/treesit-textobj.el`** — five-line `use-package` wrapper. Hook list lives here, not in the package — keeps the package itself language-agnostic.

## Default node-type table (shipped inside the package)

Derived from the user's `zetta-treesit-language-extras` (`modules/lang/treesit.el` lines 67–100) for python/ts/tsx, extended for js/rust/c/c++/go from common tree-sitter grammar knowledge.

| Thing | python-ts-mode | typescript-ts-mode / tsx-ts-mode | javascript-ts-mode | rust-ts-mode | c-ts-mode / c++-ts-mode | go-ts-mode |
|---|---|---|---|---|---|---|
| function | `function_definition` | `function_declaration` `arrow_function` `method_definition` `function_expression` | (same as ts) | `function_item` `closure_expression` | `function_definition` | `function_declaration` `method_declaration` |
| class | `class_definition` | `class_declaration` `interface_declaration` | `class_declaration` | `impl_item` `struct_item` `enum_item` `trait_item` | `class_specifier` `struct_specifier` | `type_declaration` |
| parameter | `parameter` `typed_parameter` `default_parameter` | `required_parameter` `optional_parameter` | (same as ts) | `parameter` `self_parameter` | `parameter_declaration` | `parameter_declaration` |
| call | `call` | `call_expression` `new_expression` | (same as ts) | `call_expression` `macro_invocation` | `call_expression` | `call_expression` |
| string | `string` | `string` `template_string` | (same as ts) | `string_literal` `raw_string_literal` | `string_literal` | `interpreted_string_literal` `raw_string_literal` |
| comment | `comment` | `comment` | `comment` | `line_comment` `block_comment` | `comment` | `comment` |

## Critical files referenced

- `/Users/charlieholland/.zetta.d/modules/lang/treesit.el` lines 67–100 — reference table inspiring the package defaults.
- `/Users/charlieholland/.zetta.d/modules/completion/tap.el` lines 347–373 — `zetta-treesit-bridged-things` taxonomy already aligned with the chosen thing names.
- `/Users/charlieholland/.zetta.d/source/zettapkg/spot4e/spot4e.el` — structural template for a local zettapkg sub-package.
- `/Users/charlieholland/.zetta.d/source/zettapkg/claude.md` — MELPA-readiness checklist (header, Eask file, CI). Revisited on factor-out, not for the in-tree sketch.

## Verification

End-to-end smoke test from a python-ts buffer with `def foo():\n    return 1`:

1. `M-x evil-mode`, then open a `.py` file and confirm `M-: (bound-and-true-p treesit-textobj-mode)` is `t`.
2. Point inside `return 1`. Press `vif`. Selection covers the body (`    return 1`). Press `daf` — whole `def foo() …` deleted.
3. In a class with two methods, point on the inner method, press `2vaf` → walks up to enclosing class.
4. Repeat in a typescript-ts buffer (`function foo(x) { return x; }`): `vif` selects body, `vaf` selects the whole declaration.
5. `vic` / `vac` for class, `viq` / `vaq` for string, `vig` / `vag` for parameter, `vi/` / `va/` for call, `viC` / `vaC` for comment.
6. `M-:` diagnostic — `(treesit-textobj--find-ancestor 'function)` returns a non-nil node when inside one, nil at top of buffer.

Manual rebinding test:

```elisp
(setf (alist-get 'function treesit-textobj-keys) "F")
(treesit-textobj-mode -1)
(treesit-textobj-mode  1)
```

→ `viF` now works, `vif` falls through to stock evil.

## Out of scope (now)

- Structural editing (drag/swap/raise/slurp/barf/extract/inject). `er/expand-region` + `tap-fold` + embark cover most uses.
- Avy / "remote" text objects across visible screen. Covered by `s-x a` / `C-;`.
- Movement (`]f`/`[f`/M-f). Covered by embark `C-j`/`C-k` nav-by-type.
- A test suite. ERT + a python sample buffer added at factor-out time, not blocking.
- meow integration. Name leaves room for it; v1 ships evil only.

## Factor-out path (for later, not now)

When ready to publish:

1. `git subtree split --prefix=source/zettapkg/treesit-textobj -b treesit-textobj-split`.
2. Push that branch to a new GitHub repo as `main`.
3. Add Eask file, GitHub Actions CI (matrix on Emacs 30.1+), and release-please config — templates exist in `source/zettapkg/claude.md`.
4. Open a MELPA recipe PR.
5. In this config, swap `modules/editor/treesit-textobj.el` to use `:ensure (:host github :repo "…")` then later `:ensure t` once on MELPA.

## Open question (decided)

- Name → **`treesit-textobj`**.
- Default keys → **`f c g / q C`** for function/class/parameter/call/string/comment.
- Activation → **per-hook only** in v1.
