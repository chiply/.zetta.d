# svg-perf — measuring SVG rendering performance in Emacs

A self-contained, dependency-free benchmark for Emacs's SVG pipeline
(`svg.el` → `create-image` → librsvg → redisplay). No packages, no I/O, no
`svg-line` — it measures Emacs SVG performance *in general*, so the numbers
aren't entangled with any config or content function.

Everything is in one file, `svg-perf.el` (~200 lines of Elisp, only built-in
`svg` and `cl-lib`).

## Requirements

A **graphical** Emacs. Rasterisation and fps are meaningless under `--batch` or
`-nw` (no display), so the commands refuse to run there.

## Running it (live demo)

```sh
emacs -Q svg-perf/svg-perf.el
```

Then:

1. `M-x eval-buffer` — load the commands.
2. `M-x svg-perf-animate` — **the visual demo**: a large SVG (48 moving bars)
   animates in the window with a giant live **fps counter**, building and
   rasterising a fresh ~900×420 image every frame. Runs ~8s; any key stops it.
3. `M-x svg-perf-report` — the SVG benchmark table (below), filled in row by
   row in a `*svg-perf*` buffer.
4. `M-x svg-perf-vs-modeline` — the **same changing text** rendered by Emacs's
   native text mode line vs an SVG mode line, head to head.
5. `M-x svg-perf-three-way` — native text mode line vs SVG-text vs SVG-icon-
   glyphs (Nerd Font), matched on cell count, over 10 trials with averages.

## What it measures

The per-update cost splits into stages that have to be measured separately:

- **generation** — build the `svg.el` DOM and serialise it to the XML data
  string. Pure Lisp; measured with `benchmark-run`. Does **not** rasterise.
- **rasterisation** — librsvg turning that XML into a bitmap. Happens during
  *redisplay*, not at `create-image`, and is **cached by the data string**.
  Measured end to end as `dynamic − static` (see below).
- **composite / redisplay** — Emacs drawing the cached bitmap into the frame.

The harness shows an image in a header/mode line and forces redisplay in a
loop. With content **changing** each frame the image is a cache miss (librsvg
rasterises); with content **static** it's a cache hit (composite only). So:

```
raster ≈ dynamic − static          fps = 1000 / dynamic
```

### Reproducibility gotchas (learned the hard way)

- Pin `gc-cons-threshold` high during timing; report consing separately.
  Per-frame allocation is the real GC risk, not raw CPU.
- Discard a warm-up frame (the first render loads librsvg).
- **`force-mode-line-update` (no arg) does NOT re-rasterise a mode-line image**
  — redisplay reuses the cached glyph. You must call
  `force-mode-line-update t`. A benchmark using the no-arg form silently
  measures a no-op (~0.1 ms) instead of the real ~2–6 ms. (A header line *does*
  refresh without the `t`, which is how this bug hides.)
- Run in a real GUI frame — `--batch` skips rasterisation and will look
  infinitely fast.

## Sample results

Measured on Emacs 31.0.50 (native-comp, librsvg, macOS), 597×508 px frame.

### SVG pipeline (`svg-perf-report`)

```
elems@WxH    | gen us | dyn ms | static ms | raster ms |  fps
8@800x22     |     47 |   2.20 |      0.12 |      2.08 |  454
32@800x22    |    149 |   2.33 |      0.25 |      2.09 |  428
128@800x22   |    523 |   3.35 |      0.62 |      2.74 |  298
512@800x22   |   2211 |   8.73 |      2.38 |      6.34 |  115
32@1600x22   |    136 |   3.72 |      0.22 |      3.50 |  269
256@1600x44  |   1074 |  10.01 |      1.18 |      8.83 |  100
32@3000x44   |    143 |  12.06 |      0.24 |     11.82 |   83
```

- A realistic bar (≤32 elements, 800–1600 px) repaints **fully fresh at
  280–450 fps** (~2–3.5 ms) — 5–9× the 60 fps budget.
- An **unchanged** bar is a cache hit: ~0.1–0.2 ms. Steady-state cost ≈ 0.
- **Rasterisation scales with pixel area** (same 32 elems: 800×22 → 1.9 ms,
  3000×44 → 11.8 ms). On a HiDPI display the device-pixel area — and raster
  cost — can be ~4× the logical size.
- **Generation scales with element count** (~4.3 µs/element): only hundreds of
  shapes make the Lisp serialise cost visible.

### SVG vs the native text mode line (`svg-perf-vs-modeline`)

Same changing text, both repainted every frame:

```
segs | text ms | svg ms | text fps | svg fps | svg/text
4    |   0.31  |  2.00  |    3233  |    500  |  6.5x
16   |   0.71  |  3.19  |    1417  |    314  |  4.5x
48   |   0.71  |  6.22  |    1408  |    161  |  8.8x
```

- The SVG mode line is **~4.5–9× heavier** than the native text engine —
  skeptics are right that it costs more.
- But it's still **160–500 fps** *while repainting the whole bar every frame*,
  3–8× over the 60 fps budget. Real bars only repaint on content change, so the
  steady-state difference is negligible.

### Native vs SVG-text vs SVG-glyphs, 10 trials (`svg-perf-three-way`)

Each draws **72 matched cells** (72 ASCII chars vs 72 Nerd-Font icon glyphs vs
the same 72-char string in the native mode line), repainting every frame. Averages
over 10 trials:

```
         native ms | svg-text ms | svg-glyph ms
  AVG        0.295  |     2.521   |     2.920
  avg fps     3385  |       397   |       342
  ratios:  svg-text/native 8.5x   svg-glyph/native 9.9x   svg-glyph/svg-text 1.16x
```

- **Icon glyphs cost ~16% more than ASCII text in SVG** (2.92 vs 2.52 ms) —
  Nerd-Font glyphs are more complex vector shapes — but it's a minor effect; the
  fixed whole-canvas raster dominates both.
- The native/SVG **ratio is not a stable number**: SVG is ~flat at ~2–3 ms
  regardless of cell count (canvas raster dominates), while the native text
  engine scales with the number of glyphs. So the meaningful figure is the
  *absolute* SVG cost (~2–3 ms ⇒ 340–400 fps), not the ratio.

## The honest conclusion

SVG generation is microseconds; rasterisation of a normal-sized bar is a couple
of milliseconds and only happens on a content change (then it's cached). Yes,
it's several times heavier than text — and still an order of magnitude faster
than 60 fps. In a real status bar the dominant cost is almost never the SVG: it
is whatever the *content* function does (e.g. a synchronous `git` call in a VC
segment can be ~7.6 ms — ~40× the entire SVG pipeline, and exactly the cost a
text mode line would pay too).
