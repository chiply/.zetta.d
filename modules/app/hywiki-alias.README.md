# hywiki-alias

Highlight and follow **case- and space-variants of your HyWikiWords** without
typing any aliases. Derived automatically from your existing HyWiki pages.

A page named `DataModelTesting` is split at its CamelCase boundaries
(`Data | Model | Testing`). The mode then highlights any case-insensitive
occurrence with optional single spaces at those boundaries and makes the Action
Key (`M-RET`) on it jump to the page — exactly as on the real WikiWord:

| Text in a buffer      | Highlighted? | Action Key jumps to |
|-----------------------|:------------:|---------------------|
| `DataModelTesting`    | (HyWiki does it) | `DataModelTesting` |
| `Data Model Testing`  | ✅ (this mode) | `DataModelTesting` |
| `data model testing`  | ✅ | `DataModelTesting` |
| `DaTa moDel TESTING`  | ✅ | `DataModelTesting` |

Nothing to maintain: the alias set is rebuilt from `hywiki-get-wikiword-list`
and refreshed whenever a page is added.

## Usage

Enabled automatically once HyWiki loads (a `with-eval-after-load` at the bottom
of the module turns the global mode on). Toggle it off — or back on — any time:

```
M-x zetta-hywiki-alias-mode
```

### Options

| Variable | Default | Meaning |
|---|---|---|
| `zetta-hywiki-alias-min-segments` | `1` | Minimum CamelCase segments to alias. `1` aliases every page, including single-word ones like `Emacs` (so `emacs` highlights and activates). Set `2` to skip single-word pages, whose case-insensitive match tends to light up prose. |
| `zetta-hywiki-alias-min-length` | `1` | Minimum WikiWord length to alias. `1` imposes no real floor; raise it to drop very short, prose-prone names. |
| `zetta-hywiki-alias-deny-list` | `nil` | WikiWords that should never get a derived alias (e.g. a page named after a common word or phrase). |

## How it works (thin, reversible layer)

- **Derivation** — split each WikiWord at CamelCase boundaries (acronym-aware:
  `HTMLParser` → `HTML | Parser`); build a case-insensitive, word-bounded
  regexp `Data ?Model ?Testing` and an index `datamodeltesting → DataModelTesting`.
- **Highlight** — a `post-command-hook` driver re-scans the visible window
  region (only when the buffer changed or scrolled, so it stays cheap) and
  applies overlays in a face that *inherits* `hywiki-word-face`: visually
  identical, but a distinct object so HyWiki's own face-based dehighlight passes
  don't clear it. The exact WikiWord form is left to HyWiki where HyWiki
  highlights it, but highlighted here too in buffers HyWiki doesn't manage
  (e.g. eww, where its buffer-local highlighter never runs) — so the real word
  is never left dark while its aliases light up.
- **Activate** — an `:around` advice on `hywiki-word-at` returns the canonical
  WikiWord when point is on an alias overlay; the entire HyWiki display chain
  (`hywiki-referent-exists-p` → `link-to-wikiword`) then works unchanged, so
  both the `hywiki-word` and `hywiki-existing-word` implicit buttons activate.

Disabling the mode removes both advices and every overlay — no residue.

## ⚠️ What this does NOT do — the missing ~20%

This is an **editing-time convenience**: highlighting + Action-Key jump *inside
your Emacs*. Aliases live only in this overlay/advice layer — they never enter
HyWiki's referent hash table (`hywiki--referent-hasht`). Everything in HyWiki
that reads the *data model* or re-scans with the WikiWord regexps is therefore
blind to them:

- **Backlinks** — `hywiki-consult-backlink` searches for the WikiWord pattern.
  `Data Model Testing` will **not** show up as a backlink to the page.
- **Publishing** — HyWiki's publisher re-scans source with its own regexps to
  build links. Aliases stay **plain text** in published output (e.g. chiply.dev).
- **hywiki-graph** — the graph parses WikiWords; alias occurrences are **not
  edges**.
- **Cross-file grep / consult** — `hywiki-word-grep`, `hywiki-consult-*` search
  the WikiWord pattern and **won't find** aliases.
- **Completion & creation** — `hywiki-word-read-new`, the referent menu, and
  `[[hy:…]]` Org export don't know aliases exist.
- **Section / line suffixes** — only bare aliases; `Alias#Section` and
  `Alias:Lnum` are not recognized.
- **Refresh scope** — highlighting is limited to the visible window region
  (like lazy fontification), refreshed on `post-command-hook`; aliases off-screen
  are highlighted when scrolled into view. Overlap with a real WikiWord is
  resolved by skipping any position HyWiki has already highlighted; the exact
  WikiWord form is otherwise highlighted here too (e.g. in eww, where HyWiki's
  buffer-local highlighter never runs).

### Why it can't be more without forking HyWiki

Making aliases first-class means putting them in `hywiki--referent-hasht` so the
lookup, scan, backlink, publish and grep machinery all see them. But
`hywiki-add-referent` / `hywiki-add-page` reject any non-WikiWord key with
*"must be capitalized, all alpha"*, and matching is deliberately case-sensitive
(`case-fold-search` bound to `nil`) throughout. First-class aliases therefore
require changes to HyWiki's private internals — an upstream proposal to the
Hyperbole maintainers, not a drop-in. This module is the pragmatic 80%: the
day-to-day highlight + jump, kept entirely outside HyWiki's core.

## False positives

Case-insensitive matching turns every aliased page name into a prose magnet,
and the defaults alias **every** page — including short, single-word ones like
`Emacs`, so ordinary "emacs" lights up throughout your notes. That is the
intended trade-off here (single-word pages are wanted); to tighten it, in order
of bluntness:

- Add specific offenders to `zetta-hywiki-alias-deny-list` (surgical).
- Raise `zetta-hywiki-alias-min-length` to drop short page names.
- Set `zetta-hywiki-alias-min-segments` to `2` to skip single-word pages entirely.

If the highlighting feels too eager, those are the knobs — or just turn the
mode off; it's designed to be A/B'd against plain HyWiki.
