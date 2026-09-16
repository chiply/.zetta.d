;;; dired-ranger.el --- Configure dired-ranger -*- lexical-binding: t; -*-

;; The ranger-style extras for dired, from dired-hacks (installed by the
;; `dired-hacks' recipe in tools/dired-subtree.el): a two-stage copy/paste
;; and single-character bookmarks.
;;
;; Copy/paste: mark files, `Y' puts them on the clipboard (C-u Y adds to
;; it); in the target dired, `P' copies them there and `M' moves them.
;; Those three keys are bound in tools/dired.el, wrapped to revert the
;; target afterwards.  Past clipboards stay on `dired-ranger-copy-ring'.
;;
;; Bookmarks: `'' asks for a character and remembers this dired buffer
;; under it; `` ` '' asks for one and jumps to it.  The LRU bookmark
;; (`dired-ranger-bookmark-LRU', the backquote itself) always names the
;; previously used dired buffer, so `` ` ` '' bounces between the two you
;; are working in.  Not persistent across sessions: Emacs's own bookmarks
;; are, and have their own keys.

(use-package dired-ranger
  :ensure nil
  :after dired-hacks
  ;; No compile-time load: the build directory that holds dired-ranger.el
  ;; is put on `load-path' by elpaca when dired-hacks is activated, which
  ;; in a batch load can be after this file is byte-compiled.  The runtime
  ;; `require' behind :after is unaffected.
  :no-require t
  :commands (dired-ranger-copy dired-ranger-paste dired-ranger-move
             dired-ranger-bookmark dired-ranger-bookmark-visit)
  :custom
  ;; A bookmark whose buffer has been killed is reopened without asking:
  ;; the buffer is only ever a directory listing.
  (dired-ranger-bookmark-reopen 'always)
  :general
  (:keymaps 'dired-mode-map
   "'" 'dired-ranger-bookmark
   "`" 'dired-ranger-bookmark-visit))
;;; dired-ranger.el ends here
