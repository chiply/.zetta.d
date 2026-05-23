# Plan: factor out the typed-target stack as standalone packages

> **v3.** Two review rounds done (6 agent passes total). Round 2 surfaced (a) two execution blockers, (b) UX gaps for non-zetta users, and (c) a serious challenge to the premise of factoring at all. This version folds the concrete fixes AND surfaces the strategic challenge prominently.

## TL;DR — decisions you need to make

Read [Strategic challenge: the case for stepping back](#strategic-challenge-the-case-for-stepping-back) first. The devil's-advocate review made a strong case for NOT factoring most of this code. Three live options:

1. **Proceed with full plan**: Phase 0 → Phase 1 (`treesit-tap`) → Phase 1.5 (upstream) → Phase 2 (`embark-by-type`) → Phase 3 (`tap-fold`). v3 plan covers this path.
2. **Minimal factoring**: Phase 0 only (LICENSE backfill); ship `present` + `treesit-textobj` to MELPA; keep the rest in `modules/`; write `docs/type-bridges.md` as a reference architecture essay. Reviewer #2's explicit recommendation.
3. **Middle path**: do Phase 0 + Phase 1 (`treesit-tap` is genuinely audience-useful and the smallest scope) but defer or drop `embark-by-type` and `tap-fold`. Keeps the most reusable piece, avoids the heaviest coordination burden.

The remaining open questions ([§Open questions](#open-questions-remaining-user-decisions-needed)) only matter under options 1 or 3.

## Strategic challenge: the case for stepping back

Round-2 devil's-advocate review pushed back on factoring with concrete numbers and arguments. Summarized here so the decision is informed:

**Velocity tax (concrete).** 9 of the last 29 commits in the past 60 days touched the candidate files. If those packages were already factored, those 9 commits would have become 9 cross-repo PRs, ~90 minutes of extra CI waiting, and at least 3 coordinated two-PR releases. Estimated tax: **25-40% slowdown on the most active third of the user's Emacs work.**

**Audience reality.** The intersection of (uses embark) ∩ (uses treesit aggressively) ∩ (wants typed cycle/pick UX) ∩ (won't just copy from a blog post) is tiny. No package as opinionated as `embark-by-type` exists in MELPA — which is signal that it's *too niche*, not an untapped market. `present` is the only candidate with broad appeal.

**Coupling doesn't go away — it relocates.** Six of the v2 coupling findings (#2, #5, #6, #8, #11, #12) describe couplings that survive factoring; they just turn from in-tree function calls into cross-package contracts. Harder to refactor, not easier.

**Minimal-defaults + wrapper-restores-behavior = bad MELPA UX.** A non-zetta installer downloads `embark-by-type`, enables `embark-by-type-mode`, runs a command, gets nothing. They have to read the README and reproduce ~50 lines of wrapper config to get the same behavior the in-tree zetta config has out-of-box. That's worse UX than the status quo for the audience the factoring is supposed to serve.

**Maintenance multiplication.** 3 Eask files, 3 CI matrices, 3 release-please configs, 3 CHANGELOGs, 3 issue trackers. Every cross-cutting change becomes a coordinated 3-PR dance. For a one-person config, that's ~10% of available Emacs-tinkering time vaporized into release plumbing.

**Test investment underestimated ~3×.** Plan calls for ERT smoke per package; zero tests exist today outside `present`. Realistic cost: 1-2 days/package writing, plus ongoing maintenance on every behavior change.

**Upstream-first as procrastination trap.** Phase 1.5 has no SLA. Embark's maintainer is selective; response time is 2-6 weeks if at all. Strict gating means Phase 2 stalls indefinitely.

**Reverse alternative.** A `docs/type-bridges.md` essay + blog post would reach more people with 1% of the effort. Readers cherry-pick what fits their config rather than installing a soft-dep-laden meta-package.

**Reviewer's recommendation, verbatim**: *"Step back. Ship `present` + `treesit-textobj` (with LICENSE backfill), write `docs/type-bridges.md` as a reference architecture essay, and keep the rest in `modules/`. Revisit only if a real external user files an issue asking for `embark-by-type` as a package."*

The other two round-2 reviewers (implementation feasibility, end-user discoverability) operated under the assumption that factoring is happening and surfaced concrete fixes for that path. Their findings are folded into the rest of this plan in case option 1 or 3 is chosen.

---

The remainder of this document covers **option 1 (full factoring)** in detail. If you pick option 2, only [Phase 0](#phase-0-prerequisite-backfill-license-for-existing-packages) and the existing-package status entries are relevant.

## Context

PR #14 (`present`) + the iterative work in PR #17 produced a substantial type-aware navigation / picker stack inside `modules/completion/embark.el` (now ~1300 lines) and `modules/completion/tap.el`. Most of that code is **not** zetta-specific — it's general-purpose embark + tree-sitter + thing-at-point glue.

Already factored (in `source/zettapkg/`, MELPA-ready by design):

| Package | Status |
|---|---|
| `present` | Factored, in-tree, awaiting MELPA submission. **Missing LICENSE** — backfill before submission. |
| `treesit-textobj` | Factored, in-tree, awaiting MELPA submission. **Missing LICENSE** — backfill before submission. |

Critical constraint: each factored package **must not reference any `zetta-*` symbol**. All zetta-specific defaults move into the zetta-side `use-package` wrapper as defcustom overrides.

## Inventory of factor-out candidates

| Bundle | LOC | Files | Purpose |
|---|---|---|---|
| Bridge A (treesit → thing-at-point bounds) | ~30 | `tap.el` | Make `treesit-thing-settings` provide `bounds-of-thing-at-point` |
| Bridge B (`zetta-embark-deftap-finder` macro) | ~50 | `embark.el` | Wrap any TAP thing as an embark target finder. **Pure embark, no treesit code.** |
| Bridge C (treesit nodes → embark targets) | ~80 | `embark.el` | Walks treesit ancestors, surfaces as `ts-<type>` targets |
| Bridge E + cycle UX | ~600 | `embark.el` | Nav / pick / avy / focus / narrow / select by current target type |
| Visible-instance collectors | ~150 | `embark.el` | Window-bounded enumeration |
| Cycle sort by bounds | ~40 | `embark.el` | Innermost-first target ordering |
| TAP-current state | ~150 | `tap.el` | Per-buffer "current thing" notion + nav/select/pulse |
| `tap-fold` | ~150 | `tap-fold.el` | Overlay folding |
| `avy-action-embark` | ~10 | `avy.el` | Karthik snippet — NOT package material |

## Coupling map (v3, both review rounds folded)

1. **`zetta-*` prefix everywhere.** Mechanical rename, but pervasive.

2. **Third-party module mutation of `zetta-embark-nav-type-map`.** `modules/org/org.el:167-169` does `(setf (alist-get 'org-src-block zetta-embark-nav-type-map) 'org-src-block)`. Needs either a public registration API OR coordinated wrapper updates.

3. **TAP-current has multiple non-embark consumers** — full list (v3 added `narrow.el`):
   - `modules/editor/tap-fold.el:169`
   - `modules/editor/narrow.el:61, 68` **← missed in v2**
   - `modules/core/tab-bar.el:89-91`
   - `modules/org/org.el` (keybindings)
   - `modules/app/eww.el` (keybindings)
   - `modules/ui/focus.el` (focus-current-thing mirror)
   - `modules/completion/embark.el:438, 519, 525, 550, 552` — reads + setq-local writes from inside embark functions

4. **Cross-package symbol dependency (NEW in v3, blocks v2 split).** `embark.el:438` does `(let ((zetta-tap-current-thing thing)) (zetta-tap-forward-thing n))`. After factoring, `embark-by-type` would either:
   - Hard-depend on `treesit-tap` (add to Package-Requires)
   - Move those nav functions into `treesit-tap`'s embark sub-extension (inverts plan's split)
   - Forward-declare via `(defvar treesit-tap-current-thing)` and rely on dynamic binding only when bound — fragile

   v3 decision: **`embark-by-type` Package-Requires `treesit-tap`**. The nav family genuinely uses TAP-current state; pretending otherwise is wishful.

5. **Capture infrastructure is TWO writers, NOT one.** Pre-action `:always` hook AND `:filter-return` advice on `embark--rotate`. `embark-by-type-capture-mode` must install/uninstall both. Advising private `embark--rotate` is policy-risky — upstream embark could break it in any release.

6. **Hook installation is non-idempotent in current code (NEW v3 blocker).** `embark.el:421-423` uses `(setf (alist-get :always embark-pre-action-hooks) (cons ...))`. Re-evaluating duplicates entries. There is no removal logic at all. The factored `capture-mode` toggle MUST be rewritten with proper `add-hook`/`remove-hook` semantics or explicit dedup; this is not a port — it's a redesign.

7. **Hook ordering.** Capture hook must run BEFORE refresh-highlights consumer. Documented as part of `embark-by-type-capture-priority` defcustom.

8. **Cross-file face reference.** `tap.el`'s consult preview falls back to `zetta-embark-other-instance-face`. Each package owns its own face with soft-fallback.

9. **`brick` registration is load-order coupled.** `embark.el:154` calls `(zetta-embark-deftap-finder brick)` at `:config` time; brick's TAP provider is set in `tap.el:383`. The wrapper module must own this registration and sequence load order explicitly.

10. **`focus-current-thing` integration.** Gate is `(boundp ...)`, semantically correct. Doc note: mirror is no-op when focus.el unloaded.

11. **`embark-org` is bundled INSIDE `embark`.** Not a separate MELPA dep. Gate org-link collectors via `(featurep 'embark-org)`.

12. **`ts-*` taxonomy is implicit cross-package schema.** `treesit-tap`'s embark sub-extension owns the `ts-*` entries; `embark-by-type`'s default map ships with zero `ts-*` entries.

13. **`present` wrapper update is THREE references, not one** (v3 finding): `modules/completion/present.el` collector name + treesit-types source, PLUS `source/zettapkg/present/present.el:142, 749` (docstrings), PLUS `source/zettapkg/present/README.md:174`.

14. **Hand-written embark target finders missed from macro inventory (NEW v3).** `zetta-embark-target-word-at-point` (`embark.el:175`) is hand-written, NOT generated by `deftap-finder`. Its prose+elisp gating logic moves with it as a separate function in `embark-by-type`.

15. **Embark sub-keymaps are silently public API (NEW v3).** `embark-defun-map`, `embark-ts-string-map`, `embark-ts-call-map` (`embark.el:231-236, 297-303, 307-313`) — user's live keybindings into these will silently break on rename. Add to rename inventory: `embark-by-type-defun-map`, etc.

16. **Autoload coordination (NEW v3 blocker).** `treesit-tap`'s embark sub-extension installs `ts-*` entries at LOAD time. With `;;;###autoload` only on commands, registration never fires until a command runs. Options: (a) `treesit-tap-embark-setup` autoloaded function the wrapper calls, (b) `;;;###autoload` on a `with-eval-after-load` form (rare pattern), (c) **ship as a separate file `treesit-tap-embark.el` users `require` explicitly**. v3 decision: **option (c)**, mirrors `embark-consult` pattern.

## Suggested factoring

Three new packages, phased smallest → largest.

### Package 1: `treesit-tap`

**One-liner**: turn any tree-sitter node type into a first-class `thing-at-point` thing, with optional embark surface.

**Includes**:
- `treesit-tap-bounds THING` — bounds provider that calls `treesit-thing-at-point` / `treesit-thing-defined-p` (the symbols that actually force the Emacs 30.1 floor — NOT `treesit-thing-settings`).
- `treesit-tap-extend-language LANG EXTRAS` — buffer-local appender (this is the API-drift surface).
- `treesit-tap-language-extras` — defcustom with built-in defaults.
- `treesit-tap-mode` (global minor mode) — installs the bounds bridge.
- **TAP-current sub-feature** (moved here per v2 coupling finding #3):
  - `treesit-tap-current-thing` (defvar-local)
  - `treesit-tap-set-local` — interactive setter with optional consult preview
  - `treesit-tap-forward-thing` / `-next` / `-prev` / `-beg` / `-end`
  - `treesit-tap-pulse` / `-select` / `-comment`
  - Soft mirror to `focus-current-thing` when bound
- `treesit-tap-setup` (NEW v3) — convenience function that enables `treesit-tap-mode` and sets a sensible default current thing.
- **Embark sub-extension as separate file** `treesit-tap-embark.el` (NEW v3, resolves autoload coordination blocker):
  - `treesit-tap-embark-target-node-at-point` — embark finder
  - At `require` time: adds finder to `embark-target-finders`, registers `ts-*` entries into `embark-by-type-nav-type-map` (gated by `boundp`)

**Defcustoms** (with `:type` and `:options` per discoverability review):
```elisp
(defcustom treesit-tap-language-extras
  '((python-ts-mode . ((function . "function_definition") ...)))
  "..."
  :type '(alist :key-type symbol :value-type (alist :key-type symbol :value-type sexp))
  :group 'treesit-tap)

(defcustom treesit-tap-embark-types
  '("function_definition" "call" "string")
  "Node types to surface as embark targets. Add to or replace this list.
Example: (\"function_definition\" \"call_expression\" \"if_statement\")"
  :type '(repeat string)
  :options '("function_definition" "call" "string" "class_definition" "if_statement")
  :group 'treesit-tap)
```

**Hard deps**: `((emacs "30.1"))`. **Soft deps** (documented): `embark`, `consult`, `focus`.

**LOC estimate**: 300-400.

### Package 2: `embark-by-type`

**One-liner**: turn embark into a type-aware structural navigation system.

**Public commands** (three families per round-1 API review):

*Nav family* (`embark-by-type-nav-*`): `nav-next` / `-prev` / `-beg` / `-end`. **All four guarded with `(unless embark-by-type-capture-mode (user-error "Enable embark-by-type-capture-mode first"))`** (NEW v3 per discoverability review).

*Pick family* (`embark-by-type-pick-*`): `pick-target-type` (consult+preview), `pick-target-type-key` (transient), `pick-instance`, `avy-pick-instance`.

*Act family* (`embark-by-type-act-*`): `act-focus`, `act-highlight-instances`, `act-select-as-region`, `act-narrow`. **Same capture-mode guard.**

**Public collector facade**: `embark-by-type-collect-visible TYPE THING`. Internal collectors are private.

**Capture infrastructure**:
- `embark-by-type-last-target-type` (defvar)
- `embark-by-type-last-target-bounds` (defvar)
- `embark-by-type-capture-mode` (global minor mode) — installs **both** the pre-action hook AND the `embark--rotate` advice via proper `add-hook`/`remove-hook` semantics (NEW v3; this is a redesign, not a port — see coupling finding #6)

**Bridge B macro**: `embark-by-type-deftap-finder THING [TYPE]`. Generated names: `embark-by-type-target-<thing>-at-point`.

**Hand-written finders** (NEW v3 — not macro-generated, must move explicitly): `embark-by-type-target-word-at-point` (prose+elisp gated).

**Embark sub-keymap renames** (NEW v3): `embark-by-type-defun-map`, `embark-by-type-ts-string-map`, `embark-by-type-ts-call-map`. Document in MIGRATION.md.

**Modes the user opts into**:
- `embark-by-type-sort-by-bounds-mode` — cycle-sort advice
- `embark-by-type-capture-mode` — capture infra (REQUIRED for nav/act)
- `embark-by-type-install-default-bindings` — function (not a mode) to install bindings into `embark-general-map`

**Setup convenience** (NEW v3): `embark-by-type-setup` — enables `capture-mode`, optionally `sort-by-bounds-mode`, optionally calls `install-default-bindings`. Single function for one-line user setup.

**Defcustoms** (with `:type`, `:options`, and worked examples in docstrings):
- `embark-by-type-nav-type-map` — `(alist :key-type symbol :value-type symbol)`, no `ts-*` entries default. Docstring: `"Example: ((function . defun) (class . class) (call . sexp))"`.
- `embark-by-type-symbol-target-types` — `(repeat symbol)`, default subset
- `embark-by-type-org-link-collectors` — `(alist :key-type symbol :value-type regexp)`
- `embark-by-type-other-instance-face`
- `embark-by-type-default-bindings`
- `embark-by-type-install-default-bindings-p` — boolean default nil
- `embark-by-type-capture-priority` (NEW v3) — controls hook ordering relative to consumers

**Hard deps**: `((emacs "29.1") (embark "1.0") (treesit-tap "0.1"))`. The `treesit-tap` dep is NEW in v3 — required because the nav family lex-binds `treesit-tap-current-thing` (coupling finding #4).

**Soft deps**: `avy`, `consult`, `marginalia`. `embark-org` bundled in embark, gate via `featurep`.

**LOC estimate**: 800-1000.

### Package 3: `tap-fold`

Unchanged from v2. Soft-depends on `embark-by-type-capture-mode` being on; provides clear `user-error` when invoked while mode is off.

## What NOT to factor

- `avy-action-embark` — community snippet, document in README.
- Highlight-on-cycle refresh hook — kept as sub-feature of `embark-by-type-act-highlight-instances`.

## Cross-cutting concerns

### Naming (resolved)

| Package | v1 → v2 → v3 | Reason |
|---|---|---|
| Tree-sitter bridge | `treesit-thing` → **`treesit-tap`** | Clearer purpose, no built-in collision |
| Embark extension | `embark-cycle` → **`embark-by-type`** | v1 collided with built-in `embark-cycle` |
| Folding | `tap-fold` (unchanged) | Clean |

### License (resolved)

GPL-3-or-later for all three new packages + retro-fit `present` + `treesit-textobj` (Phase 0).

### Default behavior

No package installs hooks/advices/bindings on `require`. Each ships a `*-setup` convenience function for one-line user setup. The zetta wrapper calls each `*-setup` to preserve current behavior.

### Capture-mode guards (NEW v3)

Every `embark-by-type-nav-*` and `embark-by-type-act-*` command begins with:
```elisp
(unless embark-by-type-capture-mode
  (user-error "Enable `embark-by-type-capture-mode' first"))
```
This is the discoverability fix for the silent-prerequisite UX problem.

### Migration support (NEW v3)

Each package ships `MIGRATION.md` with a `zetta-* → new-*` symbol table covering:
- `zetta-embark-*` → `embark-by-type-*` (or `treesit-tap-*` for nav vars)
- `zetta-tap-*` → `treesit-tap-*`
- Sub-keymap renames (`embark-defun-map` → `embark-by-type-defun-map`)
- Hand-written finder renames

Optional: ship `embark-by-type-compat.el` providing `defalias` for one release cycle.

### Documentation per-package

`README.md` Quick Start section MUST contain:
- One-line "what is this" elevator pitch
- For `treesit-tap`: explicit two-feature breakdown (bounds bridge + per-buffer current-thing)
- Install snippet (zettapkg form + MELPA form)
- Single one-liner `(treesit-tap-setup)` / `(embark-by-type-setup)` user calls
- For `embark-by-type`: use-case → command table (e.g. "Switch active type → `pick-target-type`"; "Jump within current type → `pick-instance`")
- Soft-dep matrix

### Test strategy

CI matrix per package: `treesit-tap` (30.1 / snapshot), `embark-by-type` (29.4 / 30.x / snapshot), `tap-fold` (29.4 / 30.x / snapshot). Ubuntu + macOS.

ERT smoke tests cover public API. Plan budgets 1-2 days/package writing time.

## Phased execution plan

### Phase 0 (prerequisite): backfill LICENSE for existing packages

Add GPL-3-or-later LICENSE + header to `source/zettapkg/present/` and `source/zettapkg/treesit-textobj/`. One commit. Independent of factoring decision — required regardless if those go to MELPA.

### Phase 1: `treesit-tap`

1. Create `source/zettapkg/treesit-tap/`.
2. Copy + rename Bridge A, Bridge C, TAP-current, language extras.
3. Strip zetta-specific defaults.
4. Write `treesit-tap-mode` and `treesit-tap-setup`.
5. Create `treesit-tap-embark.el` as separate file for the embark sub-extension (resolves autoload blocker).
6. ERT tests.
7. README + MIGRATION.md + Eask + CI (30.1 / snapshot).
8. Update consumers: `modules/lang/treesit.el`, `modules/completion/tap.el`, `modules/editor/tap-fold.el`, `modules/editor/narrow.el`, `modules/core/tab-bar.el`, `modules/org/org.el`, `modules/app/eww.el`.
9. Drop Bridge A/C and TAP-current from in-tree `embark.el`/`tap.el`.

### Phase 1.5: upstream embark issue (parallel, NOT a gate)

File issue proposing `embark-sort-targets-by-bounds` as built-in defcustom on embark. **30-day timeout**; if no response or declined, ship in `embark-by-type`. Phase 2 proceeds in parallel — sort-mode is independent of capture-mode + nav + pick + act work.

### Phase 2: `embark-by-type`

Sub-phases:
1. Pure utilities (collectors, `--assign-type-keys`).
2. **`embark-by-type-capture-mode` redesigned for clean toggle** (NEW v3 — this is the rewrite). Install/uninstall both pre-action hook AND rotate advice with proper semantics + dedup.
3. Sort advice (only if upstream declined Phase 1.5).
4. Collector dispatcher (gates org-link via `featurep`).
5. Type pickers.
6. Instance pickers.
7. Action commands + capture-mode guards.
8. Nav commands + capture-mode guards.
9. Bridge B macro.
10. Hand-written finders (word-at-point).
11. Sub-keymap renames.
12. Default-bindings installer + `embark-by-type-setup` convenience fn.
13. README + MIGRATION.md.
14. Wrapper updates: `modules/completion/embark.el` (wrapper), `modules/completion/present.el` (collector + treesit-types source), `source/zettapkg/present/present.el` (docstrings:142, 749), `source/zettapkg/present/README.md:174`, `modules/org/org.el:167-169` (consider register-mapping API).
15. Smoke test asserting post-wrapper-load keymap state.

### Phase 3: `tap-fold`

Only if external interest emerges. Straightforward port.

## Per-package factor-out checklist (v3)

- [ ] Create `source/zettapkg/<name>/` with `<name>.el`, `README.md`, **`MIGRATION.md`**, `test/<name>-test.el`, `Eask`, `.github/workflows/`, release-please config, `version.txt`, `LICENSE` (GPL-3)
- [ ] License header in main `.el` file
- [ ] Rename all `zetta-*` symbols
- [ ] **Include hand-written finders and sub-keymaps in rename inventory** (v3)
- [ ] Remove zetta-specific defaults
- [ ] Add `:type` AND `:options` to every defcustom; worked example in docstring (v3)
- [ ] `;;;###autoload` only on user-facing commands and `define-minor-mode` forms
- [ ] **For load-time registration: ship as separate file requiring explicit `require`** (v3 — autoload coordination)
- [ ] Forward-declare external symbols
- [ ] **`add-hook`/`remove-hook` semantics for any hook installation; explicit dedup** (v3)
- [ ] `package-lint-current-buffer` clean (warnings OK, errors not)
- [ ] Byte-compile clean on CI matrix
- [ ] ERT smoke test suite covering public API
- [ ] **`*-setup` convenience function** (v3)
- [ ] **`user-error` guards on commands with implicit prerequisites** (v3)
- [ ] README "Quick start" with single-call setup line
- [ ] CHANGELOG.md with initial 0.1.0 entry
- [ ] Zetta wrapper enables modes/bindings via `*-setup` to preserve pre-factor behavior
- [ ] Smoke test asserts post-wrapper bindings match pre-factor set

## Open questions (user decisions needed)

If proceeding (options 1 or 3 above):

1. **Name confirmation**: confirm `treesit-tap` and `embark-by-type`.
2. **License confirmation**: GPL-3-or-later.
3. **Phase 1.5 scope**: file upstream issue first (30-day timeout) or skip entirely and ship sort-mode in-package immediately?
4. **`org.el` registration API**: extend `embark-by-type-nav-type-map` directly OR add public `embark-by-type-register-nav-mapping` API?
5. **`treesit-tap`'s embark sub-extension**: ship as `treesit-tap-embark.el` (v3 default per autoload coordination decision) or in-package with `with-eval-after-load`?
6. **Compat layer**: ship `*-compat.el` with `defalias` for one release cycle, or rely solely on MIGRATION.md?

## Verification

After each phase: existing CI green; live-test the pre-factor behaviors documented in PR #14 / PR #17 test plans; new smoke test asserting wrapper restores prior keymap state.

## Out of scope (this plan)

- Actually publishing to MELPA (separate effort).
- Documentation site / homepage.
- API redesign (rename + extract only).
- Test coverage beyond smoke.

## Review findings incorporated

**v2 → v3 changes driven by round-2 reviews:**

*From implementation-feasibility review (blockers + concrete issues):*
- Added coupling finding #4: `embark-by-type` HARD-depends on `treesit-tap` (lex-binding at `embark.el:438`) — Package 2 deps updated.
- Added coupling finding #6: capture-mode hook installation needs redesign for clean toggle (not just port).
- Added coupling finding #13 expansion: `present/README.md:174` also needs update.
- Added coupling finding #14: hand-written finders (`-target-word-at-point`) missed from rename.
- Added coupling finding #15: embark sub-keymaps (`embark-defun-map` etc.) silently public, need explicit rename.
- Added coupling finding #16: autoload coordination — resolved by shipping embark sub-extension as separate `treesit-tap-embark.el`.
- Fixed Emacs 30.1 justification: the symbols are `treesit-thing-at-point` and `treesit-thing-defined-p`, NOT `treesit-thing-settings`.
- Restructured Phase 1.5 from gate to parallel with 30-day timeout.
- Added `modules/editor/narrow.el` to TAP-current consumer list.
- Documented private-symbol advising risk (`embark--rotate`).

*From end-user discoverability review (UX gaps):*
- Added `treesit-tap-setup` and `embark-by-type-setup` convenience functions per package.
- Added `user-error` guards on `nav-*` / `act-*` commands when capture-mode is off.
- Specified `:options` + worked docstring examples for every user-facing defcustom.
- Added `MIGRATION.md` to per-package checklist.
- Added README Quick Start template requirements (use-case table for embark-by-type, two-feature breakdown for treesit-tap).
- New open question #6: compat layer (`defalias` `*-compat.el`)?

*From devil's-advocate review (strategic challenge):*
- Added prominent "Strategic challenge: the case for stepping back" section.
- Added TL;DR with three live options (full factor / minimal / middle path).
- Underestimation flagged: test investment ~3× plan's budget.
- Velocity tax flagged: 25-40% slowdown on most active third of work.
- Reverse alternative surfaced: `docs/type-bridges.md` essay as substitute for some / all packages.

## Critical files referenced

- `/Users/charlieholland/.zetta.d/modules/completion/embark.el`
- `/Users/charlieholland/.zetta.d/modules/completion/tap.el`
- `/Users/charlieholland/.zetta.d/modules/completion/present.el`
- `/Users/charlieholland/.zetta.d/modules/editor/tap-fold.el`
- `/Users/charlieholland/.zetta.d/modules/editor/narrow.el` (NEW v3 — missed consumer)
- `/Users/charlieholland/.zetta.d/modules/lang/treesit.el`
- `/Users/charlieholland/.zetta.d/modules/org/org.el`
- `/Users/charlieholland/.zetta.d/modules/ui/focus.el`
- `/Users/charlieholland/.zetta.d/modules/core/tab-bar.el`
- `/Users/charlieholland/.zetta.d/modules/editor/avy.el`
- `/Users/charlieholland/.zetta.d/docs/type-bridges.md`
- `/Users/charlieholland/.zetta.d/source/zettapkg/CLAUDE.md`
- `/Users/charlieholland/.zetta.d/source/zettapkg/present/` (+ `README.md:174`)
- `/Users/charlieholland/.zetta.d/source/zettapkg/treesit-textobj/`
