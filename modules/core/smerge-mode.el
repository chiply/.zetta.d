;;; smerge-mode.el --- Configure smerge-mode -*- lexical-binding: t; -*-

(use-package smerge-mode
  :ensure nil

  :general
  (
   :keymaps 'menu-smerge-map
   "n" (repeatable-lite-wrap smerge-next)
   "p" (repeatable-lite-wrap smerge-prev)
   "b" (repeatable-lite-wrap smerge-keep-base)
   "u" (repeatable-lite-wrap smerge-keep-upper)
   "l" (repeatable-lite-wrap smerge-keep-lower)
   "a" (repeatable-lite-wrap smerge-keep-all)
   "RET" (repeatable-lite-wrap smerge-keep-current)
   "\C-m" (repeatable-lite-wrap smerge-keep-current)
   "<" (repeatable-lite-wrap smerge-diff-base-upper)
   "=" (repeatable-lite-wrap smerge-diff-upper-lower)
   ">" (repeatable-lite-wrap smerge-diff-base-lower)
   "R" (repeatable-lite-wrap smerge-refine)
   "E" (repeatable-lite-wrap smerge-ediff)
   "C" (repeatable-lite-wrap smerge-combine-with-next)
   "r" (repeatable-lite-wrap smerge-resolve)
   "k" (repeatable-lite-wrap smerge-kill-current))

  )
;;; smerge-mode.el ends here
