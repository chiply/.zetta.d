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
