//! Read a graph from stdin and print an ASCII DAG rendered by the ascii-dag
//! crate.  Used by hywiki-graph.el's `ascii-dag' view.
//!
//! stdin format (1-based node ids; labels are single lines):
//!   <n_nodes>
//!   <label_1>
//!   ...
//!   <label_n>
//!   <n_edges>
//!   <src> <dst>      (one per line, 1-based indices)
//!   ...

use ascii_dag::graph::Graph;
use ascii_dag::render::colors::Palette;
use std::io::{self, Read};

fn main() {
    let color = std::env::args().any(|a| a == "--color");
    let mut input = String::new();
    io::stdin().read_to_string(&mut input).expect("read stdin");
    let mut lines = input.lines();

    let n: usize = lines.next().unwrap_or("0").trim().parse().unwrap_or(0);
    let labels: Vec<String> = (0..n)
        .map(|_| lines.next().unwrap_or("").to_string())
        .collect();

    let m: usize = lines.next().unwrap_or("0").trim().parse().unwrap_or(0);
    let edges: Vec<(usize, usize)> = (0..m)
        .filter_map(|_| {
            let line = lines.next()?;
            let mut it = line.split_whitespace();
            let a = it.next()?.parse::<usize>().ok()?;
            let b = it.next()?.parse::<usize>().ok()?;
            Some((a, b))
        })
        .collect();

    let nodes: Vec<(usize, &str)> = labels
        .iter()
        .enumerate()
        .map(|(i, s)| (i + 1, s.as_str()))
        .collect();

    let dag = Graph::from_edges(&nodes, &edges);
    if color {
        let ir = dag.compute_layout();
        print!("{}", ir.render_scanline_colored(Palette::Ansi));
    } else {
        print!("{}", dag.render());
    }
}
