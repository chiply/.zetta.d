;;; svg-margin.el --- Multi-provider SVG indicators in the window margins -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; URL: https://github.com/chiply/svg-margin
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
;; svg-margin turns the window margins into a flexible, multi-column gutter
;; that many independent sources ("providers") can draw into, with their
;; indicators packed side by side on the same line.  Unlike the fringe --
;; which renders only monochrome bitmaps and shows a single bitmap per line
;; per side -- a margin can display arbitrary SVG, and svg-margin composites
;; every indicator for a line/side into ONE SVG image at exact pixel
;; coordinates.  Both the left and right margins are supported.
;;
;; This is the rendering ENGINE only.  It ships no providers; you (or a
;; small adapter) supply them.  A provider is just a function of one
;; argument BUFFER that returns a list of indicator plists:
;;
;;   (svg-margin-register-provider 'todo
;;     (lambda (_buffer)
;;       (list (list :line 10 :shape 'dot   :color "#cc3333")
;;             (list :line 10 :shape 'bar   :color "#3333cc" :column 1)
;;             (list :line 25 :text "a"     :side 'left :face 'warning))))
;;   (svg-margin-mode 1)
;;
;; An indicator plist recognises:
;;   :pos / :line  buffer position or 1-based line (one is required)
;;   :side         `left' (default `svg-margin-default-side') or `right'
;;   :column       explicit slot (0 = nearest the text); else auto-packed
;;   :priority     higher is packed first (default 0)
;;   :shape        a registered shape symbol (see `svg-margin-define-shape')
;;   :text         a short string drawn centred (e.g. an evil mark letter)
;;   :draw         a function (SVG X Y W H COLOR) for full control
;;   :color/:face  fill colour, or a face whose foreground is used
;;   :help         tooltip string
;;
;; Indicators sharing a (line, side) are packed into columns and drawn into
;; a single composite SVG; the margin width on that side grows to the widest
;; line.  Providers are decoupled, so several packages can contribute to the
;; same gutter and stack on one line.
;;
;; To move what a package draws in the fringe into the margin instead, write
;; a provider that reads that package's data (e.g. evil's `evil-markers-alist')
;; and set `svg-margin-disable-fringe' to reclaim the fringe space.  See the
;; examples/ directory.

;;; Code:

(require 'svg)
(require 'cl-lib)
(require 'color)
(require 'subr-x)

(defgroup svg-margin nil
  "Multi-provider SVG indicators in the window margins."
  :group 'convenience
  :prefix "svg-margin-")

(defcustom svg-margin-column-width 1
  "Width of one indicator column, in character cells.
The reserved margin width (in columns, as `set-window-margins' measures it)
is this value times the number of indicator columns on the widest line."
  :type 'integer)

(defcustom svg-margin-default-side 'left
  "Default margin side for indicators that do not specify `:side'."
  :type '(choice (const left) (const right)))

(defcustom svg-margin-disable-fringe nil
  "Which window fringe(s) svg-margin collapses to 0 while active.
nil leaves the fringe alone; `left', `right', `both' (or t) zero the
named fringe(s) so the margin reclaims the space.  Restored on mode exit.
Note: zeroing a fringe also hides its truncation/continuation arrows."
  :type '(choice (const :tag "Leave fringe alone" nil)
                 (const left) (const right)
                 (const :tag "Both" both) (const :tag "Both (t)" t)))

(defcustom svg-margin-idle-delay 0.1
  "Idle seconds to coalesce changes before re-rendering a buffer."
  :type 'number)

;;;; Colour
;; ----------------------------------------------------------------

(defun svg-margin--color (c)
  "Normalise colour C to a 6-digit \"#RRGGBB\" string for SVG, else nil.
Names and the 12-digit \"#RRRRGGGGBBBB\" form are resolved via `color.el';
6-digit hex passes through; nil returns nil."
  (cond
   ((null c) nil)
   ((not (stringp c)) c)
   ((string-match-p "\\`#[0-9a-fA-F]\\{6\\}\\'" c) c)
   (t (let ((rgb (ignore-errors (color-name-to-rgb c))))
        (if rgb (apply #'color-rgb-to-hex (append rgb '(2))) c)))))

;;;; Shape registry
;; ----------------------------------------------------------------
;; The SVG analogue of `define-fringe-bitmap': a named drawing function
;; (SVG X Y W H COLOR) that fills the cell rectangle [X,X+W] x [Y,Y+H].

(defvar svg-margin--shapes (make-hash-table :test 'eq)
  "Map of shape NAME symbol -> drawing function (SVG X Y W H COLOR).")

(defun svg-margin-define-shape (name fn)
  "Register drawing FN under shape NAME (a symbol).
FN is called as (FN SVG X Y W H COLOR) and should draw within the cell
rectangle whose top-left is (X, Y) and size is W by H pixels."
  (puthash name fn svg-margin--shapes))

(defun svg-margin--shape-dot (svg x y w h color)
  "Draw a filled dot of COLOR centred in the (X Y W H) cell of SVG."
  (svg-circle svg (+ x (/ w 2.0)) (+ y (/ h 2.0)) (* (min w h) 0.30)
              :fill (svg-margin--color color)))

(defun svg-margin--shape-bar (svg x y w h color)
  "Draw a vertical bar of COLOR spanning the height of the (X Y W H) cell of SVG."
  (svg-rectangle svg (+ x (round (* w 0.12))) y (max 2 (round (* w 0.34))) h
                 :rx 1 :fill (svg-margin--color color)))

(defun svg-margin--shape-box (svg x y w h color)
  "Draw a rounded filled box of COLOR centred in the (X Y W H) cell of SVG."
  (let ((s (* (min w h) 0.6)))
    (svg-rectangle svg (+ x (/ (- w s) 2.0)) (+ y (/ (- h s) 2.0)) s s
                   :rx 2 :fill (svg-margin--color color))))

(defun svg-margin--shape-triangle (svg x y w h color)
  "Draw a right-pointing triangle of COLOR centred in the (X Y W H) cell of SVG."
  (let* ((cx (+ x (/ w 2.0))) (cy (+ y (/ h 2.0))) (r (* (min w h) 0.34)))
    (svg-polygon svg (list (cons (- cx r) (- cy r))
                           (cons (+ cx r) cy)
                           (cons (- cx r) (+ cy r)))
                 :fill (svg-margin--color color))))

(dolist (s '((dot . svg-margin--shape-dot)
             (circle . svg-margin--shape-dot)
             (bar . svg-margin--shape-bar)
             (box . svg-margin--shape-box)
             (triangle . svg-margin--shape-triangle)))
  (svg-margin-define-shape (car s) (cdr s)))

;;;; Providers
;; ----------------------------------------------------------------

(defvar svg-margin--providers nil
  "Alist of (NAME . FUNCTION); each FUNCTION maps a buffer to indicators.")

(defun svg-margin-register-provider (name fn)
  "Register provider FN under NAME (a symbol), replacing any prior one.
FN is called with one argument, the buffer, and returns a list of
indicator plists (see Commentary).  Registered buffers are re-rendered."
  (setf (alist-get name svg-margin--providers) fn)
  (svg-margin-refresh-all))

(defun svg-margin-unregister-provider (name)
  "Remove the provider registered under NAME and re-render."
  (setq svg-margin--providers (assq-delete-all name svg-margin--providers))
  (svg-margin-refresh-all))

;;;; Collection, normalisation, grouping
;; ----------------------------------------------------------------

(defun svg-margin--normalize (ind)
  "Return a normalised copy of indicator IND, or nil if it has no position.
The result carries a `:pos' at beginning-of-line and a `:side' of `left'
or `right'."
  (let* ((pos (or (plist-get ind :pos)
                  (and (plist-get ind :line)
                       (save-excursion
                         (goto-char (point-min))
                         (forward-line (1- (plist-get ind :line)))
                         (point)))))
         (side (or (plist-get ind :side) svg-margin-default-side)))
    (when (and pos (<= (point-min) pos (point-max)))
      (let ((bol (save-excursion (goto-char pos) (line-beginning-position))))
        (append (list :pos bol :side (if (memq side '(right right-margin)) 'right 'left))
                ind)))))

(defun svg-margin--collect ()
  "Run every provider against the current buffer and return all indicators."
  (let ((buf (current-buffer)) (out nil))
    (dolist (p svg-margin--providers)
      (condition-case err
          (dolist (ind (funcall (cdr p) buf))
            (when-let* ((n (svg-margin--normalize ind)))
              (push n out)))
        (error (message "svg-margin: provider %s failed: %s"
                        (car p) (error-message-string err)))))
    out))

(defun svg-margin--group (indicators)
  "Group INDICATORS into a hash keyed by (POS . SIDE) -> list of indicators."
  (let ((h (make-hash-table :test 'equal)))
    (dolist (ind indicators)
      (push ind (gethash (cons (plist-get ind :pos) (plist-get ind :side)) h)))
    h))

(defun svg-margin--pack-columns (indicators)
  "Assign each of INDICATORS a column, packing them side by side.
Higher `:priority' is placed first.  An explicit free `:column' is
honoured; otherwise the lowest unoccupied column is used.  Returns a list
of (:indicator IND :column N)."
  (let ((sorted (sort (copy-sequence indicators)
                      (lambda (a b) (> (or (plist-get a :priority) 0)
                                       (or (plist-get b :priority) 0)))))
        (used nil) (result nil))
    (dolist (ind sorted)
      (let ((col (plist-get ind :column)))
        (when (or (null col) (memq col used))
          (setq col 0)
          (while (memq col used) (setq col (1+ col))))
        (push col used)
        (push (list :indicator ind :column col) result)))
    (nreverse result)))

(defun svg-margin--max-column (packed)
  "Return the number of columns occupied by PACKED (max column + 1)."
  (1+ (apply #'max -1 (mapcar (lambda (c) (plist-get c :column)) packed))))

;;;; Drawing
;; ----------------------------------------------------------------

(defun svg-margin--indicator-color (ind)
  "Return the fill colour for indicator IND from `:color' or `:face'."
  (or (plist-get ind :color)
      (let ((f (plist-get ind :face)))
        (and f (face-foreground f nil 'default)))
      (face-foreground 'default nil 'default)
      "#000000"))

(defun svg-margin--draw-text (svg text x y w h color)
  "Draw TEXT centred in the (X Y W H) cell of SVG in COLOR."
  (let ((fs (max 6 (round (* h 0.7)))))
    (svg-text svg text
              :x (+ x (/ w 2.0))
              :y (+ y (/ h 2.0) (* (max 6 (round (* h 0.7))) 0.35))
              :font-size fs
              :font-family (face-attribute 'default :family nil t)
              :font-weight "bold"
              :text-anchor "middle"
              :fill (svg-margin--color color))))

(defun svg-margin--draw (ind svg x y w h)
  "Draw indicator IND into the (X Y W H) cell of SVG."
  (let ((color (svg-margin--indicator-color ind)))
    (cond
     ((plist-get ind :draw) (funcall (plist-get ind :draw) svg x y w h color))
     ((plist-get ind :text) (svg-margin--draw-text svg (plist-get ind :text) x y w h color))
     ((gethash (plist-get ind :shape) svg-margin--shapes)
      (funcall (gethash (plist-get ind :shape) svg-margin--shapes) svg x y w h color))
     (t (svg-margin--shape-dot svg x y w h color)))))

(defun svg-margin--line-height ()
  "Pixel height of a default line in the selected frame."
  (max 1 (default-line-height)))

(defun svg-margin--image (packed side ncols)
  "Build the composite margin image for PACKED cells on SIDE.
NCOLS is the number of columns to reserve; column 0 is nearest the buffer
text on either side."
  (let* ((cw (* svg-margin-column-width (frame-char-width)))
         (h (svg-margin--line-height))
         (w (max 1 (* ncols cw)))
         (svg (svg-create w h)))
    (dolist (cell packed)
      (let* ((col (plist-get cell :column))
             (ind (plist-get cell :indicator))
             (x (if (eq side 'left) (* (- ncols 1 col) cw) (* col cw))))
        (svg-margin--draw ind svg x 0 cw h)))
    (svg-image svg :ascent 'center :scale 1.0)))

;;;; Overlays
;; ----------------------------------------------------------------

(defvar-local svg-margin--overlays nil
  "List of overlays this buffer uses to carry margin images.")

(defun svg-margin--clear ()
  "Delete all svg-margin overlays in the current buffer."
  (mapc #'delete-overlay svg-margin--overlays)
  (setq svg-margin--overlays nil))

(defun svg-margin--place (pos side packed ncols)
  "Create an overlay at POS carrying the composite SIDE image for PACKED.
NCOLS is the number of columns the image spans."
  (let* ((img (svg-margin--image packed side ncols))
         (marg (if (eq side 'left) 'left-margin 'right-margin))
         (help (string-join
                (delq nil (mapcar (lambda (c) (plist-get (plist-get c :indicator) :help))
                                  packed))
                "\n"))
         ;; Put the image descriptor DIRECTLY as the margin spec's element;
         ;; wrapping it in a string (((margin SIDE) STRING)) reserves the
         ;; margin space but does not render the nested image.
         (str (propertize " " 'display (list (list 'margin marg) img)))
         (ov (make-overlay pos pos)))
    (when (> (length help) 0) (setq str (propertize str 'help-echo help)))
    (overlay-put ov 'svg-margin t)
    (overlay-put ov 'before-string str)
    ;; NB: do NOT set `evaporate' -- these overlays are zero-length, and an
    ;; evaporate overlay is auto-deleted the instant it is empty, so it would
    ;; vanish before display.  `svg-margin--clear' rebuilds them each render.
    (push ov svg-margin--overlays)))

;;;; Window geometry (margins + fringes)
;; ----------------------------------------------------------------

(defun svg-margin--windows ()
  "Return the windows currently displaying the current buffer."
  (get-buffer-window-list (current-buffer) nil t))

(defun svg-margin--apply-margins (left right)
  "Reserve LEFT and RIGHT indicator columns in every window showing the buffer.
Only writes a window whose margins actually differ, so the call cannot
induce a redundant `window-configuration-change-hook' (and the re-render
loop / flicker that would follow)."
  (let ((lw (* left svg-margin-column-width))
        (rw (* right svg-margin-column-width)))
    (dolist (win (svg-margin--windows))
      (let* ((cur (window-margins win))
             (cl (or (car cur) 0))
             (cr (or (cdr cur) 0)))
        (unless (and (= cl lw) (= cr rw))
          (set-window-margins win lw rw))))))

(defun svg-margin--restore-margins ()
  "Restore window margins to the buffer's own margin widths."
  (dolist (win (svg-margin--windows))
    (set-window-margins win (or left-margin-width 0) (or right-margin-width 0))))

(defun svg-margin--fringe-sides ()
  "Return the list of fringe sides to zero per `svg-margin-disable-fringe'."
  (pcase svg-margin-disable-fringe
    ((or 't 'both) '(left right))
    ('left '(left))
    ('right '(right))
    (_ nil)))

(defun svg-margin--apply-fringes (restore)
  "Zero (or, when RESTORE, reset to default) the configured fringe sides."
  (let ((sides (svg-margin--fringe-sides)))
    (when sides
      (dolist (win (svg-margin--windows))
        (let* ((fr (window-fringes win)) (l (nth 0 fr)) (r (nth 1 fr))
               (nl (cond ((not (memq 'left sides)) l) (restore nil) (t 0)))
               (nr (cond ((not (memq 'right sides)) r) (restore nil) (t 0))))
          ;; Only write when changed (see `svg-margin--apply-margins').
          (unless (and (equal nl l) (equal nr r))
            (set-window-fringes win nl nr)))))))

;;;; Render
;; ----------------------------------------------------------------

(defun svg-margin--render (&optional buffer)
  "Re-render all svg-margin indicators in BUFFER (default current)."
  (let ((buffer (or buffer (current-buffer))))
    (when (and (buffer-live-p buffer) (display-graphic-p))
      (with-current-buffer buffer
        (when (bound-and-true-p svg-margin-mode)
          (svg-margin--clear)
          (let ((groups (svg-margin--group (svg-margin--collect)))
                (max-left 0) (max-right 0))
            (maphash
             (lambda (key inds)
               (let* ((pos (car key)) (side (cdr key))
                      (packed (svg-margin--pack-columns inds))
                      (ncols (svg-margin--max-column packed)))
                 (when (> ncols 0)
                   (if (eq side 'left)
                       (setq max-left (max max-left ncols))
                     (setq max-right (max max-right ncols)))
                   (svg-margin--place pos side packed ncols))))
             groups)
            (svg-margin--apply-margins max-left max-right)
            (svg-margin--apply-fringes nil)))))))

(defvar-local svg-margin--timer nil
  "Idle timer coalescing re-renders for this buffer.")

(defun svg-margin--schedule (&optional buffer)
  "Schedule a debounced re-render of BUFFER (default current)."
  (let ((buf (or buffer (current-buffer))))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (when (timerp svg-margin--timer) (cancel-timer svg-margin--timer))
        (setq svg-margin--timer
              (run-with-idle-timer svg-margin-idle-delay nil
                                   #'svg-margin--render buf))))))

(defun svg-margin--after-change (&rest _)
  "Schedule a re-render after a buffer change."
  (svg-margin--schedule))

(defun svg-margin--window-config ()
  "Schedule a re-render after a window configuration change."
  (svg-margin--schedule))

;;;; Public commands + mode
;; ----------------------------------------------------------------

;;;###autoload
(defun svg-margin-refresh (&optional buffer)
  "Re-render svg-margin indicators in BUFFER (default current)."
  (interactive)
  (svg-margin--schedule buffer))

(defun svg-margin-refresh-all ()
  "Re-render every buffer in which `svg-margin-mode' is enabled."
  (dolist (buf (buffer-list))
    (when (buffer-local-value 'svg-margin-mode buf)
      (svg-margin--schedule buf))))

;;;###autoload
(define-minor-mode svg-margin-mode
  "Display SVG indicators from registered providers in the window margins.
Providers are registered globally with `svg-margin-register-provider'; this
buffer-local mode renders whatever they contribute for the current buffer."
  :lighter " SVGm"
  (if svg-margin-mode
      (progn
        (add-hook 'after-change-functions #'svg-margin--after-change nil t)
        (add-hook 'window-configuration-change-hook #'svg-margin--window-config nil t)
        (svg-margin--render (current-buffer)))
    (remove-hook 'after-change-functions #'svg-margin--after-change t)
    (remove-hook 'window-configuration-change-hook #'svg-margin--window-config t)
    (when (timerp svg-margin--timer) (cancel-timer svg-margin--timer))
    (svg-margin--clear)
    (svg-margin--apply-fringes t)
    (svg-margin--restore-margins)))

(defun svg-margin--maybe-enable ()
  "Turn on `svg-margin-mode' in an ordinary file buffer."
  (when (and (not (minibufferp)) buffer-file-name)
    (svg-margin-mode 1)))

;;;###autoload
(define-globalized-minor-mode global-svg-margin-mode
  svg-margin-mode svg-margin--maybe-enable)

(provide 'svg-margin)
;;; svg-margin.el ends here
