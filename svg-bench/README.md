# svg-bench — how fast is SVG rendering in Emacs?

A self-contained benchmark (`svg-bench.el`, only built-in `svg` + `cl-lib`, no
packages, no I/O) for the cost of rendering a status bar in Emacs two ways — as
an **SVG image** (`svg.el` → `create-image` → librsvg → redisplay) versus the
**native text engine** — plus an icon animation that shows where SVG size
starts to bite.

It backs a blog post, so it has both **live, recordable demos** and **headless
data gatherers**.

> The thesis: SVG raster cost scales with image **pixel area**. A status bar is
> *short*, so even a very wide (ultrawide-monitor) SVG bar — and even a thin
> inline animation re-rendering every frame — stays comfortably above the 60 fps
> that high-frame-rate applications target.

Everything needs a **graphical** frame — raster and fps are meaningless under
`--batch` or `-nw`.

## Usage

```sh
emacs -Q ~/.zetta.d/svg-bench/svg-bench.el
```

Then `M-x eval-buffer`, and:

**Demos** (record these — each shows a `[type] [data]` label, the rendered data,
and a live fps counter):

| command | what it renders |
|---|---|
| `M-x svg-perf-text` | an SVG bar drawing text |
| `M-x svg-perf-icons` | an SVG bar drawing Nerd-Font icon glyphs |
| `M-x builtin-perf-text` | the native text engine drawing text |
| `M-x svg-perf-animation` | the purple Emacs icon bouncing in a thin inline bar (optional width arg) |

**Data tables:**

| command | output |
|---|---|
| `M-x svg-perf-benchmark` | three tables — SVG-text / SVG-icons / built-in-text, each across the narrow/medium/large bar widths |
| `M-x svg-perf-animation-benchmark` | one table — the line animation across small/medium/large bar widths |

Both gather **20 trials × 100 frames** per cell and report mean / median / sd /
min / max ms, **mean fps**, and **min fps** (the worst trial — the number that
matters for "is it *always* above 60?").

## Methodology

The per-update cost splits into stages, and a naive benchmark hides the
interesting one:

1. **Generation** — build the `svg.el` DOM and serialise it to the XML string
   (pure Lisp; does *not* rasterise).
2. **Rasterisation** — librsvg paints the bitmap. This happens during
   *redisplay*, not at `create-image`, and is cached by the data string.
3. **Composite** — Emacs draws the bitmap into the frame.

So timing only the render call misses rasterisation entirely. Instead the
harness re-renders into a displayed buffer and forces `(redisplay t)` in a loop,
measuring wall-clock ms per frame. Care taken so the numbers are honest:

- **GUI only.** Under `--batch` there is no display and rasterisation is
  skipped; it would look infinitely fast.
- **Every frame is a unique image.** A 2px per-frame colour marker at the bar's
  edge guarantees a distinct SVG data string, so each frame is an Emacs
  image-cache *miss* and is genuinely re-rasterised. (Verified: an *identical*
  image is a cache hit at ~0.3 ms; the benchmark runs 10–40× slower, so the
  cache is not helping it. Rotating through a small content pool, by contrast,
  repeats frames and silently hits the cache — which is why we mark instead.)
  Glyph *colour* stays fixed, so librsvg's internal glyph cache behaves as in a
  real re-render and text vs icons is a fair, like-for-like comparison.
- **Full-image raster regardless of window.** librsvg rasterises the whole
  W×H image even if the window clips it, so a wide SVG bar genuinely pays for
  its full width. The native engine, by contrast, only pays for the glyphs it
  draws — which is why the two diverge so sharply as the bar widens.
- **`gc-cons-threshold` pinned**, a **warm-up frame** discarded, and the image
  **cache cleared** before each trial.

The three bar widths are the size axis: SVG raster scales with width; the native
engine scales with the glyph count that width implies. The line animation uses
the same thin bar shape across three widths, so it scales the same gentle way.

## Results

Measured on Emacs 31.0.50 (native-comp, librsvg, macOS Retina), 20 trials × 100
frames per cell.

### Status bars (`svg-perf-benchmark`)

```
SVG / text             | mean ms | min ms | max ms | mean fps | min fps
narrow  800px,  65c    |   3.55  |  3.13  |  3.93  |     282  |    254
medium  1800px, 149c   |   7.74  |  7.34  |  8.08  |     129  |    124
large   3000px, 249c   |  13.07  | 12.37  | 13.59  |      76  |     74

SVG / icons            | mean ms | min ms | max ms | mean fps | min fps
narrow  800px,  65c    |   3.61  |  3.28  |  3.83  |     277  |    261
medium  1800px, 149c   |   7.77  |  7.13  |  8.30  |     129  |    121
large   3000px, 249c   |  13.10  | 12.63  | 13.72  |      76  |     73

BUILT-IN / text        | mean ms | min ms | max ms | mean fps | min fps
narrow  800px,  65c    |   0.16  |  0.14  |  0.18  |    6414  |   5574
medium  1800px, 149c   |   0.22  |  0.18  |  0.65  |    4506  |   1527
large   3000px, 249c   |   0.25  |  0.22  |  0.28  |    3967  |   3604
```

Even the **large** (3000px, ultrawide-monitor-width) SVG bar stays **>60 fps**:
mean 76, and the *worst of 20 trials* is still **73–74 fps**. Text and icons
land on essentially the same numbers — with a fixed glyph colour the cost is
canvas-area-bound, so glyph *type* barely matters. The native engine is
~30–80× cheaper because it never rasterises empty pixels.

### Line animation (`svg-perf-animation-benchmark`)

```
animation width        | mean ms | min ms | max ms | mean fps | min fps
small   300x56px        |   1.94  |  1.77  |  2.26  |     517  |    443
medium  700x56px        |   4.03  |  3.75  |  4.55  |     248  |    220
large   1400x56px       |   7.45  |  7.04  |  7.77  |     134  |    129
```

A thin inline animation (three large purple icons — Emacs, Org, image — gliding
along a white bar) that re-rasterises a fresh SVG **every frame** runs at
**130–520 fps** across these widths — the worst trial is still ~129 fps. So an
SVG animation you'd actually drop into a status line is silky, not just "fast
enough."

## Conclusion

An SVG status bar costs several times more than the native text engine, and is
still far faster than 60 fps — even at ultrawide widths, and even when it is a
*live, every-frame animation* — because a bar is short and raster cost is
area-bound. The text engine remains an order of magnitude cheaper, but SVG has
ample headroom for the job.
