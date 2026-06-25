;;; spacetree.el --- space-tree workspace management config -*- lexical-binding: t -*-

;; space-tree: https://github.com/chiply/space-tree

(use-package space-tree
  :ensure (:host github :repo "chiply/space-tree")
  :demand t
  :config
  (unless (ht-keys space-tree-tree) (space-tree-init))

  :general
  ("s-1" 'space-tree-to-1
   "s-2" 'space-tree-to-2
   "s-3" 'space-tree-to-3
   "s-4" 'space-tree-to-4
   "s-5" 'space-tree-to-5
   "s-6" 'space-tree-to-6
   "s-7" 'space-tree-to-7
   "s-8" 'space-tree-to-8
   "s-9" 'space-tree-to-9
   ;; Second level
   "s-a" 'space-tree-sub-1
   "s-s" 'space-tree-sub-2
   "s-d" 'space-tree-sub-3
   "s-f" 'space-tree-sub-4
   "s-g" 'space-tree-sub-5
   ;; Third level
   "s-A" 'space-tree-sub-sub-1
   "s-S" 'space-tree-sub-sub-2
   "s-D" 'space-tree-sub-sub-3
   "s-F" 'space-tree-sub-sub-4
   "s-G" 'space-tree-sub-sub-5
   ;; Navigation
   "M-S-<tab>" 'space-tree-switch-space-by-name
   "M-<tab>" 'space-tree-go-to-last-space
   "C-M-<tab>" 'space-tree-go-right
   "C-M-S-<tab>" 'space-tree-go-left
   "s-_" 'space-tree-delete-space)
  :general
  (:states '(normal visual)
   :keymaps 'override
   "gt" 'space-tree-switch-current-level
   "gT" 'space-tree-switch-space-by-digit-arg
   "g+" 'space-tree-create-space-top-level
   "gn" 'space-tree-create-space-current-level))

;;; ------------------------------------------------------------------
;;; Circled-number lighter -- render the space-tree tab-bar numbers as
;;; the same nf-md-numeric_N_circle glyphs the tab-line and svg-margin
;;; use.  space-tree's per-level renderer calls `number-to-string' for an
;;; unnamed space; we rebind that, for the duration of just that one
;;; function, so the display number becomes a circle glyph.  Its only
;;; `number-to-string' use is the display number, and NAMED spaces never
;;; reach it -- so names and the package's internals are untouched.
;;; ------------------------------------------------------------------
(require 'cl-lib)
(declare-function zetta-circle-number "line-utils")
(declare-function space-tree--modeline-string-for-level "space-tree")

(defun zetta-space-tree--circle-numbers (orig &rest args)
  "Around-advice for `space-tree--modeline-string-for-level': circle the numbers.
Falls back to the real `number-to-string' when nerd-icons is unavailable or the
value isn't an integer (`zetta-circle-number' returns nil in those cases)."
  (cl-letf* ((nts (symbol-function 'number-to-string))
             ((symbol-function 'number-to-string)
              (lambda (n) (or (zetta-circle-number n) (funcall nts n)))))
    (apply orig args)))

(with-eval-after-load 'space-tree
  (advice-add 'space-tree--modeline-string-for-level
              :around #'zetta-space-tree--circle-numbers))
