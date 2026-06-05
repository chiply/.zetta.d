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

;; The dependency-free path-injection primitive `svg-line-icon-append'
;; (and `svg-line--icon-width') live in the svg-line core, so the line
;; renderers can draw icons without depending on svg-lib.  This file only
;; HARVESTS icon data from svg-lib and hands it to that primitive.

;;;; Harvest cache + non-blocking fetch policy
;; ----------------------------------------------------------------
;; Harvesting reads+parses a cached SVG file, and an UNcached icon would
;; fetch synchronously over the network -- neither is acceptable on the
;; redisplay path.  So harvested data is memoised, and `svg-line-icon-data'
;; can run in a NO-FETCH mode that returns nil for not-yet-cached icons;
;; `svg-line-icon-prefetch' warms the cache from an idle timer instead.

(defvar svg-line-icon--cache (make-hash-table :test 'equal)
  "Memoised (VIEWBOX . PATHS) harvests, keyed by \"COLLECTION/NAME\".")

(defvar svg-line-icon--pending (make-hash-table :test 'equal)
  "Keys with an in-flight idle prefetch, to avoid scheduling duplicates.")

(defun svg-line-icon--cache-file (collection name)
  "Path svg-lib would cache icon NAME of COLLECTION at (without fetching)."
  (expand-file-name (format "%s_%s.svg" collection name)
                    (or (bound-and-true-p svg-lib-icons-dir)
                        (expand-file-name "svg-lib/" user-emacs-directory))))

(defun svg-line-icon-data (name &optional collection no-fetch)
  "Return (VIEWBOX . PATHS) for icon NAME in COLLECTION, via `svg-lib'.
VIEWBOX is (MINX MINY W H); PATHS is a list of path \"d\" strings.
COLLECTION defaults to `svg-line-icon-default-collection'.

Results are memoised.  When NO-FETCH is non-nil and the icon is not
already cached (in memory or on disk), return nil instead of fetching --
so this is safe to call on the redisplay path.  Otherwise it may read the
disk cache, or fetch+cache over the network on first use.

A memoised result is returned WITHOUT loading `svg-lib', so a warm render
path never pulls in svg-lib."
  (let* ((collection (or collection svg-line-icon-default-collection))
         (key (concat collection "/" name)))
    (or (gethash key svg-line-icon--cache)
        (progn
          (require 'svg-lib)
          (when (or (not no-fetch)
                    (file-exists-p (svg-line-icon--cache-file collection name)))
            (let* ((root (car (ignore-errors (svg-lib--icon-get-data collection name))))
                   (vb (and root (cdr (assq 'viewBox (xml-node-attributes root)))))
                   (viewbox (and vb (mapcar #'string-to-number (split-string vb))))
                   (paths (and root
                               (delq nil (mapcar (lambda (n) (cdr (assq 'd (xml-node-attributes n))))
                                                 (xml-get-children root 'path)))))
                   (data (cons (or viewbox '(0 0 24 24)) paths)))
              (puthash key data svg-line-icon--cache)
              data))))))

(defun svg-line-icon-prefetch (name &optional collection)
  "Warm the cache for icon NAME of COLLECTION from an idle timer.
Does nothing if it is already cached or a prefetch is already scheduled.
On completion, requests a mode-line update so a later render picks it up."
  (let* ((collection (or collection svg-line-icon-default-collection))
         (key (concat collection "/" name)))
    (unless (or (gethash key svg-line-icon--cache)
                (gethash key svg-line-icon--pending))
      (puthash key t svg-line-icon--pending)
      (run-with-idle-timer
       0.3 nil
       (lambda ()
         (ignore-errors (svg-line-icon-data name collection)) ; fetch allowed here
         (remhash key svg-line-icon--pending)
         (force-mode-line-update t))))))

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
