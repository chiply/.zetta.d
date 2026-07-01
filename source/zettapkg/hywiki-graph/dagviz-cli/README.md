# dagviz-cli

Helper for hywiki-graph.el's `dagviz` view: reads a graph on stdin and prints
a "git-log" style SVG via the [dagviz](https://wimyedema.github.io/dagviz/)
Python package.

## Setup (one-time)

The virtualenv is git-ignored; create it here:

```sh
python3 -m venv .venv
.venv/bin/pip install dagviz networkx
```

`hywiki-graph-dagviz-python` auto-locates `.venv/bin/python`. Once the venv
exists, press `S` in a `*HyWiki Graph*` buffer.

## stdin format

```
<n_nodes>
<label_1>
...
<label_n>
<n_edges>
<src> <dst>      # one per line, 1-based indices, already oriented
```
