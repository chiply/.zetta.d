# hywiki-graph.el

A plain-text (and SVG) **graph view for GNU Hyperbole's HyWiki**, in the spirit
of Logseq's local graph.

- **Nodes** are WikiWords (HyWiki pages).
- An **edge** joins two WikiWords when one page's text mentions the other
  (undirected).
- `M-x hywiki-graph` (bound to `, G` on `launch-map`) prompts for a WikiWord and
  draws its neighbourhood. The numeric prefix sets how many link hops out to
  include — `C-u 3 M-x hywiki-graph` shows three degrees; default one.

The same neighbourhood can be rendered as any of **eight views**, plus optional
hub-pruning and a second class of HyRolo-sourced nodes.

## Keys (in the `*HyWiki Graph*` buffer)

| Key | Action |
|-----|--------|
| `1`–`9` | re-render at that many degrees from the centre |
| `v` | cycle the text view style |
| `V` | jump to any view by name (completion) |
| `s` / `S` | open the graph-fa2 / dagviz SVG view (own buffer) |
| `h` | toggle hub pruning |
| `[` / `]` | lower / raise the hub-degree threshold |
| `r` | toggle HyRolo-sourced nodes |
| `RET` / `mouse-1` | recentre on the node at point |
| `o` | open the WikiWord page at point |
| `c` | show this view's underlying graph code (DOT, spec, helper input...); the header view label is also a button for it |
| `g` | rebuild the link graph from disk and re-render |
| `?` | view catalog (what each view is + its backend) |
| `q` | quit |

## Views and their dependencies

| View | Key | What it is | Backend | Dependency |
|------|-----|-----------|---------|------------|
| **tree** | `v` | BFS spanning tree (indentation = hops) + inline cross-links | built-in | **none** |
| **matrix** | `v` | Adjacency matrix, centre first; never tangles | built-in | **none** |
| **dag** | `v` | git-log style rail diagram, per-lane colours | built-in | **none** |
| **graph** | `v` | Node-and-line box diagram | [graph-easy] | `graph-easy` (Perl) on `PATH` |
| **layered** | `v` | Sugiyama flowchart (ASCII boxes/arrows) | [dag-draw.el] | `dag-draw` (elpaca) + `dash`, `ht` |
| **asciidag** | `v` | Sugiyama boxes, optional ANSI edge colours | [ascii-dag] (Rust) | `cargo` build of `ascii-dag-cli/` |
| **svg** | `s` | Force-directed inline SVG image (animated) | [graph-fa2] | `graph-fa2` (elpaca) |
| **dagviz** | `S` | git-log style as an inline SVG image | [dagviz] (Python) | `python3` venv in `dagviz-cli/` |

The three built-in views and the **tree** fallback always work. Each optional
backend is **soft-required**: if it is not installed, that view is omitted from
the `v` cycle / `V` picker, and `?` flags it as unavailable. Views that draw
boxes (`graph`, `layered`, `asciidag`) fall back to the **tree** past an edge
cap, since dense neighbourhoods tangle.

[graph-easy]: https://metacpan.org/pod/Graph::Easy
[dag-draw.el]: https://codeberg.org/Trevoke/dag-draw.el
[ascii-dag]: https://github.com/AshutoshMahala/ascii-dag
[graph-fa2]: https://github.com/elij/graph-fa2
[dagviz]: https://wimyedema.github.io/dagviz/

### Installing the optional backends

```sh
# graph-easy (Perl) — for the `graph` view
brew install cpanminus && cpanm --local-lib=~/perl5 Graph::Easy

# ascii-dag (Rust) — for the `asciidag` view
cd ascii-dag-cli && cargo build --release

# dagviz (Python) — for the `dagviz` view
cd dagviz-cli && python3 -m venv .venv && .venv/bin/pip install dagviz networkx
```

`dag-draw` and `graph-fa2` install via elpaca (recipes are in the module
`modules/app/hywiki-graph.el`). The Rust `target/` and Python `.venv/` are
git-ignored, so they are rebuilt per machine.

## HyRolo-sourced nodes (`r`)

Pressing `r` adds a **second class of nodes**: each file in `hyrolo-file-list`
that mentions WikiWords becomes a (non-WikiWord) node linked to those WikiWords
— the same mention relationship, a new node set. Rolo nodes render in a
distinct italic face and the header shows `+rolo`. This affects the text views;
the SVG views stay WikiWord-only.

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
