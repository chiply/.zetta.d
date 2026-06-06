# svg-margin

Turn the Emacs window margins into a flexible, **multi-column gutter** that
many independent sources can draw into — with their indicators packed **side
by side on the same line**, as crisp **SVG**.

The fringe can only render monochrome bitmaps, and only **one** bitmap per
line per side — so `git-gutter`, `evil-fringe-mark`, `flycheck`, bookmarks,
and continuation arrows all compete for the same ~8px strip and clobber each
other. svg-margin sidesteps that: a margin can show arbitrary SVG, so the
engine composites *every* indicator for a line/side into **one SVG image** at
exact pixel coordinates. Both the **left and right** margins are supported.

svg-margin is the rendering **engine** only — it ships no providers. You (or
a tiny adapter) supply them.

## How it works

- A **provider** is a function `BUFFER -> (list of indicators)`. Register any
  number of them; they're fully decoupled, so several packages can feed the
  same gutter.
- An **indicator** is a plist describing *where* and *what* to draw.
- On each render the engine pulls all providers, groups indicators by
  `(line, side)`, **packs them into columns**, and draws one composite SVG
  per line/side. The margin width on a side grows to the widest line.

## Installation

Requires **Emacs 29.1+**; no dependencies beyond the built-in `svg.el`.
Once on MELPA:

```elisp
(use-package svg-margin
  :ensure t)
```

Or manually, with `svg-margin.el` on your `load-path`:

```elisp
(require 'svg-margin)
```

## Usage

```elisp
(svg-margin-register-provider 'my-source
  (lambda (_buffer)
    (list (list :line 10 :shape 'bar :color "#3fb950")          ; col 0
          (list :line 10 :text "a"  :face 'warning)             ; col 1, same line
          (list :line 25 :shape 'dot :side 'right :color "red"))))

(svg-margin-mode 1)            ; buffer-local; or global-svg-margin-mode
```

### Indicator keys

| Key         | Meaning                                                        |
|-------------|----------------------------------------------------------------|
| `:pos`/`:line` | buffer position or 1-based line (one is required)           |
| `:side`     | `left` (default `svg-margin-default-side`) or `right`          |
| `:column`   | explicit slot (0 = nearest the text); else auto-packed         |
| `:priority` | higher is packed first → claims the inner column (default 0)    |
| `:shape`    | a registered shape: `dot` `circle` `bar` `box` `triangle`      |
| `:text`     | a short string drawn centred (e.g. an evil mark letter)        |
| `:draw`     | `(lambda (SVG X Y W H COLOR) ...)` for full control            |
| `:color`/`:face` | fill colour, or a face whose foreground is used           |
| `:help`     | tooltip string                                                 |

Indicators sharing a `(line, side)` pack into adjacent columns; an explicit
free `:column` is honoured, otherwise each takes the lowest free slot.

### Custom shapes

Register your own, the SVG analogue of `define-fringe-bitmap`:

```elisp
(svg-margin-define-shape 'chevron
  (lambda (svg x y w h color)
    (svg-polygon svg (list (cons x y) (cons (+ x w) (+ y (/ h 2))) (cons x (+ y h)))
                 :fill color)))
```

## Diverting the fringe

Two independent pieces:

1. **Reclaim the space** — set `svg-margin-disable-fringe` to `left`,
   `right`, or `both`; svg-margin zeroes that fringe while active and restores
   it on exit. (Note: a zeroed fringe also hides its truncation/continuation
   arrows.)
2. **Move the data** — write a provider that reads the package's own state.
   No interception needed; adapters are ~10 lines.

`examples/svg-margin-examples.el` ships three, stacking on one line:

- **evil marks** — reads evil's `evil-markers-alist` (no `evil-fringe-mark`,
  no fringe), drawing each mark letter in the margin;
- **VC hunks** — reads `diff-hl-changes`, drawing a coloured bar that hugs the
  text like a gutter;
- **TODO/FIXME/HACK** — coloured dots.

`M-x svg-margin-example-setup` wires all three plus the fringe diversion.

## Layout notes

- Margin width is measured in **character columns**, so column *N* maps
  directly to margin width *N* (times `svg-margin-column-width`).
- Overlays are created **only where indicators exist**, so cost scales with
  the number of indicators, not buffer size.
- Margins and the composite image are pinned to `:scale 1.0`, so the gutter
  doesn't inherit `image-scaling-factor` and overflow.

## Caveats (v1)

- svg-margin **owns** the managed margins while active (one consumer at a time).
- Margin *content* (the overlay images) is per-buffer, while the reserved
  *width* is per-window — so the same indicators show in every window on the
  buffer.
- Each indicator occupies one column (multi-column-wide single indicators are
  not yet modelled).

## Tests

```sh
cd test
emacs -Q --batch -L .. -l svg-margin-test.el -f ert-run-tests-batch-and-exit
```

Rendering/overlay/margin behaviour needs a live graphical frame; the test
suite covers the pure logic (column packing, colour, normalisation, grouping,
shape registry).
