# hywiki-alias

Highlight and follow **variants of your HyWikiWords** — different case, spaces,
hyphens, and hand-written aliases — without leaving HyWiki. A page named
`DataModelTesting` then lights up on `Data Model Testing`, `data-model-testing`,
and anything you list in its `Aliases` section, and the Action Key on any of
them jumps to the page exactly as on the real WikiWord.

It is a thin, reversible layer over HyWiki: overlays plus a little advice. Turn
it off and you are back to plain HyWiki (see [Enabling / disabling](#enabling--disabling)).

## What gets highlighted

For a page `DataModelTesting` (with `Emacs` also a page):

| Text in a buffer       | Highlighted? | Action Key → |
|------------------------|:------------:|--------------|
| `DataModelTesting`     | HyWiki does it | `DataModelTesting` |
| `Data Model Testing`   | ✅ this mode | `DataModelTesting` |
| `data model testing`   | ✅ | `DataModelTesting` |
| `data-model-testing`   | ✅ | `DataModelTesting` |
| `DaTa moDel TESTING`    | ✅ | `DataModelTesting` |
| `emacs`, `EMACS`       | ✅ | `Emacs` |
| `emacs-foobar`         | ❌ (part of a bigger hyphenated word) | — |

There are three sources of aliases — [automatic](#automatic-aliases),
[manual](#manual-aliases--the-aliases-section), and HyWiki's own exact WikiWord
— and one rule for when they overlap: [the longest match wins](#composite-wikiwords-precedence).

## Enabling / disabling

`zetta-hywiki-alias-mode` is a global minor mode and **is the toggle** between
this module and HyWiki's native behaviour:

```
M-x zetta-hywiki-alias-mode
```

- **On** — automatic + manual aliases, hyphen variants, and composite handling.
- **Off** — plain HyWiki. Disabling removes every overlay this module added and
  **re-runs HyWiki's own highlighter in the visible windows**, so the native
  view is restored cleanly — even in buffers like eww that HyWiki never
  re-scans on its own. That makes it a true A/B: flip it and compare.

It is enabled automatically once HyWiki loads (a `with-eval-after-load` at the
bottom of the module). Bind it for quick flipping if you like:

```elisp
(keymap-global-set "C-c w" #'zetta-hywiki-alias-mode)
```

## Automatic aliases

Derived from each WikiWord's own name — nothing to maintain. Each WikiWord is
split at its CamelCase boundaries (acronym-aware: `HTMLParser` → `HTML |
Parser`), and every case-insensitive occurrence of those segments, joined
directly or by a single space or hyphen, is highlighted:

- `EmacsCompletion` → `emacs completion`, `Emacs Completion`, `emacs-completion`, …

The alias set is rebuilt from `hywiki-get-wikiword-list` on enable, whenever a
page is added, and whenever a page file is saved. Which pages get aliased is
controlled by three [options](#options) (`min-segments`, `min-length`,
`deny-list`) — the defaults alias **every** page, including single words.

## Manual aliases — the `Aliases` section

Some aliases can't be derived from the name (`corfu` for `EmacsCompletion`,
"completion framework", plurals, jargon). List them yourself: add a heading
titled **`Aliases`** (any level) to the page file and put one alias per line
beneath it, up to the next heading.

```org
#+title: EmacsCompletion

* Aliases
- completion framework
- minibuffer completion
- corfu

* Notes
...the rest of the page...
```

- Bulleted (`-` `+` `*` `1.`) or plain lines both work; blank lines and Org
  keyword/comment lines (`#…`) are ignored.
- Manual aliases highlight and activate exactly like derived ones and inherit
  the same case / space / hyphen flexibility.
- They are **always honoured** — they ignore the `min-segments` / `min-length`
  / `deny-list` filters, since you wrote them deliberately.
- **Saving the page picks up the change**: an `after-save-hook` rebuilds when
  any file under `hywiki-directory` is saved, so edit the `Aliases` section,
  `C-x C-s`, and the new aliases are live immediately.

## Hyphenation

Hyphens are treated as a segment separator, so a multi-segment WikiWord matches
its hyphenated form (`EmacsCompletion` → `emacs-completion`). But a match that
is only *part of a larger hyphenated token* is left alone, so a page `Emacs`
does **not** highlight the `emacs` inside `emacs-foobar` (or `foobar-emacs`). A
hyphen that falls *between the WikiWord's own segments* is fine — it is consumed
inside the match, not sitting at its edge.

## Composite WikiWords (precedence)

When one WikiWord is composed of others — say `Emacs`, `Completion`, and
`EmacsCompletion` are all pages — **the longest match wins**, consistently:

| Text | Highlighted as | Action Key → |
|------|----------------|--------------|
| `EmacsCompletion` | one unit | `EmacsCompletion` |
| `Emacs Completion` | one unit | `EmacsCompletion` |
| `emacs completion` | one unit | `EmacsCompletion` |
| `emacs-completion` | one unit | `EmacsCompletion` |

By default HyWiki would read the capitalized `Emacs Completion` as *two*
separate WikiWords (`Emacs` + `Completion`). This module overrides that: when a
longer composite WikiWord spans HyWiki's sub-part overlays, it removes them and
lays down the single composite, so the whole phrase highlights and activates as
one unit. The exact `EmacsCompletion` form is still left to HyWiki (its overlay
already covers the whole match).

**Caveat:** in eww and while reading, this is stable. In a *live* HyWiki page
buffer, HyWiki re-highlights on edits, so it may briefly re-split `Emacs
Completion` until the next command re-composes it — a momentary flicker on
edits, never a wrong final state.

## Options

| Variable | Default | Meaning |
|---|---|---|
| `zetta-hywiki-alias-min-segments` | `1` | Minimum CamelCase segments a page needs for a derived alias. `1` aliases every page, including single-word ones like `Emacs`. Set `2` to skip single-word pages, whose case-insensitive match tends to light up prose. (Manual aliases ignore this.) |
| `zetta-hywiki-alias-min-length` | `1` | Minimum WikiWord length for a derived alias. `1` imposes no real floor; raise it to drop short, prose-prone names. (Manual aliases ignore this.) |
| `zetta-hywiki-alias-deny-list` | `nil` | WikiWords that should never get a *derived* alias (e.g. a page named after a common word). |

## How it works (thin, reversible layer)

- **Index + regexp** — segments and manual aliases are collected into a hash
  (`datamodeltesting → DataModelTesting`) and one case-insensitive, word-bounded
  alternation regexp, sorted longest-first so a composite pre-empts its parts.
- **Highlight** — a `post-command-hook` driver re-scans the visible window
  region (only when the buffer changed or scrolled, so it stays cheap), in a
  face that *inherits* `hywiki-word-face`: visually identical, but a distinct
  object so HyWiki's own face-based dehighlight passes don't clear it.
  - The exact WikiWord form is left to HyWiki where it highlights, but drawn
    here too where HyWiki is idle (e.g. eww, whose buffer-local highlighter
    never runs), so the real word is never dark while its aliases glow.
  - On a link (an eww hyperlink or a button) the overlay keeps the WikiWord's
    text colour but takes the **link's own colour as its underline** and layers
    above HyWiki's overlay, so it reads as both a WikiWord and a link.
  - Where a composite spans HyWiki's sub-part overlays, those are removed so the
    composite wins (see [precedence](#composite-wikiwords-precedence)).
- **Activate** — an `:around` advice on `hywiki-word-at` returns the canonical
  WikiWord when point is on an alias overlay; HyWiki's whole display chain then
  works unchanged, so both the `hywiki-word` and `hywiki-existing-word` implicit
  buttons activate.
- **Refresh** — the alias set rebuilds on enable, after `hywiki-add-page` /
  `hywiki-add-referent`, and on `after-save-hook` for HyWiki page files.

Disabling the mode removes the advice, every overlay, and the hooks — no residue.

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
  are highlighted when scrolled into view.

### Why it can't be more without forking HyWiki

Making aliases first-class means putting them in `hywiki--referent-hasht` so the
lookup, scan, backlink, publish and grep machinery all see them. But
`hywiki-add-referent` / `hywiki-add-page` reject any non-WikiWord key with
*"must be capitalized, all alpha"*, and matching is deliberately case-sensitive
(`case-fold-search` bound to `nil`) throughout. First-class aliases therefore
require changes to HyWiki's private internals — an upstream proposal to the
Hyperbole maintainers, not a drop-in. This module is the pragmatic 80%: the
day-to-day highlight + jump, kept entirely outside HyWiki's core.

## Tuning false positives

Case-insensitive matching turns every aliased page name into a prose magnet,
and the defaults alias **every** page — including short, single-word ones like
`Emacs`, so ordinary "emacs" lights up throughout your notes. That is the
intended trade-off here; to tighten it, in order of bluntness:

- Add specific offenders to `zetta-hywiki-alias-deny-list` (surgical).
- Raise `zetta-hywiki-alias-min-length` to drop short page names.
- Set `zetta-hywiki-alias-min-segments` to `2` to skip single-word pages entirely.

If the highlighting ever feels too eager, those are the knobs — or just turn the
mode off; it is designed to be A/B'd against plain HyWiki.
