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

A `wrap` tab-line whose `:content` returns `(LABEL . CURRENTP)` items:

```elisp
(svg-line-define 'tab-line
  :target 'tab-line :layout 'wrap
  :content #'my-tab-line-items
  :background "#eef3fc"
  :current-background "#2a4d77" :current-foreground "#ffffff")
(svg-line-activate 'tab-line)
```

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
