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

Single-font SVG text can't draw icon-font glyphs (all-the-icons, nerd-icons)
— they render as tofu because the font isn't embedded. svg-line instead draws
real **vector** icons as scaled `<path>` groups:

- `svg-line-icon-append` (core, dependency-free) injects already-harvested
  path data — a `viewBox` + path `d` strings — into a composed SVG at a given
  position/size/fill.
- The optional **`svg-line-icons`** add-on bridges to Nicolas Rougier's
  [`svg-lib`](https://github.com/rougier/svg-lib), which fetches and caches
  icon collections (material, octicons, …). Harvests are memoised, and
  `svg-line-icon-data … no-fetch` + `svg-line-icon-prefetch` keep the network
  and svg-lib itself entirely **off the redisplay path**.

In the **`wrap`** layout, each tab takes a leading icon via `:icon`:

```elisp
(cons "1 init.el" (list :current t :icon (svg-line-icon-data "lambda")))
```

In the **`lines`** layout, a segment may *be* (or *return*) an inline icon
or progress-bar token, placed anywhere among the text — `(:svg-icon DATA
FILL)` and `(:svg-bar FRACTION PIXELWIDTH FILL BG)`:

```elisp
(defun my-vc-icon ()                       ; a dynamic inline-icon segment
  (when (vc-backend buffer-file-name)
    (list :svg-icon (svg-line-icon-data "git" "simple") nil)))

(defun my-progress ()                      ; a progress bar of point-in-buffer
  (list :svg-bar (/ (float (point)) (point-max)) 56 "#2a4d77" "#d4dcea"))

;; row: [git] repo:branch ......  <progress>
(cons '(my-vc-icon my-repo-branch) '(my-progress))
```

A side containing any icon/bar token is laid out with `:char-advance`
spacing; pure-text sides keep exact font anchoring.

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
- `svg-line-icon-append` — inject scaled icon paths into an svg object
- `svg-line-safe` — wrap a render thunk with the error/loop guard

## Tests

```sh
cd test
emacs -Q --batch -L .. -l svg-line-test.el -f ert-run-tests-batch-and-exit
```
