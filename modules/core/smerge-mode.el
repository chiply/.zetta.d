;;; smerge-mode.el --- Configure smerge-mode -*- lexical-binding: t; -*-

(use-package smerge-mode
  :ensure nil

  :general
  (
   :keymaps 'menu-smerge-map
   "n" (repeatable-wrap smerge-next)
   "p" (repeatable-wrap smerge-prev)
   "b" (repeatable-wrap smerge-keep-base)
   "u" (repeatable-wrap smerge-keep-upper)
   "l" (repeatable-wrap smerge-keep-lower)
   "a" (repeatable-wrap smerge-keep-all)
   "RET" (repeatable-wrap smerge-keep-current)
   "\C-m" (repeatable-wrap smerge-keep-current)
   "<" (repeatable-wrap smerge-diff-base-upper)
   "=" (repeatable-wrap smerge-diff-upper-lower)
   ">" (repeatable-wrap smerge-diff-base-lower)
   "R" (repeatable-wrap smerge-refine)
   "E" (repeatable-wrap smerge-ediff)
   "C" (repeatable-wrap smerge-combine-with-next)
   "r" (repeatable-wrap smerge-resolve)
   "k" (repeatable-wrap smerge-kill-current))

  )
;;; smerge-mode.el ends here
