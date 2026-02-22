;;; smerge-mode.el --- Configure smerge-mode -*- lexical-binding: t; -*-

(use-package smerge-mode
  :ensure nil

  :general
  (
   :keymaps 'menu-smerge-map
   "n" (** smerge-next)
   "p" (** smerge-prev)
   "b" (** smerge-keep-base)
   "u" (** smerge-keep-upper)
   "l" (** smerge-keep-lower)
   "a" (** smerge-keep-all)
   "RET" (** smerge-keep-current)
   "\C-m" (** smerge-keep-current)
   "<" (** smerge-diff-base-upper)
   "=" (** smerge-diff-upper-lower)
   ">" (** smerge-diff-base-lower)
   "R" (** smerge-refine)
   "E" (** smerge-ediff)
   "C" (** smerge-combine-with-next)
   "r" (** smerge-resolve)
   "k" (** smerge-kill-current))

  )
;;; smerge-mode.el ends here
