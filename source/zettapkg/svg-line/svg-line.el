;;; svg-line.el --- SVG-rendered tab-bar, tab-line, header-line and mode-line -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; URL: https://github.com/<TBD>/svg-line
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience, faces, frames

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; svg-line renders the tab-bar, tab-line, header-line and mode-line as
;; SVG images instead of laid-out text.  An SVG image can be any height
;; and is positioned at exact pixel coordinates, which makes possible
;; things the text engine cannot do uniformly:
;;
;;   - multi-line bars (status info, breadcrumbs) of arbitrary height;
;;   - per-line left/right alignment on EVERY line (not just the last,
;;     and without the `:align-to'-on-a-non-final-line redisplay freeze);
;;   - tab lines that WRAP overflowing tabs onto new rows instead of
;;     truncating or horizontally scrolling.
;;
;; Two layout modes:
;;   `lines'  -- rows of (LEFT . RIGHT); left flush-left, right flush-right.
;;   `wrap'   -- a flow of items wrapped across as many rows as needed,
;;               with per-item "current" highlighting (for tab lines).
;;
;; This package is the rendering ENGINE only -- it ships no content and no
;; colours of its own.  You supply a `:content' function and styling in
;; your config and bind it to a target:
;;
;;   (svg-line-define 'my-mode-line
;;     :target 'mode-line
;;     :content #'my-mode-line-rows          ; -> list of (LEFT . RIGHT)
;;     :active  #'mode-line-window-selected-p
;;     :background        (lambda () my-active-bg)
;;     :inactive-background (lambda () my-inactive-bg))
;;   (svg-line-activate 'my-mode-line)
;;
;; Colour/font options accept a literal value OR a zero-argument function
;; evaluated on every render -- so theme-dependent colours (e.g. branching
;; on a dark/light predicate) live in your config and the engine stays
;; theme-agnostic.
;;
;; The renderers are SAFE: each segment is evaluated exactly once (the
;; discipline that avoids redisplay feedback loops), and rendering is
;; wrapped so a Lisp error shows inline instead of breaking the display
;; and re-entrant renders return the last good value instead of looping.

;;; Code:

(require 'svg)
(require 'cl-lib)
(require 'dom)
(require 'color)

(defgroup svg-line nil
  "SVG-rendered tab-bar, tab-line, header-line and mode-line."
  :group 'convenience
  :prefix "svg-line-")

(defcustom svg-line-font nil
  "Default font family for SVG line text.
nil means use the `default' face family at render time."
  :type '(choice (const :tag "default face family" nil) string))

(defcustom svg-line-font-size 15
  "Default font size, in pixels, for SVG line text."
  :type 'integer)

(defcustom svg-line-line-pad 4
  "Default extra vertical padding, in pixels, added per rendered row."
  :type 'integer)

(defcustom svg-line-char-advance 8
  "Default per-character advance, in pixels, for the `wrap' layout.
Used to decide where tab rows wrap.  Set slightly high so rows wrap
before reaching the right edge rather than clipping."
  :type 'number)

;;;; Value resolution
;; ----------------------------------------------------------------
;; Every styling option may be a literal or a zero-arg function; the
;; function form is what makes theme-dependent colours possible.

(defun svg-line--val (v)
  "Resolve V: call it when it is a function, else return it."
  (if (functionp v) (funcall v) v))

(defun svg-line--color (c)
  "Normalise colour C to a 6-digit \"#RRGGBB\" string for SVG.
Emacs colours are often names or the 12-digit \"#RRRRGGGGBBBB\" form,
which SVG/librsvg does not accept.  Hex forms are converted directly
\(display-independent); names are resolved via `color.el'.  A value that
is already 6-digit hex passes through; nil returns nil."
  (cond
   ((null c) nil)
   ((not (stringp c)) c)
   ((string-match-p "\\`#[0-9a-fA-F]\\{6\\}\\'" c) c)
   ;; 12-digit #RRRRGGGGBBBB -> high byte of each 16-bit channel
   ((string-match "\\`#\\([0-9a-fA-F]\\{4\\}\\)\\([0-9a-fA-F]\\{4\\}\\)\\([0-9a-fA-F]\\{4\\}\\)\\'" c)
    (concat "#" (substring (match-string 1 c) 0 2)
            (substring (match-string 2 c) 0 2)
            (substring (match-string 3 c) 0 2)))
   ;; 3-digit #RGB -> #RRGGBB
   ((string-match "\\`#\\([0-9a-fA-F]\\)\\([0-9a-fA-F]\\)\\([0-9a-fA-F]\\)\\'" c)
    (concat "#" (make-string 2 (aref (match-string 1 c) 0))
            (make-string 2 (aref (match-string 2 c) 0))
            (make-string 2 (aref (match-string 3 c) 0))))
   ;; named colour (or anything else): resolve, else pass through unchanged
   (t (let ((rgb (ignore-errors (color-name-to-rgb c))))
        (if rgb (apply #'color-rgb-to-hex (append rgb '(2))) c)))))

;;;; Segment rendering
;; ----------------------------------------------------------------
;; A "segment" is a string (used verbatim), a zero-arg function (called,
;; result normalised), or anything else (contributes nothing).  A function
;; result may be a string, a tab-bar menu-item `(KEY menu-item STR . _)',
;; a list of such, or nil.  Each segment is evaluated exactly once.

(defun svg-line--menu-item-string (item)
  "Return the display string of a tab-bar menu-item ITEM (its third element).
A plain string is returned verbatim (without round-tripping through
`format-mode-line', which yields \"\" in batch); a mode-line construct is
formatted."
  (let ((s (nth 2 item)))
    (cond ((stringp s) (substring-no-properties s))
          (s (format-mode-line s))
          (t ""))))

(defun svg-line--item->string (r)
  "Normalise a segment result R to a plain string."
  (cond
   ((null r) "")
   ((stringp r) (substring-no-properties r))
   ((and (consp r) (eq (nth 1 r) 'menu-item)) (svg-line--menu-item-string r))
   ((and (consp r) (consp (car r)))
    (mapconcat (lambda (it)
                 (if (and (consp it) (eq (nth 1 it) 'menu-item))
                     (svg-line--menu-item-string it) ""))
               r ""))
   (t (format "%s" r))))

(defun svg-line-render-segments (segments)
  "Render SEGMENTS to one plain string, each evaluated exactly once."
  (mapconcat (lambda (s)
               (cond ((stringp s) s)
                     ((functionp s) (svg-line--item->string (funcall s)))
                     (t "")))
             segments ""))

;;;; Runs -- text interleaved with icons / progress bars
;; ----------------------------------------------------------------
;; A `lines' side may mix text with inline icons and progress bars.  A
;; segment value (or literal) of (:svg-icon DATA FILL) or
;; (:svg-bar FRACTION WIDTH FILL BG) becomes a non-text run; everything
;; else contributes text.  `svg-line--render-runs' lowers a segment list
;; to a run list -- (:text STR), (:icon DATA FILL), (:bar FRAC W FILL BG)
;; -- coalescing adjacent text, each segment evaluated exactly once.

(defun svg-line--render-runs (segments)
  "Lower SEGMENTS to a list of runs, each segment evaluated exactly once.
Run forms: (:text STR), (:icon DATA FILL), (:bar FRACTION WIDTH FILL BG),
\(:pie FRACTION FILL BG)."
  (let ((runs '()) (buf ""))
    (cl-flet ((flush () (when (> (length buf) 0)
                          (push (list :text buf) runs) (setq buf ""))))
      (dolist (s segments)
        (let ((v (cond ((stringp s) s)
                       ((and (consp s) (memq (car s) '(:svg-icon :svg-bar :svg-pie))) s)
                       ((functionp s) (funcall s))
                       (t nil))))
          (cond
           ((and (consp v) (eq (car v) :svg-icon)) (flush) (push (cons :icon (cdr v)) runs))
           ((and (consp v) (eq (car v) :svg-bar))  (flush) (push (cons :bar (cdr v)) runs))
           ((and (consp v) (eq (car v) :svg-pie))  (flush) (push (cons :pie (cdr v)) runs))
           (t (setq buf (concat buf (svg-line--item->string v)))))))
      (flush))
    (nreverse runs)))

(defun svg-line--runs-all-text-p (runs)
  "Non-nil if RUNS are entirely text (so the side can use exact text anchoring)."
  (cl-every (lambda (r) (eq (car r) :text)) runs))

(defun svg-line--run-width (run char-advance fz)
  "Advance width in pixels of a single RUN."
  (pcase (car run)
    (:text (* (length (nth 1 run)) char-advance))
    (:icon (+ (round (svg-line--icon-width (car (nth 1 run)) fz)) (round (* 0.3 fz))))
    (:pie  (+ (round (* fz 0.76)) (round (* 0.3 fz))))   ; diameter + gap
    (:bar  (+ (nth 2 run) (round (* 0.3 fz))))
    (_ 0)))

(defun svg-line--runs-width (runs char-advance fz)
  "Total advance width in pixels of RUNS (for right alignment)."
  (apply #'+ (mapcar (lambda (r) (svg-line--run-width r char-advance fz)) runs)))

;;;; Image builders (public, pure: data in, svg object out)
;; ----------------------------------------------------------------

(defun svg-line--draw-runs (svg runs x top fz lh font char-advance foreground)
  "Draw RUNS left-to-right in SVG starting at X (row top at TOP).
Text advances by CHAR-ADVANCE per character; icons and bars by their own
width.  FOREGROUND is the fallback fill.  Returns the ending x."
  (dolist (run runs)
    (pcase (car run)
      (:text (let ((str (nth 1 run)))
               (when (> (length str) 0)
                 (svg-text svg str :font-family font :font-size fz
                           :fill foreground :x x :y (+ top fz)))))
      (:icon (let ((data (nth 1 run)))
               (svg-line-icon-append svg (cdr data) (car data)
                                     :x (+ x (round (* 0.15 fz)))
                                     :y (+ top (max 0 (/ (- lh fz) 2)))
                                     :size fz :fill (or (nth 2 run) foreground))))
      (:pie  (let* ((frac (max 0.0 (min 1.0 (float (nth 1 run)))))
                    (fill (svg-line--color (or (nth 2 run) foreground)))
                    (bg   (svg-line--color (or (nth 3 run) "#d4dcea")))
                    (r  (* fz 0.38))
                    ;; leading-only gap: the pie's right edge lands at the
                    ;; run end, so a rightmost pie sits flush at the margin.
                    (cx (+ x (round (* 0.3 fz)) r))
                    (cy (+ top (/ lh 2.0))))
               (svg-circle svg cx cy r :fill bg)
               (if (>= frac 0.999)
                   (svg-circle svg cx cy r :fill fill)
                 (when (> frac 0.001)
                   (let* ((theta (* 2 float-pi frac))
                          (ex (+ cx (* r (sin theta))))
                          (ey (- cy (* r (cos theta))))
                          (large (if (> frac 0.5) 1 0)))
                     (dom-append-child
                      svg (dom-node 'path
                                    (list (cons 'd (format "M %g %g L %g %g A %g %g 0 %d 1 %g %g Z"
                                                           cx cy cx (- cy r) r r large ex ey))
                                          (cons 'fill fill)))))))))
      (:bar  (let* ((frac (max 0.0 (min 1.0 (float (nth 1 run)))))
                    (bw (nth 2 run))
                    (fill (or (nth 3 run) foreground))
                    (bg (nth 4 run))
                    (bh (max 3 (round (* fz 0.5))))
                    (by (+ top (max 0 (/ (- lh bh) 2)))))
               (when bg (svg-rectangle svg x by bw bh :fill (svg-line--color bg) :rx 2))
               (svg-rectangle svg x by (max 1 (round (* bw frac))) bh
                              :fill (svg-line--color fill) :rx 2))))
    (setq x (+ x (svg-line--run-width run char-advance fz))))
  x)

;;;###autoload
(cl-defun svg-line-image (rows &key
                               (width 100)
                               (font (or svg-line-font (face-attribute 'default :family nil t)))
                               (font-size svg-line-font-size)
                               (line-pad svg-line-line-pad)
                               (pad 0)
                               (right-margin 0)
                               (char-advance svg-line-char-advance)
                               (foreground "#000000")
                               (background nil))
  "Build a `lines'-layout SVG from ROWS, a list of (LEFT . RIGHT).
Each of LEFT and RIGHT is either:
  - a STRING, drawn with exact font anchoring (flush-left at PAD, or
    flush-right at WIDTH minus RIGHT-MARGIN); or
  - a list of RUNS, drawn with CHAR-ADVANCE spacing so it can carry inline
    icons, pies and progress bars.  A run is (:text STR), (:icon DATA FILL),
    (:pie FRACTION FILL BG) or (:bar FRACTION PIXELWIDTH FILL BG); see
    `svg-line--render-runs'.
Returns an svg object (see `svg-create')."
  (let* ((foreground (svg-line--color foreground))
         (background (svg-line--color background))
         (fz font-size)
         (lh (+ fz line-pad))
         (rx (max 0 (- width right-margin)))
         (height (max 1 (* lh (length rows))))
         (svg (svg-create width height)))
    (when background (svg-rectangle svg 0 0 width height :fill background))
    (cl-loop for (l . r) in rows
             for i from 0
             for top = (* lh i)
             for y = (+ top fz)
             do (progn
                  ;; LEFT: flush-left
                  (cond
                   ((and (stringp l) (> (length l) 0))
                    (svg-text svg l :font-family font :font-size fz
                              :fill foreground :x pad :y y))
                   ((consp l)
                    (svg-line--draw-runs svg l pad top fz lh font char-advance foreground)))
                  ;; RIGHT: flush-right
                  (cond
                   ((and (stringp r) (> (length r) 0))
                    (svg-text svg r :font-family font :font-size fz
                              :fill foreground :x rx :y y :text-anchor "end"))
                   ((consp r)
                    (svg-line--draw-runs svg r (max pad (- rx (svg-line--runs-width r char-advance fz)))
                                         top fz lh font char-advance foreground)))))
    svg))

;;;###autoload
(cl-defun svg-line-wrap-image (items &key
                                     (width 100)
                                     (font (or svg-line-font (face-attribute 'default :family nil t)))
                                     (font-size svg-line-font-size)
                                     (line-pad svg-line-line-pad)
                                     (char-advance svg-line-char-advance)
                                     (gap 3)
                                     (foreground "#000000")
                                     (background nil)
                                     (current-foreground nil)
                                     (current-background nil)
                                     (modified-foreground nil)
                                     (modified-background nil))
  "Build a `wrap'-layout SVG from ITEMS, a list of (LABEL . STATE).
Items flow left-to-right and wrap onto new rows at WIDTH.  GAP is the
inter-item gap in character widths.  Returns an svg object.

STATE selects how each item is styled:
  - nil / non-nil atom  -- treated as CURRENTP (backward compatible);
  - a plist             -- recognised keys `:current', `:modified', and
                           `:icon' (a (VIEWBOX . PATHS) leading icon, drawn
                           in the item's text colour and accounted for in
                           the wrap width).

A current item is drawn bold, in CURRENT-FOREGROUND, over a
CURRENT-BACKGROUND box.  A (non-current) modified item is drawn in
MODIFIED-FOREGROUND, over a MODIFIED-BACKGROUND box when set.  When an
item is BOTH current and modified, its box is tinted with
MODIFIED-FOREGROUND (the readable current label stays, but the unsaved
state remains visible behind the highlight)."
  (let* ((foreground (svg-line--color foreground))
         (background (svg-line--color background))
         (current-foreground (svg-line--color current-foreground))
         (current-background (svg-line--color current-background))
         (modified-foreground (svg-line--color modified-foreground))
         (modified-background (svg-line--color modified-background))
         (fz font-size)
         (lh (+ fz line-pad))
         (x 0) (row 0) (placements nil))
    (dolist (it items)
      (let* ((label (car it))
             (state (cdr it))
             (currentp  (if (consp state) (plist-get state :current) state))
             (modifiedp (and (consp state) (plist-get state :modified)))
             (icon (and (consp state) (plist-get state :icon)))
             ;; icon advance = icon width + a small gap before the label
             (iw (if icon (+ (round (svg-line--icon-width (car icon) fz))
                             (round (* 0.4 fz)))
                   0))
             (lw (* (length label) char-advance))
             (cw (+ iw lw))                          ; full item (box) width
             (w  (+ cw (* gap char-advance))))       ; + inter-item gap
        (when (and (> x 0) (> (+ x w) width))
          (setq x 0 row (1+ row)))
        (push (list x (* row lh) cw iw label currentp modifiedp icon) placements)
        (setq x (+ x w))))
    (let* ((height (max 1 (* (1+ row) lh)))
           (svg (svg-create width height)))
      (when background (svg-rectangle svg 0 0 width height :fill background))
      (dolist (p (nreverse placements))
        (cl-destructuring-bind (px top cw iw label currentp modifiedp icon) p
          (let ((box  (cond ;; current AND modified: tint the current box with the
                            ;; modified accent so "unsaved" stays visible behind
                            ;; the current highlight (the label stays readable).
                            ((and currentp modifiedp) (or modified-foreground current-background))
                            (currentp  current-background)
                            (modifiedp modified-background)))
                (fill (cond (currentp  (or current-foreground foreground))
                            (modifiedp (or modified-foreground foreground))
                            (t foreground))))
            (when box
              (svg-rectangle svg px top cw lh :fill box :rx 3))
            (when icon
              (svg-line-icon-append svg (cdr icon) (car icon)
                                    :x px :y (+ top (max 0 (/ (- lh fz) 2)))
                                    :size fz :fill fill))
            (svg-text svg label :font-family font :font-size fz
                      :fill fill :font-weight (if currentp "bold" "normal")
                      :x (+ px iw) :y (+ top fz)))))
      svg)))

;;;###autoload
(defun svg-line-display (svg)
  "Wrap SVG object as a one-space string carrying it as a display image."
  (propertize " " 'display (svg-image svg :ascent 'center)))

;;;; Icons (generic, dependency-free path injection)
;; ----------------------------------------------------------------
;; Draw real vector icons INTO a composed svg as scaled <path> groups,
;; from already-harvested data (a viewBox + path "d" strings).  This is
;; the primitive the line renderers use; harvesting the data from an icon
;; set is the job of the optional `svg-line-icons' add-on (which bridges
;; to `svg-lib').  Kept here, and free of any icon-set dependency, so the
;; renderers can place icons without the core depending on svg-lib.

(defun svg-line--icon-width (viewbox size)
  "Pixel width of an icon with VIEWBOX (MINX MINY W H) drawn at height SIZE."
  (let ((vw (float (or (nth 2 viewbox) size)))
        (vh (float (or (nth 3 viewbox) size))))
    (* size (/ vw (if (zerop vh) size vh)))))

(defun svg-line-icon-append (svg paths viewbox &rest props)
  "Append icon PATHS to SVG as a positioned, scaled `<g>'; return the group.
PATHS is a list of SVG path \"d\" strings.  VIEWBOX is (MINX MINY W H),
as parsed from the source icon's `viewBox'.  PROPS is a plist:
  :x :y    top-left placement in SVG pixels (default 0, 0);
  :size    target height in pixels, width scales proportionally (default 16);
  :fill    path fill colour (default \"#000000\").
SVG is an svg object from `svg-create' (or any DOM node to append into)."
  (let* ((x    (or (plist-get props :x) 0))
         (y    (or (plist-get props :y) 0))
         (size (or (plist-get props :size) 16))
         (fill (svg-line--color (or (plist-get props :fill) "#000000")))
         (vx (float (or (nth 0 viewbox) 0)))
         (vy (float (or (nth 1 viewbox) 0)))
         (vh (float (or (nth 3 viewbox) size)))
         (s  (/ size (if (zerop vh) size vh)))
         ;; map icon space -> SVG pixels: place at (x,y), scale to `size',
         ;; and shift away the viewBox origin.
         (transform (format "translate(%g,%g) scale(%g) translate(%g,%g)"
                            x y s (- vx) (- vy)))
         (g (dom-node 'g (list (cons 'transform transform)))))
    (dolist (d paths)
      (when (and (stringp d) (> (length d) 0))
        (dom-append-child g (dom-node 'path (list (cons 'd d) (cons 'fill fill))))))
    (dom-append-child svg g)
    g))

;;;; Safety wrapper
;; ----------------------------------------------------------------
;; Guards against (a) a Lisp error in a content function breaking the
;; display, and (b) a render that re-enters the render machinery (a
;; feedback loop), which returns the last good value instead of looping.

(defvar svg-line--rendering nil
  "Non-nil while a line is rendering; blocks re-entrant renders.")
(defvar svg-line--last-good (make-hash-table :test 'eq)
  "Per-line last successfully rendered value, keyed by line name.")

(defun svg-line-safe (name thunk)
  "Call THUNK for line NAME, guarding errors and re-entrancy."
  (if svg-line--rendering
      (gethash name svg-line--last-good " ")
    (let ((svg-line--rendering t))
      (condition-case err
          (puthash name (funcall thunk) svg-line--last-good)
        (error (propertize (format " ⚠ %s: %s " name (error-message-string err))
                           'face 'error))))))

;;;; Line registry + spec resolution
;; ----------------------------------------------------------------

(defvar svg-line--registry (make-hash-table :test 'eq)
  "Map of line NAME -> plist with :spec :renderer :saved keys.")

(defun svg-line--entry (name)
  "Return the registry entry for NAME, or nil."
  (gethash name svg-line--registry))

(defun svg-line--spec (name)
  "Return the spec plist for line NAME."
  (plist-get (svg-line--entry name) :spec))

(defun svg-line--opt (spec key &optional default)
  "Resolve option KEY from SPEC (value-or-function), else DEFAULT."
  (let ((v (plist-member spec key)))
    (if v (svg-line--val (cadr v)) default)))

(defun svg-line--width (spec)
  "Resolve the pixel width for SPEC."
  (let ((w (or (plist-get spec :width)
               (if (eq (plist-get spec :target) 'tab-bar) 'frame 'window))))
    (max 1 (pcase w
             ('frame (frame-inner-width))
             ('window (window-pixel-width))
             ((pred functionp) (funcall w))
             ((pred integerp) w)
             (_ 100)))))

(defun svg-line--active-p (spec)
  "Return non-nil if SPEC's `:active' predicate is absent or holds."
  (let ((p (plist-get spec :active)))
    (or (null p) (funcall p))))

;;;; Per-spec builders
;; ----------------------------------------------------------------

(defun svg-line--side (segments)
  "Render SEGMENTS to a side value: a plain string if all text, else a run list."
  (let ((runs (svg-line--render-runs segments)))
    (if (svg-line--runs-all-text-p runs)
        (mapconcat (lambda (r) (nth 1 r)) runs "")
      runs)))

(defun svg-line--build-lines (spec)
  "Build the `lines' SVG for SPEC.
Each content row is (LEFT-SEGMENTS . RIGHT-SEGMENTS).  A segment may emit
an inline icon (:svg-icon DATA FILL) or progress bar (:svg-bar ...) token
\(see `svg-line--render-runs'); a side with any such token is laid out with
CHAR-ADVANCE spacing, otherwise with exact text anchoring."
  (let* ((active (svg-line--active-p spec))
         (fg (or (and (not active) (svg-line--opt spec :inactive-foreground))
                 (svg-line--opt spec :foreground "#000000")))
         (bg (if active
                 (svg-line--opt spec :background)
               (or (svg-line--opt spec :inactive-background)
                   (svg-line--opt spec :background)))))
    (svg-line-image
     (mapcar (lambda (r)
               (cons (svg-line--side (car r)) (svg-line--side (cdr r))))
             (funcall (plist-get spec :content)))
     :width (svg-line--width spec)
     :font (svg-line--opt spec :font
                          (or svg-line-font (face-attribute 'default :family nil t)))
     :font-size (svg-line--opt spec :font-size svg-line-font-size)
     :line-pad (svg-line--opt spec :line-pad svg-line-line-pad)
     :pad (svg-line--opt spec :pad 0)
     :right-margin (svg-line--opt spec :right-margin 0)
     :char-advance (svg-line--opt spec :char-advance svg-line-char-advance)
     :foreground fg
     :background bg)))

(defun svg-line--build-wrap (spec)
  "Build the `wrap' SVG for SPEC.
When SPEC has an `:active' predicate that is false, the inactive variant
of each colour applies (falling back to the active colour when unset),
mirroring the `lines' layout."
  (let* ((active (svg-line--active-p spec))
         (pick (lambda (key inactive-key &optional default)
                 (if active
                     (svg-line--opt spec key default)
                   (or (svg-line--opt spec inactive-key)
                       (svg-line--opt spec key default))))))
    (svg-line-wrap-image (funcall (plist-get spec :content))
                         :width (svg-line--width spec)
                         :font (svg-line--opt spec :font
                                              (or svg-line-font (face-attribute 'default :family nil t)))
                         :font-size (svg-line--opt spec :font-size svg-line-font-size)
                         :line-pad (svg-line--opt spec :line-pad svg-line-line-pad)
                         :char-advance (svg-line--opt spec :char-advance svg-line-char-advance)
                         :gap (svg-line--opt spec :gap 3)
                         :foreground (funcall pick :foreground :inactive-foreground "#000000")
                         :background (funcall pick :background :inactive-background)
                         :current-foreground (funcall pick :current-foreground :inactive-current-foreground)
                         :current-background (funcall pick :current-background :inactive-current-background)
                         :modified-foreground (funcall pick :modified-foreground :inactive-modified-foreground)
                         :modified-background (funcall pick :modified-background :inactive-modified-background))))

(defun svg-line--render (name)
  "Render line NAME to a display string (error/loop guarded)."
  (svg-line-safe
   name
   (lambda ()
     (let* ((spec (svg-line--spec name))
            (svg (pcase (or (plist-get spec :layout) 'lines)
                   ('wrap (svg-line--build-wrap spec))
                   (_     (svg-line--build-lines spec)))))
       (svg-line-display svg)))))

(defun svg-line--renderer (name)
  "Return (creating if needed) the named renderer function symbol for NAME."
  (let ((sym (intern (format "svg-line-render/%s" name))))
    (defalias sym (lambda () (svg-line--render name))
      (format "Render the `%s' svg-line (made by `svg-line-define')." name))
    sym))

;;;; Definition + activation
;; ----------------------------------------------------------------

;;;###autoload
(defun svg-line-define (name &rest spec)
  "Define an svg-line NAME from SPEC (a plist) and create its renderer.
Recognised SPEC keys:
  :target  one of `tab-bar' `mode-line' `header-line' `tab-line' (required)
  :layout  `lines' (default) or `wrap'
  :content a function returning the line's content (required):
             - for `lines': a list of (LEFT-SEGMENTS . RIGHT-SEGMENTS); a
               segment may be a string, a function, or an inline icon
               (:svg-icon DATA FILL), pie (:svg-pie FRAC FILL BG) or
               progress-bar (:svg-bar FRAC W FILL BG) token (or a function
               returning one)
             - for `wrap':  a list of (LABEL . STATE), where STATE is a
               CURRENTP atom or a plist with `:current'/`:modified'/`:icon'
               keys (`:icon' is a (VIEWBOX . PATHS) leading tab icon)
  :width   `frame', `window', an integer, or a function (default by target)
  :font :font-size :line-pad :pad :right-margin :char-advance
  :foreground :background
  :active   a predicate; when present and false, inactive variants apply
  :inactive-foreground :inactive-background
  `wrap' only:
  :gap
  :current-foreground :current-background
  :modified-foreground :modified-background
  :inactive-current-foreground :inactive-current-background
  :inactive-modified-foreground :inactive-modified-background
Each styling value may be a literal or a zero-arg function,
evaluated on every render."
  (unless (plist-get spec :target)
    (error "svg-line-define: %s needs a :target" name))
  (unless (functionp (plist-get spec :content))
    (error "svg-line-define: %s needs a :content function" name))
  (let ((entry (or (svg-line--entry name) (list :saved nil))))
    (setq entry (plist-put entry :spec spec))
    (setq entry (plist-put entry :renderer (svg-line--renderer name)))
    (puthash name entry svg-line--registry))
  name)

(defun svg-line--install (name)
  "Install line NAME's renderer on its target, saving the prior value."
  (let* ((entry (svg-line--entry name))
         (spec (plist-get entry :spec))
         (sym (plist-get entry :renderer))
         (target (plist-get spec :target)))
    (pcase target
      ('tab-bar
       (setq entry (plist-put entry :saved (cons 'value tab-bar-format)))
       (setq tab-bar-format (list sym)))
      ('mode-line
       (setq entry (plist-put entry :saved (cons 'value (default-value 'mode-line-format))))
       (setq-default mode-line-format `((:eval (,sym)))))
      ('header-line
       (setq entry (plist-put entry :saved (cons 'value (default-value 'header-line-format))))
       (setq-default header-line-format `((:eval (,sym)))))
      ('tab-line
       ;; tab-line-format is buffer-local in many buffers but always calls
       ;; the `tab-line-format' FUNCTION, so override that to catch them all.
       (setq entry (plist-put entry :saved (cons 'advice sym)))
       (advice-add 'tab-line-format :override sym))
      (_ (error "svg-line: unknown :target %S" target)))
    (puthash name entry svg-line--registry)
    (force-mode-line-update t)))

(defun svg-line--uninstall (name)
  "Restore line NAME's target to the value saved at install time."
  (let* ((entry (svg-line--entry name))
         (spec (plist-get entry :spec))
         (saved (plist-get entry :saved))
         (target (plist-get spec :target)))
    (when saved
      (pcase (cons target (car saved))
        (`(tab-bar . value)     (setq tab-bar-format (cdr saved)))
        (`(mode-line . value)   (setq-default mode-line-format (cdr saved)))
        (`(header-line . value) (setq-default header-line-format (cdr saved)))
        (`(tab-line . advice)   (advice-remove 'tab-line-format (cdr saved))))
      (setq entry (plist-put entry :saved nil))
      (puthash name entry svg-line--registry))
    (force-mode-line-update t)))

;;;###autoload
(defun svg-line-active-p (name)
  "Return non-nil if line NAME is currently installed on its target."
  (and (svg-line--entry name)
       (plist-get (svg-line--entry name) :saved)
       t))

;;;###autoload
(defun svg-line-activate (name)
  "Activate the svg-line NAME on its target."
  (interactive)
  (unless (svg-line--entry name)
    (error "svg-line-activate: no line named %S (use `svg-line-define')" name))
  (unless (svg-line-active-p name)
    (svg-line--install name))
  name)

;;;###autoload
(defun svg-line-deactivate (name)
  "Deactivate the svg-line NAME, restoring its target."
  (interactive)
  (when (svg-line-active-p name)
    (svg-line--uninstall name))
  name)

;;;###autoload
(defun svg-line-toggle (name)
  "Toggle the svg-line NAME on its target."
  (interactive)
  (if (svg-line-active-p name)
      (svg-line-deactivate name)
    (svg-line-activate name)))

(provide 'svg-line)
;;; svg-line.el ends here
