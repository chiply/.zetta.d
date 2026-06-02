;;; tap-fold.el --- Overlay-based folding of thing-at-point things -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; URL: https://github.com/<TBD>/tap-fold
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience, tools

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

;; Fold spans by *type* using overlay invisibility.  Universal across
;; any `thing-at-point' thing: paragraph, sentence, defun, sexp, word,
;; line, function, class, call, etc.
;;
;; Unlike line-snapped folding (hideshow, outline, treesit-fold), this
;; layer hides arbitrary bounds.  A sentence inside a line can be
;; folded with the rest of the line still visible (ellipsis in place
;; of the hidden span).
;;
;; Quick start:
;;
;;   (use-package tap-fold
;;     :ensure t
;;     :bind (("s-x f" . tap-fold-thing-at-point)
;;            ("s-x F" . tap-fold-unfold-at-point)
;;            ("s-x M-f" . tap-fold-unfold-all)))
;;
;; Optional integrations (auto-detected when loaded):
;;   - consult -- preview UI in `tap-fold-thing-at-point' shows
;;                exactly which bounds will be folded as you narrow
;;   - treesit-tap -- `tap-fold-current-thing' folds
;;                    `treesit-tap-current-thing'
;;   - embark-scope -- `tap-fold-embark-target' folds the captured
;;                       embark target's bounds (requires
;;                       `embark-scope-capture-mode' to be on)

;;; Code:

(require 'cl-lib)
(require 'thingatpt)

;; Forward declarations for optional packages.
(declare-function consult--read "consult" (table &rest options))
(defvar treesit-tap-current-thing)
(defvar embark-scope-capture-mode)
(defvar embark-scope-last-target-bounds)

(defgroup tap-fold nil
  "Overlay-based folding of thing-at-point things."
  :group 'editing
  :prefix "tap-fold-")

(defconst tap-fold--spec 'tap-fold
  "Symbol used as the `invisible' property value on fold overlays
and as the spec entry added to `buffer-invisibility-spec'.")

(defcustom tap-fold-things
  '(paragraph sentence defun sexp word line)
  "Things prompted for by `tap-fold-thing-at-point' when called
interactively.  Any symbol that `bounds-of-thing-at-point' can
resolve works.

Extend with user-defined things (e.g. `brick' from a private config,
or `orgtree' from org-mode):

  (push \\='orgtree tap-fold-things)"
  :type '(repeat symbol)
  :group 'tap-fold)

(defface tap-fold-preview-face
  '((((background dark))  :background "#3a2a00" :extend nil)
    (((background light)) :background "#fff3b0" :extend nil))
  "Face used to highlight the candidate bounds in
`tap-fold-thing-at-point''s consult preview."
  :group 'tap-fold)


;;;; Core: spec + overlay primitives
;; ----------------------------------------------------------------

(defun tap-fold--ensure-spec ()
  "Add `tap-fold--spec' to `buffer-invisibility-spec' with ellipsis
enabled, idempotently."
  (let ((entry (cons tap-fold--spec t)))
    (cond
     ((eq buffer-invisibility-spec t)
      ;; Bare `t' hides any non-nil `invisible' property but never
      ;; renders an ellipsis -- we need the alist form to get the
      ;; ellipsis on our overlays.  This narrows the spec from "hide
      ;; anything non-nil" to "hide entries in this list".  In practice
      ;; that combination is rare: `buffer-invisibility-spec' starts as
      ;; `t' but is replaced by almost every package that uses overlay
      ;; invisibility.
      (setq buffer-invisibility-spec (list entry)))
     ((not (member entry buffer-invisibility-spec))
      (add-to-invisibility-spec entry)))))

(defun tap-fold--overlay-at (pos)
  "Return the `tap-fold' overlay at POS, or nil.
Checks both POS and POS-1 so point-on-the-ellipsis works."
  (or (cl-find-if (lambda (ov) (overlay-get ov 'tap-fold))
                  (overlays-at pos))
      (and (> pos (point-min))
           (cl-find-if (lambda (ov) (overlay-get ov 'tap-fold))
                       (overlays-at (1- pos))))))

;;;###autoload
(defun tap-fold-region (beg end)
  "Fold the region BEG..END with an invisibility overlay.
Returns the overlay."
  (interactive "r")
  (tap-fold--ensure-spec)
  (let ((ov (make-overlay beg end nil t nil)))
    (overlay-put ov 'invisible tap-fold--spec)
    (overlay-put ov 'tap-fold t)
    (overlay-put ov 'isearch-open-invisible #'delete-overlay)
    (overlay-put ov 'evaporate t)
    ov))

;;;###autoload
(defun tap-fold-unfold-at-point ()
  "Remove the fold overlay enclosing point, if any."
  (interactive)
  (if-let* ((ov (tap-fold--overlay-at (point))))
      (progn (delete-overlay ov)
             (message "Unfolded"))
    (message "No fold at point")))

;;;###autoload
(defun tap-fold-unfold-all ()
  "Remove every `tap-fold' overlay in the current buffer."
  (interactive)
  (let ((count 0))
    (dolist (ov (overlays-in (point-min) (point-max)))
      (when (overlay-get ov 'tap-fold)
        (delete-overlay ov)
        (cl-incf count)))
    (message "Cleared %d fold(s)" count)))

;;;###autoload
(defun tap-fold-thing (thing)
  "Fold the bounds of THING at point.  Non-interactive primitive."
  (if-let* ((b (ignore-errors (bounds-of-thing-at-point thing))))
      (tap-fold-region (car b) (cdr b))
    (user-error "No `%s' at point" thing)))


;;;; Consult-backed picker
;; ----------------------------------------------------------------

(defvar-local tap-fold--preview-overlay nil
  "One-shot preview overlay during `tap-fold-thing-at-point'.")

(defun tap-fold--clear-preview ()
  "Delete `tap-fold--preview-overlay' if any."
  (when (overlayp tap-fold--preview-overlay)
    (delete-overlay tap-fold--preview-overlay))
  (setq tap-fold--preview-overlay nil))

(defun tap-fold--candidates-at-point ()
  "Return alist of (NAME . (BEG . END)) for each thing in
`tap-fold-things' that has bounds at point."
  (delq nil
        (mapcar (lambda (thing)
                  (when-let* ((b (ignore-errors
                                   (bounds-of-thing-at-point thing))))
                    (when (and (car b) (cdr b) (< (car b) (cdr b)))
                      (cons (symbol-name thing) b))))
                tap-fold-things)))

;;;###autoload
(defun tap-fold-thing-at-point ()
  "Pick a thing at point and fold its bounds.

Only things whose `bounds-of-thing-at-point' returns a real span
at point appear as candidates.  With `consult--read' available, a
preview paints the candidate's bounds with `tap-fold-preview-face'
so you can see exactly what will be folded.  Falls back to plain
`completing-read' otherwise."
  (interactive)
  (let ((candidates (tap-fold--candidates-at-point)))
    (cond
     ((null candidates)
      (user-error "Nothing foldable at point"))
     ((fboundp 'consult--read)
      (unwind-protect
          (let* ((choice
                  (consult--read
                   (mapcar #'car candidates)
                   :prompt "Fold: "
                   :require-match t
                   :sort nil
                   :state
                   (lambda (action cand)
                     (pcase action
                       ('preview
                        (tap-fold--clear-preview)
                        (when (and cand (stringp cand))
                          (when-let* ((b (cdr (assoc cand candidates))))
                            (let ((ov (make-overlay (car b) (cdr b))))
                              (overlay-put ov 'face
                                           'tap-fold-preview-face)
                              (overlay-put ov 'priority 100)
                              (setq tap-fold--preview-overlay ov))))) ))))
                 (b (cdr (assoc choice candidates))))
            (when b (tap-fold-region (car b) (cdr b))))
        (tap-fold--clear-preview)))
     (t
      (let* ((choice (completing-read "Fold: " (mapcar #'car candidates)
                                      nil t))
             (b (cdr (assoc choice candidates))))
        (when b (tap-fold-region (car b) (cdr b))))))))

;;;###autoload
(defun tap-fold-toggle-thing-at-point (thing)
  "If there's a fold at point, unfold it; otherwise fold THING here."
  (interactive
   (list (intern (completing-read
                  "Fold thing: "
                  (mapcar #'symbol-name tap-fold-things)
                  nil nil))))
  (if (tap-fold--overlay-at (point))
      (tap-fold-unfold-at-point)
    (tap-fold-thing thing)))


;;;; Optional integrations: treesit-tap + embark-scope
;; ----------------------------------------------------------------

;;;###autoload
(defun tap-fold-current-thing ()
  "Fold the buffer-local `treesit-tap-current-thing' at point.

Soft dependency: requires the `treesit-tap' package to be loaded
and `treesit-tap-current-thing' to be set in this buffer."
  (interactive)
  (cond
   ((not (boundp 'treesit-tap-current-thing))
    (user-error "treesit-tap not loaded"))
   ((not treesit-tap-current-thing)
    (user-error "`treesit-tap-current-thing' is not set"))
   (t
    (tap-fold-thing treesit-tap-current-thing))))

;;;###autoload
(defun tap-fold-embark-target ()
  "Fold the captured embark target's bounds.

Soft dependency: requires the `embark-scope' package and its
`embark-scope-capture-mode' to be on (the capture machinery is
what populates `embark-scope-last-target-bounds')."
  (interactive)
  (cond
   ((not (boundp 'embark-scope-capture-mode))
    (user-error
     "embark-scope not loaded -- (require \\='embark-scope)"))
   ((not embark-scope-capture-mode)
    (user-error
     "Enable `embark-scope-capture-mode' first (needed to capture target bounds)"))
   ((not (and (boundp 'embark-scope-last-target-bounds)
              embark-scope-last-target-bounds))
    (message "No bounds on active embark target"))
   (t
    (let ((b embark-scope-last-target-bounds))
      (tap-fold-region (car b) (cdr b))))))


(provide 'tap-fold)
;;; tap-fold.el ends here
