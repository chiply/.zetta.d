;;; git-gutter.el --- Configure diff-hl -*- lexical-binding: t; -*-

;; nicer alternative, but doesn't seem to work in the margins
;; fringe mode is nicer, but overlaps with too much other stuff
(use-package diff-hl)

(use-package git-gutter
  :init
  (global-git-gutter-mode)

  :config
  (setq git-gutter:window-width 2)
  (setq git-gutter:update-interval 2)
  ;; Binary buffers: git-gutter:live-update writes the buffer to a
  ;; temp file to diff it, and raw image/pdf bytes can't be utf-8
  ;; encoded — Emacs pops the select-safe-coding-system warning +
  ;; minibuffer prompt on every idle tick for any image visited
  ;; inside a git repo.  A gutter is meaningless for these anyway.
  (setq git-gutter:disabled-modes
        '(image-mode doc-view-mode pdf-view-mode archive-mode tar-mode))

  ;; add indicator to margin showing the current line number

  :brushup
  (add-to-list 'brushup-styles
               '(progn
                  (setq brushup-git-gutter-foreground brushup-bg-6
                        brushup-git-gutter-background brushup-bg)
                  (set-face-attribute 'git-gutter:added nil
                                      :foreground brushup-git-gutter-foreground
                                      :background 'unspecified)
                  (set-face-attribute 'git-gutter:deleted nil
                                      :foreground brushup-git-gutter-foreground
                                      :background 'unspecified)
                  (set-face-attribute 'git-gutter:modified nil
                                      :foreground brushup-git-gutter-foreground
                                      :background 'unspecified)
                  (set-face-attribute 'git-gutter:separator nil
                                      :foreground brushup-git-gutter-foreground
                                      :background 'unspecified)
                  ))

  (general-define-key
   :keymaps 'menu-project-map
   "g" (** git-gutter)
   "j" (** git-gutter:next-hunk)
   "k" (** git-gutter:previous-hunk))

  :hook (use-package--git-gutter--post-config . brushup)
  )
;;; git-gutter.el ends here
