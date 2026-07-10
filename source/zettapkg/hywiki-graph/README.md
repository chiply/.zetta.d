# hywiki-graph.el

A plain-text **graph view for GNU Hyperbole's HyWiki**, in the spirit of
Logseq's local graph — drawn entirely in Emacs Lisp, no external programs.

- **Nodes** are WikiWords (HyWiki pages).
- A **directed edge** `A → B` exists when page A's text mentions B.
- `M-x hywiki-graph` (bound to `, G` on `launch-map`) prompts for a WikiWord and
  draws its neighbourhood. The numeric prefix sets how many link hops out to
  include — `C-u 3 M-x hywiki-graph` shows three degrees; default one.

The neighbourhood renders as a **git-log style rail diagram** (`dag`): every
node on its own row, its label indented one level per hop from the centre, and
each edge a vertical rail in a colour-coded lane. An arrowhead marks the page
each link points to — `<`/`>` where a rail turns into a node, `^`/`v` where it
rides a lane past a crossing. Hub-pruning and an optional second class of
HyRolo-sourced nodes round it out.

## Keys (in the `*HyWiki Graph*` buffer)

| Key | Action |
|-----|--------|
| `1`–`9` | re-render at that many degrees from the centre |
| `h` | toggle hub pruning |
| `[` / `]` | lower / raise the hub-degree threshold |
| `r` | toggle HyRolo-sourced nodes |
| `RET` / `mouse-1` | recentre on the node at point |
| `o` | open the WikiWord page at point |
| `g` | rebuild the link graph from disk and re-render |
| `q` | quit |

## The rail diagram

- **Labels on the left, rails on the right** (`hywiki-graph-dag-labels-left`, the
  default), so a hub with many edges spills rails off the right rather than
  shoving its name off the page. Set to nil for the classic rails-left,
  labels-right arrangement.
- **Indentation = hop-distance** from the centre (`hywiki-graph-dag-indent`), so
  the diagram doubles as a depth outline.
- **Per-lane colours** (`hywiki-graph-dag-lane-colors`) keep crossing rails
  distinct.
- **Directional arrowheads** (`hywiki-graph-dag-arrows`, on by default) point at
  the page each link targets; mutual links get one at each end. To keep
  crossings legible, an arrowhead is only ever drawn on a clean cell.

## HyRolo-sourced nodes (`r`)

Pressing `r` adds a **second class of nodes**: each file in `hyrolo-file-list`
that mentions WikiWords becomes a (non-WikiWord) node linked to those WikiWords
— the same mention relationship, a new node set. Rolo nodes render in a
distinct italic face and the header shows `+rolo`.

## Performance

The link graph — and the optional HyRolo graph — are built by scanning files
directly, which is fast enough to feel instant even over large corpora. On a
sample run the HyRolo scan covered **1158 files / ~11 MB in 3.4 s** (cached
afterwards). The speed comes from what the scan deliberately *avoids*:

- **Raw text in, no major mode.** Each file is read with `insert-file-contents`
  into a throwaway temp buffer — no `org-mode`, no font-lock, no hooks, no
  display, no undo. This is the dominant win: activating a major mode on a file
  is easily 50–100× heavier than slurping its text, and opening hundreds of
  files via `find-file` is exactly what makes naive approaches grind. Most of
  the wall-clock here is just the file reads; the matching is nearly free.

- **One pass per file, not one per WikiWord.** Searching each file once per
  WikiWord would be `files × wordcount` searches. Instead a single
  `re-search-forward` sweep with `hywiki-word-regexp` collects *every*
  CamelCase candidate token in the file, turning the cost into `O(total text)`.

- **O(1) membership.** "Is this token a WikiWord?" is a single `gethash` against
  a hash-table page set, not a scan of the word list. Per-file results dedup
  into a hash too.

- **Native primitives.** `re-search-forward` and `gethash` run in C over an
  in-memory buffer — no Lisp-level character iteration.

- **Cached.** Both adjacencies are built once per session (or on `g`), not per
  render; re-rendering, changing degree, pruning, or switching views is
  instant.

The general lesson: in Emacs the expensive part is almost never the bytes or
the regex — it is activating modes and running hooks on buffers you only need
to *read*. Skip that and scanning a thousand files is routine.
