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
  ;; The live-update idle timer is global and trusts buffer-local
  ;; state blindly: async diff sentinels can leave git-gutter:enabled
  ;; t in buffers where the mode never enabled (no vcs-type), and the
  ;; timer then errors every tick — "Error running timer
  ;; 'git-gutter:live-update': (wrong-type-argument arrayp nil)".
  ;; Only live-update where the mode is actually on and initialized.
  (defun zetta-git-gutter--live-update-sane-p (&rest _)
    (and git-gutter-mode git-gutter:vcs-type))
  (advice-add 'git-gutter:live-update :before-while
              #'zetta-git-gutter--live-update-sane-p)

  ;; add indicator to margin showing the current line number

  :brushup
  (add-to-list 'brushup-styles
               '(progn
                  (setq brushup-git-gutter-foreground brushup-bg-6
                        brushup-git-gutter-background brushup-bg)
                  ;; Added/deleted/modified were all one colour, so the gutter
                  ;; said "something changed" but never what.  The three hues
                  ;; come from `zetta-vc-marker-ladder' -- three rungs of the
                  ;; theme's own ink ladder rather than the red/green/yellow
                  ;; diff stoplight, which is three colours from outside the
                  ;; theme run down the edge of every window to encode a
                  ;; distinction any three shades can carry.
                  (set-face-attribute 'git-gutter:added nil
                                      :foreground (zetta-vc-marker-color 'added)
                                      :background 'unspecified)
                  (set-face-attribute 'git-gutter:deleted nil
                                      :foreground (zetta-vc-marker-color 'removed)
                                      :background 'unspecified)
                  (set-face-attribute 'git-gutter:modified nil
                                      :foreground (zetta-vc-marker-color 'modified)
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
