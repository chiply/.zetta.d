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

;;;; Image builders (public, pure: data in, svg object out)
;; ----------------------------------------------------------------

;;;###autoload
(cl-defun svg-line-image (rows &key
                               (width 100)
                               (font (or svg-line-font (face-attribute 'default :family nil t)))
                               (font-size svg-line-font-size)
                               (line-pad svg-line-line-pad)
                               (pad 0)
                               (right-margin 0)
                               (foreground "#000000")
                               (background nil))
  "Build a `lines'-layout SVG from ROWS, a list of (LEFT . RIGHT) strings.
LEFT is drawn flush-left at PAD; RIGHT is drawn flush-right (anchored at
WIDTH minus RIGHT-MARGIN).  Returns an svg object (see `svg-create')."
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
             for y = (+ (* lh i) fz)
             do (progn
                  (when (and (stringp l) (> (length l) 0))
                    (svg-text svg l :font-family font :font-size fz
                              :fill foreground :x pad :y y))
                  (when (and (stringp r) (> (length r) 0))
                    (svg-text svg r :font-family font :font-size fz
                              :fill foreground :x rx :y y :text-anchor "end"))))
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
  - a plist             -- recognised keys `:current' and `:modified'.

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
             (lw (* (length label) char-advance))
             (w  (+ lw (* gap char-advance))))
        (when (and (> x 0) (> (+ x w) width))
          (setq x 0 row (1+ row)))
        (push (list x (* row lh) lw label currentp modifiedp) placements)
        (setq x (+ x w))))
    (let* ((height (max 1 (* (1+ row) lh)))
           (svg (svg-create width height)))
      (when background (svg-rectangle svg 0 0 width height :fill background))
      (dolist (p (nreverse placements))
        (cl-destructuring-bind (px top lw label currentp modifiedp) p
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
              (svg-rectangle svg px top lw lh :fill box :rx 3))
            (svg-text svg label :font-family font :font-size fz
                      :fill fill :font-weight (if currentp "bold" "normal")
                      :x px :y (+ top fz)))))
      svg)))

;;;###autoload
(defun svg-line-display (svg)
  "Wrap SVG object as a one-space string carrying it as a display image."
  (propertize " " 'display (svg-image svg :ascent 'center)))

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

(defun svg-line--build-lines (spec)
  "Build the `lines' SVG for SPEC."
  (let* ((active (svg-line--active-p spec))
         (fg (or (and (not active) (svg-line--opt spec :inactive-foreground))
                 (svg-line--opt spec :foreground "#000000")))
         (bg (if active
                 (svg-line--opt spec :background)
               (or (svg-line--opt spec :inactive-background)
                   (svg-line--opt spec :background))))
         (rows (mapcar (lambda (r)
                         (cons (svg-line-render-segments (car r))
                               (svg-line-render-segments (cdr r))))
                       (funcall (plist-get spec :content)))))
    (svg-line-image rows
                    :width (svg-line--width spec)
                    :font (svg-line--opt spec :font
                                         (or svg-line-font (face-attribute 'default :family nil t)))
                    :font-size (svg-line--opt spec :font-size svg-line-font-size)
                    :line-pad (svg-line--opt spec :line-pad svg-line-line-pad)
                    :pad (svg-line--opt spec :pad 0)
                    :right-margin (svg-line--opt spec :right-margin 0)
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
             - for `lines': a list of (LEFT-SEGMENTS . RIGHT-SEGMENTS)
             - for `wrap':  a list of (LABEL . STATE), where STATE is a
               CURRENTP atom or a plist with `:current'/`:modified' keys
  :width   `frame', `window', an integer, or a function (default by target)
  :font :font-size :line-pad :pad :right-margin
  :foreground :background
  :active   a predicate; when present and false, inactive variants apply
  :inactive-foreground :inactive-background
  `wrap' only:
  :char-advance :gap
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
