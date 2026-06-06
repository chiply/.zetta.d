# svg-margin example providers

`examples/svg-margin-examples.el` is **not part of the package** — it is a
gallery of ready-made providers that feed the [svg-margin](README.md) gutter
from real data sources. They double as a tutorial: each one is short, and
together they exercise every technique you'd use to write your own.

A **provider** is just a function `BUFFER -> (list of indicators)`; see the
[README](README.md) for the indicator keys. The engine pulls every registered
provider on render, groups indicators by `(line, side)`, packs them into
columns, and draws one composite SVG per line/side.

## Loading & turning them on

This file is **not installed** with the package (the Eask `files` clause ships
only `svg-margin.el`), so load it from your checkout — substitute the real path
to the `examples/` directory of your clone:

```elisp
(load-file "/path/to/svg-margin/examples/svg-margin-examples.el")

(svg-margin-example-setup)          ; core set + fringe diversion + the mode
(svg-margin-example-extras-setup)   ; the five "extra" demo providers
```

Each group also has a matching `…-teardown`. `svg-margin-example-setup` enables
`svg-margin-mode`, reclaims the **left** fringe (see *Fringe diversion* below),
and picks a single VC source (git-gutter if present, else diff-hl).

## At a glance

| Provider | Source | Side | Drawn as | Prio | Setup |
|----------|--------|------|----------|:----:|-------|
| `git-gutter` | `git-gutter:diffinfos` | left | bar (green/amber) · triangle (del) | 9 | `…-git-gutter-setup` |
| `vc` | `diff-hl-changes` | left | bar / triangle | 9 | core (fallback) |
| `flycheck` | `flycheck-current-errors` | left | dot (red/amber/green) | 8 | extras |
| `todo` | buffer scan | right | dot (amber/red/purple) | 7 | core |
| `bookmarks` | `bookmark-alist` | right | ribbon (purple) | 6 | core |
| `evil-marks` | `evil-markers-alist` | left | letter glyph | 5 | core |
| `org-headings` | buffer scan | left | depth-sized rail | 4 | extras |
| `long-lines` | buffer scan | right | bar (gold) | 3 | extras |
| `symbol` | symbol at point | right | dot (blue) | 2 | extras |
| `trailing-ws` | buffer scan | right | dot (grey) | 1 | extras |

Priority sets packing order: higher numbers claim the column **nearest the
text**, so on a shared line you read outward — VC bar, then flycheck dot, then
TODO, and so on. Every side is configurable (see *Configuring sides*).

## The providers

### git-gutter — version-control hunks

- **What:** a coloured bar on every added/modified line, a triangle where a
  hunk was deleted, read from git-gutter's own `git-gutter:diffinfos`.
- **Looks:** thin vertical bar hugging the text — green = added, amber =
  modified, red triangle = deletion.
- **Why:** the canonical gutter, but now sharing the margin with everything
  else instead of monopolising it.
- **Technique — coexisting with a package that also draws.** git-gutter
  normally draws into the margin itself and would *duel* with svg-margin
  (each resets the margin width → flicker). The setup overrides
  `git-gutter:view-diff-infos` so git-gutter keeps **computing** hunks but
  **draws nothing**; svg-margin renders them. Use this pattern for any package
  that owns a margin/fringe you want to take over.

### vc — version-control hunks via diff-hl

- **What:** the same idea sourced from `diff-hl-changes` instead of git-gutter.
- **Why:** an alternative for diff-hl users. Use **one** VC provider, not both
  (both draw at priority 9 and would stack two bars per line).
- **Technique — parsing a less obvious data shape.** `diff-hl-changes` returns
  `((:working . CHANGES) …)` where each change is `(LINE INSERTS DELETES TYPE)`
  — a good reminder to read the source rather than guess the format.

### flycheck — diagnostics

- **What:** a severity-coloured dot on each line with a flycheck error.
- **Looks:** red = error, amber = warning, green = info; the message is the
  tooltip.
- **Why:** replaces the fringe error bitmaps with crisper dots that can sit
  beside VC and marks instead of fighting them for the fringe.
- **Technique — external-package integration + its refresh hook.** Reads
  `flycheck-current-errors` and refreshes on `flycheck-after-syntax-check-hook`,
  so the gutter updates exactly when new diagnostics arrive.

### todo — keyword markers

- **What:** a dot wherever `TODO`, `FIXME`, or `HACK` appears.
- **Looks:** amber (TODO), red (FIXME), purple (HACK).
- **Why:** a lightweight "things to come back to" map down the side of the file.
- **Technique — a pure buffer scan.** No dependency: `re-search-forward` over
  the buffer, emitting an indicator per match.

### bookmarks — Emacs bookmarks

- **What:** a ribbon on each line that a bookmark points to (matched by file).
- **Looks:** a purple bookmark-ribbon (a notched pennant).
- **Why:** see your bookmarks in context instead of only in a list, without the
  bookmark fringe glyph.
- **Technique — a custom shape via `svg-margin-define-shape`.** The ribbon is
  registered once as the `bookmark` shape (an `svg-polygon`), then any indicator
  can use `:shape 'bookmark`. This is the SVG analogue of
  `define-fringe-bitmap`. Refreshes on `bookmark-set` / `bookmark-delete`.

### evil-marks — evil marks

- **What:** the mark letter (`a`–`z`) drawn where the mark sits.
- **Looks:** the literal letter in the warning face.
- **Why:** a drop-in replacement for `evil-fringe-mark` that reads evil's own
  data, so it needs no fringe at all — and several marks on one line pack into
  columns instead of overwriting each other.
- **Technique — text as an indicator (`:text`) + reading another package's
  state.** Reads `evil-markers-alist` directly; refreshes via advice on
  `evil-set-marker`.

### org-headings — a structure rail

- **What:** a tick beside every Org heading, in `org-mode` buffers.
- **Looks:** a short vertical bar whose **height and colour encode the heading
  depth** — level 1 tallest, deeper levels shorter, coloured by the matching
  `org-level-N` face.
- **Why:** an at-a-glance outline rail in the margin.
- **Technique — mode-specific + a custom `:draw` with variable geometry.**
  Instead of a named shape it supplies a `:draw` lambda that closes over the
  heading level and sizes the rectangle accordingly — the "you can draw
  anything" escape hatch.

### long-lines — overlong-line warning

- **What:** a bar on every prog-mode line past
  `svg-margin-example-long-line-column` (default 80).
- **Looks:** a gold vertical bar on the right.
- **Why:** spot lines that blow past your width budget without `whitespace-mode`
  cluttering the text.
- **Technique — a pure scan with per-line measurement** (`current-column` at
  end of line).

### symbol — occurrences of the symbol at point

- **What:** a dot on every line where the symbol under the cursor also appears.
  Active **only in `prog-mode` buffers, and only for symbols of 3+ characters**
  (so short identifiers like `i`/`fn` and prose buffers stay quiet).
- **Looks:** blue dots that move with you as you navigate.
- **Why:** an instant "where else is this used" map, like a lightweight
  `highlight-symbol`, without changing the buffer text.
- **Technique — a dynamic, point-driven provider.** A `post-command-hook`
  watcher refreshes svg-margin **only when the symbol at point changes**
  (tracked in a variable), so cursor motion doesn't cause render churn.

### trailing-ws — trailing whitespace

- **What:** a small grey dot on each line ending in spaces/tabs.
- **Why:** catch stray whitespace at a glance.
- **Technique — the simplest possible scan**, included to show how little a
  provider needs to be.

## Configuring sides

Which margin a source uses is **pure configuration** — providers never hardcode
it. Every example stamps `:side` from one alist:

```elisp
(setq svg-margin-example-sides
      '((git-gutter . left) (vc . left) (evil-marks . left)
        (flycheck . left)   (org-headings . left)
        (todo . right) (bookmarks . right) (long-lines . right)
        (trailing-ws . right) (symbol . right)))
```

Flip any entry to move that source to the other margin — no code change. The
engine reserves and draws both margins independently.

`svg-margin-example-sides` is this gallery's own knob. For **third-party**
providers you didn't write, the engine offers the same control directly:
`svg-margin-provider-sides` (an alist the engine honours) and the `:side`
argument to `svg-margin-register-provider` — so you can relocate any provider
without editing it.

## Fringe diversion

`svg-margin-example-setup` reclaims only the **left** fringe
(`svg-margin-disable-fringe 'left`) — evil-fringe-mark's old home, now migrated
into the margin. Disabling a fringe is about migrating *that fringe's users*,
not about which margin side you draw in: margins and fringes are separate
regions, so right-margin indicators show fine while the **right** fringe stays
available for `yascroll` / `flycheck` / continuation arrows. Only disable a
fringe once nothing else needs it.

## Writing your own

A minimal provider and registration:

```elisp
(defun my-margin-provider (buffer)
  (with-current-buffer buffer
    (when (derived-mode-p 'prog-mode)
      (list (list :line 1 :side 'left :shape 'dot :color "#f85149"
                  :help "first line")))))

(svg-margin-register-provider 'mine #'my-margin-provider)
```

Patterns worth copying from the gallery:
- **pure scan** (`todo`, `long-lines`, `trailing-ws`) — no dependency;
- **read another package's state** (`evil-marks`, `bookmarks`, `git-gutter`);
- **custom shape** once, reused (`svg-margin-define-shape`, see `bookmarks`);
- **custom `:draw`** per indicator for variable geometry (`org-headings`);
- **dynamic refresh** keyed to a change you care about (`symbol`,
  `flycheck`) — and refresh *only* when it changes, to avoid churn;
- **take over a drawing package** by overriding its draw function and reading
  its data (`git-gutter`).

## More ideas (not yet built)

The same model fits many other per-line, sparse data sources:

- **git-blame heat** — a bar coloured by each line's commit age (recent = warm).
- **test coverage** — green/red bars for covered/uncovered lines.
- **LSP diagnostics**, **compilation errors**, **flyspell** misspellings.
- **merge-conflict** regions; **forge/PR review** comments.
- **imenu / outline** rail (like `org-headings`, for any language).
- **multiple-cursors** positions; **occur / isearch** match map.
- **debugger** breakpoints and the current execution line.
- **annotations** (annotate.el), **footnotes/links**, **registers**.
- **recently-edited heat** that fades over time.
