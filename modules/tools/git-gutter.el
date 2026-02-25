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
   "g" (repeatable-lite-wrap git-gutter)
   "j" (repeatable-lite-wrap git-gutter:next-hunk)
   "k" (repeatable-lite-wrap git-gutter:previous-hunk))

  :hook (use-package--git-gutter--post-config . brushup)
  )
;;; git-gutter.el ends here
