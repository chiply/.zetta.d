# Configuring svg-margin

How to set svg-margin up, and — the part most people ask about first — how hard
it is to **divert data from packages that already use the fringe or margin**
into the svg-margin gutter.

- For the engine API and indicator keys, see [README.md](README.md).
- For ready-made providers you can copy, see [EXAMPLES.md](EXAMPLES.md).

## Options

All are plain `defcustom`s (`M-x customize-group RET svg-margin`):

| Option | Default | Meaning |
|--------|---------|---------|
| `svg-margin-column-width` | `1` | width of one indicator column, in character cells |
| `svg-margin-default-side` | `left` | side for indicators that don't set `:side` |
| `svg-margin-min-left-columns` | `0` | columns to always reserve in the left margin |
| `svg-margin-min-right-columns` | `0` | columns to always reserve in the right margin |
| `svg-margin-disable-fringe` | `nil` | `left` / `right` / `both` — which fringe to collapse to 0 while active |
| `svg-margin-provider-sides` | `nil` | alist `(PROVIDER . left|right)` forcing where a provider draws |
| `svg-margin-debug` | `nil` | message indicators dropped for a missing/out-of-range position |
| `svg-margin-idle-delay` | `0.1` | seconds to coalesce changes before re-rendering |
| `svg-margin-help-face` | `svg-margin-help` | face for an indicator's hover help (or nil for none) |

Indicators can be made interactive with `:action` (left/middle click),
`:action-help` (the "click to …" hint), and `:menu` (right-click context
menu); see the indicator keys in the [README](README.md). The hover help is
shown with `svg-margin-help-face` (a contrasting background by default), which
stands out especially when help is shown in the **echo area** rather than a
tooltip — useful on tiling window managers, where Emacs's own tooltip *frame*
can get tiled. To route help to the echo area, disable `tooltip-mode`
(`(tooltip-mode -1)`), which also makes it instant.

Enable per buffer with `svg-margin-mode`, or everywhere with
`global-svg-margin-mode`. svg-margin needs a **graphical frame** (it draws SVG),
so it shows nothing in `emacs -nw`.

### Keeping the buffer from shifting

By default a margin is only as wide as it needs to be, so the buffer text shifts
left/right as indicators appear and disappear. Reserve a baseline to keep it
steady:

```elisp
(setq svg-margin-min-left-columns 1
      svg-margin-min-right-columns 1)
```

The margin still grows beyond the minimum when a line needs more columns — it
just never drops below it, so text stops jiggling up to that width. (Indicators
are drawn nearest the text within the reserved space, so a wider reservation
shows as empty room at the window edge, not a gap against the text.)

## Registering a provider

```elisp
;; minimal
(svg-margin-register-provider 'mine #'my-fn)

;; with per-provider defaults (applied to indicators that omit them)
(svg-margin-register-provider 'mine #'my-fn :side 'right :priority 5)
```

A provider is a function `BUFFER -> (list of indicator plists)`. One of
`:pos`/`:line` is required (line numbers are absolute, correct under narrowing);
an indicator without a valid position is silently skipped unless
`svg-margin-debug` is on.

## Moving a provider's side (yours or someone else's)

```elisp
(setq svg-margin-provider-sides '((flycheck . right) (git-gutter . left)))
```

This is declarative and works for **third-party** providers too — you never
edit the provider. Side precedence: `svg-margin-provider-sides` →
the indicator's own `:side` → the provider's registered `:side` →
`svg-margin-default-side`.

## Reclaiming the fringe

```elisp
(setq svg-margin-disable-fringe 'left)   ; collapse the left fringe to 0
```

This is **independent of which margin side you draw in** — margins and fringes
are separate regions, so right-margin indicators coexist with the right fringe.
Only disable a fringe once you've migrated *its* users; e.g. don't zero the
right fringe if `yascroll`/`flycheck` still draw there, or they'll have nowhere
to render. Original widths are restored when the mode is turned off.

---

# Diverting data from other packages

This is the most common adoption question, so it's worth being precise. Think of
diversion as **two separate jobs**:

1. **Read the data** — write a provider that reads what the other package
   already knows, and emit indicators from it.
2. **Stop the original drawing** — so you don't get duplicates or, if the other
   package also writes the *margin*, a layout "duel."

For the common case both are easy. Job 1 is almost always the easy half because
most packages keep their per-line state in a reachable variable; the provider is
~10 lines. Job 2 is the part whose difficulty varies — and you often don't need
it at all.

## Job 1 — read the data

Most sources expose their state in a variable or a function. The providers
shipped in [EXAMPLES.md](EXAMPLES.md) are worked examples:

| Source | Where the data lives | Provider size |
|--------|----------------------|---------------|
| evil marks | `evil-markers-alist` | ~10 lines |
| bookmarks | `bookmark-alist` | ~12 lines |
| flycheck | `flycheck-current-errors` | ~10 lines |
| git-gutter | `git-gutter:diffinfos` | ~12 lines |
| diff-hl | `diff-hl-changes` (a function) | ~14 lines |

The pattern is always the same: read the state, map each entry to a `:line`/`:pos`
plus a `:shape`/`:text`/`:color`, return the list.

## Job 2 — stop the original drawing

The difficulty depends entirely on *how* the source draws:

- **It has a minor mode you can disable** → trivial. Turn it off and read the
  underlying data instead. e.g. `evil-fringe-mark`:
  `(global-evil-fringe-mark-mode -1)`, then read evil's own `evil-markers-alist`.
- **It draws in the *fringe*, you draw in the *margin*** → you may not need to
  suppress it at all; the two regions coexist, so "diversion" is just *addition*.
  Suppress only to reclaim the fringe, usually via the package's own knob
  (e.g. `flycheck-indication-mode`).
- **It draws in the *margin* (a true duel)** → override its draw function so it
  keeps computing but stops drawing. This was the hardest case among everything
  shipped, and it was **one line** (see the git-gutter example below).

## The fiddly part: refresh timing

Neither job above is usually the tricky one — knowing *when* to re-render is.
You need a trigger that fires when the source's data changes:

- best — the package provides a hook (`flycheck-after-syntax-check-hook`);
- common — advise the package's setter (`evil-set-marker`, `bookmark-set`);
- bonus — when you override a draw function (the duel case), that override
  *is* your refresh trigger.

Always pair the trigger with a teardown that removes the hook/advice.

## The hard tail (honestly)

- **Data not exposed** — a package that computes and draws in one closure with
  no stored state. You must advise its compute function to capture the data, or
  re-derive it yourself. Medium-hard.
- **Data that's expensive to produce** — git-blame heat, coverage: you run git /
  parse a report, ideally asynchronously. Real effort, but it lives in *your*
  provider, not in fighting svg-margin.
- **No generic interception** — svg-margin can't auto-divert arbitrary fringe
  users; fringe bitmaps are opaque and drawing mechanisms differ per package.
  Diversion is adapter-based by design.

The decoupling is what keeps this tractable: svg-margin only ever needs **data +
a position**, so you never reverse-engineer its rendering — you just read state
you can already reach.

## Worked example: divert git-gutter (the duel case)

git-gutter draws VC hunks in the *margin* itself, so it would fight svg-margin.
The fix keeps git-gutter computing but stops it drawing, and renders from its
data:

```elisp
;; Job 1: a provider that reads git-gutter's hunks
(defun my-gg-provider (buffer)
  (with-current-buffer buffer
    (when (and (bound-and-true-p git-gutter-mode) (boundp 'git-gutter:diffinfos))
      (let (out)
        (dolist (h git-gutter:diffinfos)
          (let ((start (git-gutter-hunk-start-line h))
                (end   (or (git-gutter-hunk-end-line h)
                           (git-gutter-hunk-start-line h)))
                (type  (git-gutter-hunk-type h)))
            (if (eq type 'deleted)
                (push (list :line start :shape 'triangle :color "#f85149") out)
              (cl-loop for ln from start to end do
                       (push (list :line ln :shape 'bar
                                   :color (if (eq type 'added) "#3fb950" "#d29922"))
                             out)))))
        out))))

;; Job 2 + refresh: stop git-gutter drawing; its draw call becomes the trigger
(defun my-gg-feed (&rest _) (svg-margin-refresh))

(advice-add 'git-gutter:view-diff-infos :override #'my-gg-feed)
(svg-margin-register-provider 'git-gutter #'my-gg-provider :side 'left :priority 9)
(global-git-gutter-mode 1)   ; still computes; just doesn't draw
```

To undo:

```elisp
(advice-remove 'git-gutter:view-diff-infos #'my-gg-feed)
(svg-margin-unregister-provider 'git-gutter)
```

A package with a plain variable and a disableable mode (evil marks, bookmarks)
is simpler still — no override needed. See [EXAMPLES.md](EXAMPLES.md) for all of
the shipped adapters.
