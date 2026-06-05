;;; svg-line-icons.el --- Optional svg-lib icon bridge for svg-line -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; URL: https://github.com/<TBD>/svg-line
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (svg-lib "0.3"))
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
;; OPTIONAL add-on for svg-line: draw real vector icons INTO an svg-line
;; SVG, as scaled `<path>' groups.  This overcomes the core engine's
;; single-font limitation -- icon-font glyphs (all-the-icons, nerd-icons)
;; render as tofu in librsvg because the font is not embedded, whereas a
;; vector `<path>' draws correctly.
;;
;; Two layers:
;;
;;   - `svg-line-icon-append' -- GENERIC and dependency-free: given raw
;;     path data (a viewBox + a list of path "d" strings), append a
;;     positioned, scaled `<g>' of `<path>' nodes to an existing svg
;;     object.  No network, no svg-lib; unit-testable offline.
;;
;;   - `svg-line-icon-data' / `svg-line-icon' / `svg-line-icon-image' --
;;     a BRIDGE to Nicolas Rougier's `svg-lib', which fetches and caches
;;     icon SVGs from its `svg-lib-icon-collections' (bootstrap, material,
;;     octicons, ...).  These harvest the viewBox + paths and hand them to
;;     the generic layer.
;;
;; svg-lib is an OPTIONAL dependency: it is required lazily, only when a
;; bridge function is actually called, so the svg-line core never pulls
;; it in.  The first render of a not-yet-cached icon fetches it over the
;; network (synchronously) and caches it under `svg-lib-icons-dir'.

;;; Code:

(require 'svg)
(require 'dom)
(require 'xml)
(require 'svg-line)

(declare-function svg-lib--icon-get-data "svg-lib" (collection name &optional force-reload))
(defvar svg-lib-icon-collections)

(defcustom svg-line-icon-default-collection "material"
  "Default `svg-lib' icon collection used when none is given.
See `svg-lib-icon-collections' for the available collection names."
  :type 'string
  :group 'svg-line)

;;;; Generic layer (no svg-lib) -- inject scaled path data into an svg
;; ----------------------------------------------------------------

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

;;;; svg-lib bridge -- harvest icon data, then use the generic layer
;; ----------------------------------------------------------------

(defun svg-line-icon-data (name &optional collection)
  "Return (VIEWBOX . PATHS) for icon NAME in COLLECTION, via `svg-lib'.
VIEWBOX is (MINX MINY W H); PATHS is a list of path \"d\" strings.
COLLECTION defaults to `svg-line-icon-default-collection'.  Requires
`svg-lib'; may fetch and cache the icon over the network on first use."
  (require 'svg-lib)
  (let* ((collection (or collection svg-line-icon-default-collection))
         (root (car (svg-lib--icon-get-data collection name)))
         (vb (and root (cdr (assq 'viewBox (xml-node-attributes root)))))
         (viewbox (and vb (mapcar #'string-to-number (split-string vb))))
         (paths (and root
                     (delq nil (mapcar (lambda (n) (cdr (assq 'd (xml-node-attributes n))))
                                       (xml-get-children root 'path))))))
    (cons (or viewbox '(0 0 24 24)) paths)))

(defun svg-line-icon (svg name &rest props)
  "Harvest icon NAME via `svg-lib' and append it to SVG.
PROPS accepts :collection plus the :x :y :size :fill of
`svg-line-icon-append' (which ignores :collection)."
  (let ((data (svg-line-icon-data name (plist-get props :collection))))
    (apply #'svg-line-icon-append svg (cdr data) (car data) props)))

(defun svg-line-icon-image (name &rest props)
  "Build a standalone square SVG showing icon NAME; return a display string.
For testing / standalone use.  PROPS: :collection :size :fill :background
:pad (default 2px).  Uses the same icon harvesting as `svg-line-icon'."
  (let* ((size (or (plist-get props :size) 16))
         (pad  (or (plist-get props :pad) 2))
         (dim  (+ size (* 2 pad)))
         (bg   (svg-line--color (plist-get props :background)))
         (svg  (svg-create dim dim)))
    (when bg (svg-rectangle svg 0 0 dim dim :fill bg))
    (apply #'svg-line-icon svg name :x pad :y pad :size size props)
    (svg-line-display svg)))

(provide 'svg-line-icons)
;;; svg-line-icons.el ends here
