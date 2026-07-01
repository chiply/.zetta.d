#!/usr/bin/env python3
"""Read a graph from stdin and print a dagviz "git-log" style SVG.

Used by hywiki-graph.el's `dagviz' view.  stdin format (1-based node ids):

    <n_nodes>
    <label_1>
    ...
    <label_n>
    <n_edges>
    <src> <dst>      (one per line, 1-based indices, already oriented)
"""

import re
import sys

import dagviz
import networkx as nx


def main() -> None:
    lines = iter(sys.stdin.read().splitlines())

    def nxt() -> str:
        try:
            return next(lines)
        except StopIteration:
            return ""

    n = int((nxt() or "0").strip() or 0)
    labels = [nxt() for _ in range(n)]
    m = int((nxt() or "0").strip() or 0)

    g = nx.DiGraph()
    for label in labels:
        g.add_node(label)
    for _ in range(m):
        parts = nxt().split()
        if len(parts) >= 2:
            a, b = int(parts[0]), int(parts[1])
            if 1 <= a <= n and 1 <= b <= n:
                g.add_edge(labels[a - 1], labels[b - 1])

    svg = dagviz.render_svg(g)

    # Replace the percentage width/height with explicit pixels from the
    # viewBox, so Emacs `create-image' renders it at a definite size.
    vb = re.search(r'viewBox="[\d.\-]+,[\d.\-]+,([\d.\-]+),([\d.\-]+)"', svg)
    if vb:
        w, h = float(vb.group(1)), float(vb.group(2))
        svg = svg.replace('width="100%"', f'width="{w:.0f}"', 1)
        svg = svg.replace('height="100%"', f'height="{h:.0f}"', 1)

    # Inject a solid background so dark text stays readable on any Emacs theme.
    open_end = svg.find(">", svg.find("<svg"))
    if open_end != -1:
        svg = (
            svg[: open_end + 1]
            + '<rect x="0" y="0" width="100%" height="100%" fill="#ffffff"/>'
            + svg[open_end + 1 :]
        )

    sys.stdout.write(svg)


if __name__ == "__main__":
    main()
