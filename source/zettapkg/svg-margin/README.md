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

**Docs:** this README (engine + API) · [CONFIGURATION.md](CONFIGURATION.md)
(options, and diverting data from other fringe/margin packages) ·
[EXAMPLES.md](EXAMPLES.md) (ten ready-made providers).

## How it works

- A **provider** is a function `BUFFER -> (list of indicators)`. Register any
  number of them; they're fully decoupled, so several packages can feed the
  same gutter.
- An **indicator** is a plist describing *where* and *what* to draw.
- On each render the engine pulls all providers, groups indicators by
  `(line, side)`, **packs them into columns**, and draws one composite SVG
  per line/side. The margin width on a side grows to the widest line.

## Installation

Requires **Emacs 29.1+** and a **graphical frame** (it draws SVG images, so
it shows nothing in a terminal `emacs -nw`); no dependencies beyond the
built-in `svg.el`. Once on MELPA:

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
| `:pos`/`:line` | buffer position or **absolute** 1-based line (one is required; resolved against the whole buffer, so it is correct under narrowing) |
| `:side`     | `left` (default `svg-margin-default-side`) or `right`          |
| `:column`   | explicit slot (0 = nearest the text); else auto-packed         |
| `:priority` | higher is packed first → claims the inner column (default 0)    |
| `:shape`    | a built-in shape: `dot` (filled disc) · `circle` (hollow ring) · `bar` (vertical bar) · `box` (rounded square) · `triangle`, or your own via `svg-margin-define-shape` |
| `:text`     | a short string drawn centred (e.g. an evil mark letter)        |
| `:draw`     | `(lambda (SVG X Y W H COLOR) ...)` for full control            |
| `:color`/`:face` | fill colour, or a face whose foreground is used           |
| `:help`     | tooltip string                                                 |

Indicators sharing a `(line, side)` pack into adjacent columns; an explicit
free `:column` is honoured, otherwise each takes the lowest free slot.

One of `:pos`/`:line` is **required** — an indicator without a (valid, in-range)
position is silently skipped. Set `svg-margin-debug` to `t` to get a message
naming the provider when that happens (handy while writing one).

### Provider defaults and moving a provider's side

A provider can set defaults so it needn't stamp every indicator, and **users
can relocate any provider — including a third-party one — without editing it**:

```elisp
;; provider author: default everything from this provider to the right margin
(svg-margin-register-provider 'my-source #'my-fn :side 'right :priority 5)

;; user: override where a provider draws, declaratively
(setq svg-margin-provider-sides '((my-source . left) (flycheck . right)))
```

Precedence for an indicator's side: `svg-margin-provider-sides` override →
the indicator's own `:side` → the provider's registered `:side` →
`svg-margin-default-side`.

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

   This is **independent of which margin side you draw in** — margins and
   fringes are separate regions, so right-margin indicators coexist with the
   right fringe. Disable a fringe only once you've migrated *its* users:
   e.g. don't zero the right fringe if `yascroll`/`flycheck` still draw a
   scroll bar / checker marks there, or they'll have nowhere to render.
2. **Move the data** — write a provider that reads the package's own state.
   No interception needed; adapters are ~10 lines.

For how hard this is in practice — reading a package's data vs. stopping its own
drawing, the difficulty tiers, refresh triggers, and a worked git-gutter
example — see **[CONFIGURATION.md](CONFIGURATION.md)** ("Diverting data from
other packages").

`examples/svg-margin-examples.el` ships ten ready-made providers — VC
(git-gutter or diff-hl), flycheck, TODO/FIXME, bookmarks, evil marks, an Org
heading rail, long-line and trailing-whitespace hygiene, and live
symbol-at-point occurrences — that stack into columns on shared lines. Each is
short and demonstrates a different technique. `M-x svg-margin-example-setup`
(plus `M-x svg-margin-example-extras-setup`) wires them up with the fringe
diversion.

See **[EXAMPLES.md](EXAMPLES.md)** for what each provider does, what it looks
like, why it's useful, and how to write your own.

## Layout notes

- Margin width is measured in **character columns**, so column *N* maps
  directly to margin width *N* (times `svg-margin-column-width`).
- Overlays are created **only where indicators exist**, so cost scales with
  the number of indicators, not buffer size.
- Margins and the composite image are pinned to `:scale 1.0`, so the gutter
  doesn't inherit `image-scaling-factor` and overflow.

## Caveats (v1)

- svg-margin **owns** the managed margins while active (one consumer at a time).
  Another package that also writes the *same* window margin — e.g. `git-gutter`
  in its margin (non-fringe) mode — will duel with it: each re-sets the margin
  width to its own value and reacts to the other's change, so the buffer text
  **flickers left/right**. Disable the other margin user (and instead feed its
  data in through an svg-margin provider). svg-margin only writes a window whose
  margins actually changed, so it never duels with *itself*.
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
