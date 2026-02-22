;;; spacetree.el --- space-tree workspace management config -*- lexical-binding: t -*-

;; space-tree: https://github.com/chiply/space-tree

(use-package space-tree
  :ensure (:host github :repo "chiply/space-tree")
  :demand t
  :config
  (unless (ht-keys space-tree-tree) (space-tree-init))

  :general
  ("s-1" (lambda () (interactive) (space-tree-switch-or-create '(1)))
   "s-2" (lambda () (interactive) (space-tree-switch-or-create '(2)))
   "s-3" (lambda () (interactive) (space-tree-switch-or-create '(3)))
   "s-4" (lambda () (interactive) (space-tree-switch-or-create '(4)))
   "s-5" (lambda () (interactive) (space-tree-switch-or-create '(5)))
   "s-6" (lambda () (interactive) (space-tree-switch-or-create '(6)))
   "s-7" (lambda () (interactive) (space-tree-switch-or-create '(7)))
   "s-8" (lambda () (interactive) (space-tree-switch-or-create '(8)))
   "s-9" (lambda () (interactive) (space-tree-switch-or-create '(9)))
   ;; Second level
   "s-a" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) 1)))
   "s-s" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) 2)))
   "s-d" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) 3)))
   "s-f" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) 4)))
   "s-g" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) 5)))
   ;; Third level
   "s-A" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) ,(nth 1 space-tree-current-address) 1)))
   "s-S" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) ,(nth 1 space-tree-current-address) 2)))
   "s-D" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) ,(nth 1 space-tree-current-address) 3)))
   "s-F" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) ,(nth 1 space-tree-current-address) 4)))
   "s-G" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) ,(nth 1 space-tree-current-address) 5)))
   ;; Navigation
   "M-S-<tab>" 'space-tree-switch-space-by-name
   "M-<tab>" 'space-tree-go-to-last-space
   "C-M-<tab>" 'space-tree-go-right
   "C-M-S-<tab>" 'space-tree-go-left
   "s-_" (lambda () (interactive) (space-tree-delete-space space-tree-current-address)))
  :general
  (:states '(normal visual)
   :keymaps 'override
   "gt" 'space-tree-switch-current-level
   "gT" 'space-tree-switch-space-by-digit-arg
   "g+" 'space-tree-create-space-top-level
   "gn" 'space-tree-create-space-current-level))
