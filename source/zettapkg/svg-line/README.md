# svg-line

Render the Emacs **tab-bar**, **tab-line**, **header-line**, and **mode-line**
as SVG images instead of laid-out text.

An SVG image can be any height and is positioned at exact pixel coordinates,
which makes possible things the text engine can't do uniformly:

- **multi-line** bars (status info, breadcrumbs) of arbitrary height;
- **per-line left/right alignment on every line** — not just the last, and
  without the `:align-to`-on-a-non-final-line redisplay freeze;
- **tab lines that wrap** overflowing tabs onto new rows instead of
  truncating or scrolling horizontally.

svg-line is the rendering **engine** only: it ships no content and no colours.
You supply a `:content` function and styling and bind it to a target.

## Layout modes

| Mode    | Shape                                   | Used for                          |
|---------|-----------------------------------------|-----------------------------------|
| `lines` | rows of `(LEFT . RIGHT)`                | tab-bar, mode-line, header-line   |
| `wrap`  | a flow of items wrapped across rows     | tab-line (buffer tabs)            |

## Usage

```elisp
(require 'svg-line)

;; A multi-line mode line, active/inactive aware:
(defun my-mode-line-rows ()
  "Return a list of (LEFT-SEGMENTS . RIGHT-SEGMENTS)."
  (list (cons '(my-buffer-name) '(my-major-mode my-position))
        (cons '(my-vc my-flycheck) '(my-clock))))

(svg-line-define 'mode-line
  :target 'mode-line
  :content #'my-mode-line-rows
  :active  #'mode-line-window-selected-p
  :foreground          (lambda () (face-foreground 'default))
  :background          "#e7edf6"     ; active
  :inactive-background "#f3f6fb")

(svg-line-activate 'mode-line)   ;; svg-line-deactivate / svg-line-toggle
```

A `wrap` tab-line whose `:content` returns `(LABEL . STATE)` items. `STATE`
is either a `CURRENTP` atom or a plist with `:current` / `:modified` keys:

```elisp
(defun my-tab-line-items ()
  (list (cons "1 init.el"  '(:current t   :modified nil))
        (cons "2 notes.md" '(:current nil :modified t))))   ; unsaved

(svg-line-define 'tab-line
  :target 'tab-line :layout 'wrap
  :content #'my-tab-line-items
  :active  #'mode-line-window-selected-p
  :background "#eef3fc"
  :current-background "#2a4d77" :current-foreground "#ffffff"
  :modified-foreground "#c1641e"                 ; unsaved-buffer tabs
  ;; inactive (unfocused-window) palette — each falls back to its active
  ;; counterpart when omitted:
  :inactive-background "#f4f6fa"
  :inactive-current-background "#9aa9bd")
(svg-line-activate 'tab-line)
```

In the `wrap` layout, a **current** tab is bold over a `current-background`
box; a **modified** (non-current) tab uses `modified-foreground` (and a
`modified-background` box when set). When a tab is **both**, its box is tinted
with `modified-foreground` — the readable bold label stays, but the unsaved
state stays visible behind the current highlight. With an `:active` predicate,
the whole line switches to the `inactive-*` palette in unfocused windows.

### Styling values

Every colour/font option may be a literal **or a zero-argument function**
evaluated on each render — so theme-dependent colours (e.g. branching on a
dark/light predicate) live in your config and the engine stays theme-agnostic.

### Targets and installation

- `tab-bar` → installs into `tab-bar-format` (frame-wide).
- `mode-line` / `header-line` → `setq-default` the format (per-window).
- `tab-line` → advises the `tab-line-format` *function* (so it catches
  buffers whose `tab-line-format` variable is buffer-local).

`svg-line-deactivate` restores exactly what was there before.

## Icons

Use a **Nerd Font** for the line's `:font` and icons are just text — a
nerd-icons glyph in a segment string flows inline with everything else, one
native SVG `<text>`, font-accurate, with no positioning math. Glyphs render
smaller than a text cell, so svg-line enlarges Private-Use (icon) runs via a
larger `<tspan>` (`svg-line-glyph-scale`, default 1.3):

```elisp
;; a segment that returns a git glyph + the branch, in the same font:
(defun my-vc () (when (vc-backend buffer-file-name)
                  (concat (nerd-icons-devicon "nf-dev-git") " " (my-branch))))
(cons '(my-vc) '(my-clock))
```

No icon font? Any glyph the bar font lacks can fall back via a font list, e.g.
`font-family="Your Font, Symbols Nerd Font Mono"`.

## Progress bars and pies

A `lines` segment may emit a geometric **progress** token, drawn by svg-line
itself (no dependency): `(:svg-bar FRACTION PIXELWIDTH FILL BG)` or
`(:svg-pie FRACTION FILL BG)`:

```elisp
(defun my-progress ()                      ; point's position through the buffer
  (list :svg-pie (/ (float (point)) (point-max)) "#2a4d77" "#d4dcea"))
(cons '(my-buffer-name) '(my-progress))
```

A side containing a bar/pie token is laid out with `:char-advance` spacing;
pure-text sides keep exact font anchoring.

## Text scale

A line image *is* the bar at its exact target pixel width, so it's pinned to
`:scale 1.0` — it never inherits `image-scaling-factor` (which would scale it
with the default font and overflow the frame). To still track the default font
size (`default-text-scale`, or any change to the `default` face height), the
layout **sizes** — font-size, line-pad, padding, char-advance — scale by the
ratio of the current default height to a captured reference, so the line
*re-renders* larger and crisp. Toggle with `svg-line-scale-with-text-scale`
(default on); reset `svg-line--base-text-height` to nil to re-capture the
reference after changing your unscaled default font.

## Safety

Each segment is evaluated **exactly once** (the discipline that avoids
redisplay feedback loops). Rendering is wrapped so a Lisp error shows inline
instead of breaking the display, and a re-entrant render returns the last good
value instead of looping.

## Core API (for power use)

- `svg-line-render-segments` — segment list → string
- `svg-line-image` — `lines` layout → svg object
- `svg-line-wrap-image` — `wrap` layout → svg object
- `svg-line-display` — svg object → display string
- `svg-line-safe` — wrap a render thunk with the error/loop guard

## Tests

```sh
cd test
emacs -Q --batch -L .. -l svg-line-test.el -f ert-run-tests-batch-and-exit
```
