;;; bookmark.el --- Configure bookmark -*- lexical-binding: t; -*-

(use-package bookmark
  :ensure nil
  :commands (bookmark-set bookmark-jump bookmark-bmenu-list)

  :init
  (setq bookmark-fringe-mark 'bookmark-mark)
  (setq bookmark-save-flag t)
  (add-to-list 'desktop-globals-to-save 'bookmark-alist)

  :config

  :display
  ;;(zetta-side "^\\*Bookmark List*" 'right -10)
  ;;(zetta-side "^\\*Embark Export Bookmarks*" 'right -10)

  :evil
  (evil-set-initial-state 'bookmark-edit-annotation-mode 'normal)

  :general
  (
   :keymaps 'override
   :prefix "s-b"
   "B" '(lambda () (interactive)
          (bookmark-jump
           (bookmark-get-bookmark "org-capture-last-stored")))
   "N" '(lambda () (interactive)
          (bookmark-set)
          ;; NOTE bookmark+ (and its fringe lighting) is disabled —
          ;; see modules/app/disabled/bookmark+.el
          (bookmark-save)
          )
   )
  )
;;; bookmark.el ends here
