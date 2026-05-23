# Plan: `present` — CLIM-style presentation types for Emacs

## Context

In CLIM (Common Lisp Interface Manager), every visible piece of output carries a **presentation type** (URL, pathname, integer, command-name, ...). When a command prompts for an argument of type T, the system **highlights every visible presentation whose type is a subtype of T** and lets the user click to insert that value — typed correctly, no copy/paste, no re-parsing. The same lattice powers right-click "what commands accept this?" menus and translator chains (STRING → URL where applicable).

The user's PR #13 (just merged) built **half a CLIM** for Emacs already: a thing-at-point↔embark↔treesit bridge layer, a type cycle ordered by bounds, visible-instance collection (`zetta-embark--collect-visible-instances`), and an avy-pick primitive (`zetta-embark--avy-pick-bounds`). What's missing is the **accept** side — wiring a minibuffer's expected type to those presentations and surfacing them as clickable / pickable / avy-jumpable input candidates.

Goal: a small, focused, **MELPA-ready** package `present` that supplies that accept layer. Lives initially under `source/zettapkg/present/` so it can be developed in-place; structured so a `git subtree split` lifts it cleanly into its own MELPA repo later. The package is **standalone** (works without any vompeccc dependency) but transparently delegates to embark / avy / consult / marginalia when they are present — including the existing zetta-embark bridges, wired in the user-side module wrapper.

Critical constraint: **no zetta-* symbols in the package itself**. All zetta-specific wiring goes in `modules/completion/present.el`. The package depends only on standard MELPA packages (and even those are soft deps).

## Architecture

### The four layers

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 4: Accept API           (CLIM-style typed read)      │
│    present-read, present-accept, present-with-expected-type │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: Pickers              (avy + completing-read)      │
│    present-pick-avy, present-pick-completing-read           │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: Collection           (scan visible windows)       │
│    present-collect-visible, sources in priority order:      │
│      1. push-mode text properties (cheapest)                │
│      2. embark target finders (when loaded)                 │
│      3. built-in regex / TAP finders (fallback)             │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: Type registry        (lattice + finders)          │
│    present-deftype, present-subtype-p,                      │
│    present-types (defcustom)                                │
└─────────────────────────────────────────────────────────────┘
```

Each layer is usable in isolation: a caller wanting "just give me a URL the user picked off the screen" calls Layer 4; an integrator wanting "list all presentations in this window" calls Layer 2 directly.

### Layer 1 — Type registry

A simple DAG built as an alist; subtype check walks parents.

```elisp
(defcustom present-types
  '((string                      :parent nil)
    (url                         :parent string  :embark url       :regex present--re-url)
    (file-path                   :parent string  :embark file      :thing filename)
    (existing-file               :parent file-path :predicate file-exists-p)
    (buffer-name                 :parent string  :embark buffer)
    (symbol                      :parent string  :embark identifier)
    (function-name               :parent symbol  :embark function)
    (variable-name               :parent symbol  :embark variable)
    (command-name                :parent symbol  :embark command)
    (number                      :parent string  :regex present--re-number)
    (integer                     :parent number  :regex present--re-integer)
    (line                        :parent string  :thing line)
    (sentence                    :parent string  :thing sentence)
    (paragraph                   :parent string  :thing paragraph)
    (email                       :parent string  :embark email     :thing email)
    (uuid                        :parent string                    :thing uuid)
    (heading                     :parent string  :thing orgtree))
  "Type lattice. Each entry is (TYPE . PROPS).
Props:
  :parent     — parent type symbol or nil
  :embark     — embark target type for pull-mode finding (when embark is loaded)
  :thing      — thing-at-point thing for fallback scanning
  :regex      — symbol naming a buffer-local regex finder fn (BEG . END)
  :predicate  — extra filter on extracted text
  :extractor  — fn from (BEG . END) → typed value (defaults to buffer-substring)
  :parser     — fn from string → typed value (defaults to identity)
  :inserter   — fn (PRESENTATION) → string to insert (defaults to extracted text)")

(defun present-subtype-p (sub super)
  "Return non-nil if SUB is SUPER or a descendant via :parent chain.")

(defmacro present-deftype (name &rest props)
  "Convenience macro to register / update a type in `present-types'.")
```

The type set above is the **shipping default**. Users add types with `present-deftype`. The package ships *no* tree-sitter types in the registry itself — but the zetta-side module wrapper adds them by walking `zetta-embark-treesit-types`.

### Layer 2 — Collection

```elisp
(defun present-collect-visible (&optional expected-type include-subtypes)
  "Scan all visible non-minibuffer windows for presentations.
With EXPECTED-TYPE, filter to that type. With INCLUDE-SUBTYPES (default t),
include subtypes per the `present-types' lattice.
Returns a list of plists:
  (:type TYPE :value VAL :window W :buffer B :beg N :end N :text STR)")
```

Sourcing, in priority order (each pass is opt-in / soft-failing):

1. **Push-mode text properties (cheapest).** Walk visible region with `text-property-search-forward 'present-type`. Buffers that opt in by inserting `(propertize TEXT 'present-type TYPE)` (or `'present-type '(TYPE :value VAL)` for typed values that differ from display text) get exact, zero-scan registration. This is how mu4e / magit / org could opt in later.

2. **Embark target finders (when `embark` is loaded).** For each position in the visible region (sampled at line starts for cheap pass, then refined), call each finder in `embark-target-finders`. Map result's embark-type → presentation-type via reverse lookup against `:embark` props in `present-types`. Filter by subtype.

3. **Built-in regex finders.** For each type with a `:regex` prop in `present-types`, run the regex (buffer-local matcher) over the visible region. Built-ins: url (`browse-url-button-regexp`), email, uuid, integer, number, file-path.

4. **TAP-thing fallback.** For types with `:thing` and no other source, call `present--collect-thing-instances` which scans positions in the visible region for `(bounds-of-thing-at-point thing)`. This is the slowest path; reserved for sentence / paragraph / line / orgtree.

Dedupe by `(buffer beg end)`. Sort by window order, then position. Cache per `(buffer-modified-tick)`.

### Layer 3 — Pickers

Two pickers, both work standalone:

#### `present-pick-avy` (default `M-i` in minibuffer)

```elisp
(defun present-pick-avy ()
  "Overlay avy labels on all visible presentations matching the
inferred expected type; pressing a label inserts the value."
  (interactive)
  (let* ((expected (present--detect-expected-type))
         (presentations (present-collect-visible expected))
         (candidates (mapcar (lambda (p)
                               (cons (cons (plist-get p :beg)
                                           (plist-get p :end))
                                     (plist-get p :window)))
                             presentations))
         chosen)
    (cl-letf (((symbol-value 'avy-pre-action)
               (lambda (res) (setq chosen res) nil))
              ((symbol-value 'avy-action) #'ignore))
      (avy-process candidates))
    (when chosen
      (let* ((p (present--presentation-at chosen presentations))
             (text (present--insertion-for p expected)))
        (insert text)))))
```

When `avy` is not loaded: fall back to consecutive-letter labels rendered as overlays + `read-char`. (Small built-in fallback, ~30 lines.)

#### `present-pick-completing-read` (default `C-c i` / `M-I`)

When `consult` is loaded, use `consult--read` with preview state that flashes the source location. When not, plain `completing-read`. Category: `present-target`. Marginalia gets an annotator that shows `[TYPE  buffer-name:line]` — registered iff marginalia is loaded.

Both pickers share `present--detect-expected-type` and `present-collect-visible`. The picker key is rebindable; the user can also bind one or the other to the minibuffer-local map.

#### Optional: Highlight-on-prompt

Off by default in v1 (potentially expensive). When `present-highlight-mode` is on globally, minibuffer setup overlays a `mouse-face` + click-keymap on every visible presentation whose type matches the expected type. Click → insert; ESC / minibuffer-exit → overlays removed. This is the literal CLIM "presentations light up" effect, opt-in because the overlay churn is non-trivial.

### Layer 4 — Accept API

```elisp
(defun present-read (type prompt &optional initial history default)
  "Read a value of TYPE. Like `read-string' but typed.
Adds picker keys to the minibuffer. Parses input through the type's :parser.")

(defun present-accept (type prompt &optional initial history default)
  "Alias for `present-read' using CLIM's verb. Convenience for porters.")

(defmacro present-with-expected-type (type &rest body)
  "Run BODY with `present--expected-type-override' set to TYPE.
Wraps an un-instrumented `read-string' / `read-from-minibuffer' so the
picker can know what type the prompt wants without modifying the caller.")
```

`present--detect-expected-type` cascades:
1. `present--expected-type-override` (set by `present-with-expected-type`).
2. `completion-metadata` category mapped via `present-category-type-map`.
3. Heuristic regex against `minibuffer-prompt` — only when `present-heuristic-prompt-detection` is t (default nil; heuristics are off until the user opts in).
4. `nil` — pickers still work, just show all presentations across all types with type as a marginalia annotation.

### Public API surface (autoloaded)

| Symbol | Kind | Purpose |
|---|---|---|
| `present-deftype` | macro | register / update a type |
| `present-types` | defcustom | type lattice |
| `present-subtype-p` | fn | lattice query |
| `present-collect-visible` | fn | scan visible windows |
| `present-pick-avy` | command | avy picker (minibuffer or anywhere) |
| `present-pick-completing-read` | command | completing-read picker |
| `present-read` | fn | typed minibuffer read |
| `present-accept` | fn | CLIM-verb alias |
| `present-with-expected-type` | macro | type override |
| `present-insert-typed` | fn | output-side helper for push-mode |
| `present-highlight-mode` | minor mode | opt-in highlight-on-prompt |

Private (`present--`-prefixed): internal predicates, detection, fallback avy implementation, cache, regex builders.

### Wiring (in user's config, not in package)

`modules/completion/present.el`:

```elisp
(use-package present
  :ensure nil
  :load-path "source/zettapkg/present"
  :after (vertico embark)
  :bind (:map minibuffer-local-map
         ("M-i"   . present-pick-avy)
         ("C-c i" . present-pick-completing-read))
  :config
  ;; Teach `present' about the zetta tree-sitter type set.
  (dolist (ts-type zetta-embark-treesit-types)
    (let ((sym (intern (format "ts-%s" ts-type))))
      (present-deftype sym :parent string :embark sym)))
  ;; Bridge into the existing collector when richer scanning is desired.
  (with-eval-after-load 'embark
    (setq present-collect-extra-fn
          #'zetta-embark--collect-visible-instances)))
```

zettapkg convention (`:ensure nil` + `:load-path "source/zettapkg/PKG"`) followed exactly. MELPA factor-out is a one-line edit (`:ensure t`, drop `:load-path`).

## Files to create

1. **`source/zettapkg/present/present.el`** — main file. Estimate ~450 lines including header, defcustoms, registry, three sources (push/embark/regex), two pickers, accept API, fallback avy.

   Header:

   ```elisp
   ;;; present.el --- CLIM-style presentation types for Emacs -*- lexical-binding: t; -*-
   ;;
   ;; Author: Charlie Holland <charliebkr707@gmail.com>
   ;; URL: https://github.com/<TBD>/present
   ;; Version: 0.1.0
   ;; Package-Requires: ((emacs "29.1") (compat "30.0"))
   ;; Keywords: convenience, completion, tools
   ;;
   ;;; Commentary:
   ;;
   ;; CLIM-style presentation types. Open a minibuffer prompt that expects
   ;; type T; pressing `M-i' overlays avy labels on every visible
   ;; presentation that is a subtype of T; picking a label inserts the
   ;; typed value into the prompt.
   ;;
   ;; Standalone (no required deps beyond Emacs + compat); transparently
   ;; uses embark / avy / consult / marginalia when present.
   ;;
   ;;; Code:
   ```

2. **`source/zettapkg/present/README.md`** — install snippet (zettapkg-local + MELPA forms), defcustom reference, default type table, "how to teach my package to declare presentations" (push-mode opt-in), "how to wrap my read-string call" (`present-with-expected-type`).

3. **`modules/completion/present.el`** — ~30-line wrapper. zetta-specific: bridges to `zetta-embark-treesit-types`, optional `zetta-embark--collect-visible-instances` as extra source.

## Default category map (shipped inside the package)

`present-category-type-map` translates `completion-metadata` category symbols → presentation types:

| Category | Presentation type |
|---|---|
| `file` | `file-path` |
| `buffer` | `buffer-name` |
| `symbol` / `identifier` | `symbol` |
| `function` | `function-name` |
| `variable` | `variable-name` |
| `command` | `command-name` |
| `face` | `symbol` (no separate face type in v1) |
| `url` | `url` |
| `email` | `email` |

Other categories (project-file, kill-ring, imenu, consult-grep, ...) → no mapping; picker falls back to "all types".

## Critical files referenced

- `/Users/charlieholland/.zetta.d/docs/type-bridges.md` — Bridge A/B/C/E architecture. `present` is the accept-side counterpart.
- `/Users/charlieholland/.zetta.d/modules/completion/embark.el` lines around `zetta-embark--collect-visible-instances`, `zetta-embark--avy-pick-bounds`, `zetta-embark-jump-to-type` — the workhorse routines `present` reuses as an extra collector.
- `/Users/charlieholland/.zetta.d/modules/completion/tap.el` — `zetta-tap--things` taxonomy and `zetta-treesit-bridged-things` defcustom: source of the thing names that map onto presentation types.
- `/Users/charlieholland/.zetta.d/modules/lang/treesit.el` — per-language treesit extras; tree-sitter presentation types in the zetta wrapper.
- `/Users/charlieholland/.zetta.d/source/zettapkg/treesit-textobj/treesit-textobj.el` — structural template (header, defgroup, defcustom shape, mode definition).
- `/Users/charlieholland/.zetta.d/source/zettapkg/claude.md` — MELPA-readiness checklist (revisited on factor-out).

## Verification

End-to-end smoke tests (Emacs `-Q` + manual load is fine for v1; ERT comes at factor-out):

1. **URL into URL prompt.** Open a buffer containing `https://anthropic.com`. `M-x browse-url RET`. Press `M-i`. The URL gets an avy label. Press it → minibuffer fills with `https://anthropic.com`. RET → browser opens.

2. **File into file prompt.** Open a `dired` buffer. `M-x find-file RET`. `M-i`. Every visible filename in the dired window gets a label. Pick one → minibuffer fills with the full path. (Category `file` → `file-path`, subtype-of `string`; dired filenames detected via embark `file` target.)

3. **Function into describe-function.** With `*scratch*` containing `(message ...)` and `(princ ...)`. `M-x describe-function RET`. `M-i`. `message` and `princ` get labels. Pick `princ` → minibuffer fills → describe-function runs.

4. **completing-read picker.** Same setup as test 2 but press `C-c i` instead of `M-i`. Vertico shows all visible filenames as candidates. Marginalia (if loaded) shows `[file-path  dired.el:42]`. orderless-narrow with a substring → pick.

5. **Push-mode opt-in.** In `*scratch*`: `(insert (present-insert-typed "myref" 'string))`. In any string prompt, `M-i` → "myref" is a candidate.

6. **Type override for un-instrumented prompts.** `(present-with-expected-type 'url (read-string "Site: "))`. Press `M-i` in that prompt. URLs (not just any string) light up.

7. **No vompeccc.** `emacs -Q -L source/zettapkg/present -l present.el`. Repeat test 1. Without avy: numeric labels via `read-char` fallback. Without embark: only regex-detected URLs (still works for `https://...`).

8. **Subtype check.** `(present-subtype-p 'http-url 'url)` → t. `(present-subtype-p 'url 'string)` → t. `(present-subtype-p 'integer 'string)` → t (via `number → string`). `(present-subtype-p 'integer 'url)` → nil.

## Out of scope (now)

- **Translators** (STRING → URL conversion when only STRING presentations are visible). Confirmed deferred to v2. Adds a translator registry + BFS over the translator graph + disambiguation UI when multiple paths exist.
- **Right-click menu** ("what commands accept this presentation?"). Already covered by `embark-act`. The package will not re-implement.
- **Corfu / cape integration** (in-buffer typed completion). Hook stubs only in v1; full integration in v2 if there's demand.
- **Persistent typed history.** Each accept could push the value into a type-scoped history ring. Skipped for v1; rely on `read-string`'s history if the caller supplies it.
- **Push-mode for mu4e / magit / eshell.** Package ships the `present-insert-typed` helper; instrumenting upstream output is opt-in by those packages (or by user-side overlays). Out of scope to ship instrumentation patches.
- **Test suite.** Smoke tests above; ERT added at MELPA factor-out time.

## Factor-out path (for later, not now)

Same as treesit-textobj:

1. `git subtree split --prefix=source/zettapkg/present -b present-split`.
2. Push to a new GitHub repo as `main`.
3. Add Eask, GitHub Actions CI matrix (29.1 / 29.4 / 30.x / snapshot), release-please config.
4. Open MELPA recipe PR.
5. In this config, swap `modules/completion/present.el` to `:ensure (:host github :repo "...")` then `:ensure t` once on MELPA.

## Open questions (decided)

- **Name** → **`present`** (dir + prefix).
- **Picker UX** → **both avy and completing-read**, both bound in minibuffer (`M-i` / `C-c i`).
- **Translators** → **defer to v2**.
- **Source mode** → **pull primary, push opt-in** via `'present-type` text property.

## Open questions (deferred to implementation)

- Exact default for `present-highlight-mode` — start off, opt-in. Reassess after dogfooding.
- Whether to ship a wider built-in regex set (uuid, ip-address, semver, ...). Decide as I write; ship what's free.
- Whether `present-collect-visible` returns plists or a defstruct. Lean plist for v1 (simpler), defstruct if internal access patterns warrant.
- Whether to recognise `marginalia-classify-by-prompt-keywords` as a fourth detection source. Plausible but cute; skip unless trivial.
