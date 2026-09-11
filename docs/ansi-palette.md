# The ANSI Palette

How the 16 terminal colour slots are fitted to the current theme, and why
config in **another repo** depends on the numbers in this one.

## TL;DR

A terminal's colour table holds 256 entries plus a default fg/bg, and only
**slots 0–15 are remappable**. Slots 16–255 are a fixed RGB cube and grey
ramp; truecolor (`ESC[38;2;R;G;Bm`) names an exact colour and bypasses the
table entirely. So chrome written in hex or in 256-cube indices cannot
follow a theme, and chrome written in slots can.

`zetta-ghostel-apply-ansi-palette` (`modules/tools/ghostel.el`) refits all
sixteen on every theme change. It runs from `brushup-styles`, which is late
enough that brushup has already recomputed its faces — see the commentary on
`zetta-ghostel--push-palette` for why ordering matters here.

## The ladder

The four achromatic slots are fitted to **exact** WCAG contrasts against the
page, not to a floor. Fitting them to a floor collapses them onto whichever
grey sits at that ratio; fitting them exactly is what holds them apart and
makes them a prominence ladder rather than four greys.

| rung | contrast vs page | role |
|---|---|---|
| `default` | 1.0 | the page itself |
| `colour0` | 1.5 | wash — barely off the page |
| `colour8` | 3.0 | subtle — comment weight |
| `colour15` | 5.5 | mid |
| `colour7` | 9.0 | body ink |

A pair's contrast is the **ratio of its two rungs**, since all four sit on
the same side of the page: `colour7` on `colour0` is 9.0/1.5 = 6.0. Keep
text pairs at 3.0 or better.

The twelve chromatic slots take their number as a *minimum* instead, so a
hue that already reads against the page is left alone rather than dragged
onto a target. Their hues come from a Ghostty theme file
(`zetta-ghostel-ghostty-themes`) and lean toward the theme's own accent
faces — see `zetta-ghostel-hue-sources` and `zetta-ghostel-hue-rotation`.

## Where the greys get their tint

Only hue and chroma survive from the source colour; the exact fit replaces
lightness wholesale. `zetta-ghostel-grey-source` decides which colour lends
them, and defaults to the **page**.

This matters only where a theme's ink and ground disagree, and then it
matters a lot. doric-earth grounds at hue 102 and inks at 342:

| | hue | chroma |
|---|---|---|
| page `#f1ecd0` | 102° | 14 |
| `tab-bar-tab-inactive` `#aea88e` | 99° | 14 |
| ink `#231a1f` | 342° | 6 |

Every Emacs surface follows the ground. Greys sourced from the ink came out
mauve at 342° — a 120° error at half the chroma — against a khaki tab bar.
The greys are chrome (0 is a field, 8 a border, 15 a fill) and chrome
belongs to the ground's family. Where ink and ground agree, as doric-plum's
violet pair do, the setting changes nothing.

## Consumers outside this repo

**Changing `zetta-ghostel-contrast-targets` or `zetta-ghostel-grey-source`
restyles config that does not live here.** The tmux status bar is written
entirely in slot names so that it follows the Emacs theme; it has no palette
of its own. In [`chiply/.files`](https://github.com/chiply/.files):

| file | what it draws |
|---|---|
| `.config/tmux-powerline/themes/tomorrow-light.sh` | status bar segments, window pills |
| `.tmux/themes/tomorrow-powerline.tmux` | pane borders, copy mode, popups, clock |
| `.config/gitmux/gitmux.cfg` | the git segment's three text rungs |
| `.config/tmux-powerline/config.sh` | k8s and vpn symbol colours |
| `.tmux.conf` | the fzf popup theme |

See `TMUX.md` in that repo for the consumer-side notes. Two things to know
from this side:

- **fzf spells terminal-default `-1`**, not `default`.
- The same slots dress the Claude Code TUI, via an `ansi:`-only theme at
  `~/.claude/themes/zetta.json`. Sixteen slots serve roughly seventy UI
  roles there, so roles collide; anything that must stay distinguishable has
  to sit on a different slot first.

The palette also reaches the standalone Ghostty app, which is configured on
`Zenbones Light` — the very theme ghostel refits. Slot-written chrome
therefore reads as the same palette in both hosts, fitted in ghostel and raw
in the app.

## Gotchas

- **Modules load interpreted.** `zetta-modules!` uses `load-file`, which
  takes an exact filename, so `ghostel.el` is read as source and a stale
  `ghostel.elc` beside it is never loaded (see `bootstrap-modules.el`).
  Editing this file needs no recompile.
- **The palette must not be read back from its own faces.**
  `set-face-attribute` is destructive, so a pass that read `ghostel-color-red`
  would be reading its own previous answer and the nudges would compound
  across theme switches. They did once: black, white, bright-black and
  bright-white all drifted onto the same mid-grey. Hues come from a file for
  this reason.
- **`COLORTERM` is dropped under ghostel** (see `.zshrc` in `.files`), so
  programs emit slot escapes rather than truecolor and stay remappable.
