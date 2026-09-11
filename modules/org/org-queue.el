;;; org-queue.el --- Configure org-queue -*- lexical-binding: t; -*-

;; Thin wrapper around the in-tree `org-queue' package (under
;; `source/zettapkg/').  When it is factored out to its own repo, swap
;; `:ensure nil' + `:load-path' for `:ensure t'.
;;
;; `M-x org-queue-today' (,-o-Q) packs a day out of `org-agenda-files' --
;; commitments first, then whatever scores highest until the day is full --
;; and reports what it left out and why.  The arithmetic lives in
;; `org-queue-core', which has no Org in it and is tested in batch; see the
;; package README.
;;
;; Only three things are configured here, and all three are local facts the
;; package cannot know: where to keep its state, what a day is worth, and
;; how the buffer should look in this theme.

(use-package org-queue
  :ensure nil
  :load-path "source/zettapkg/org-queue"
  :commands (org-queue-today org-queue-calibration org-queue-plan)

  :brushup
  ;; The plan is a prominence ladder, not a colour scheme: the date at the
  ;; top, the work under it, the supporting numbers a rung down, and the
  ;; guesses a rung below that.  Overcommitment is the loudest thing on the
  ;; page and earns the top rung plus an underline -- it is a fact about
  ;; the day, not an error, so it does not get the error colour.
  (add-to-list
   'brushup-styles
   '(when (facep 'org-queue-header)
      (set-face-attribute 'org-queue-header nil
                          :foreground (or (bound-and-true-p brushup-fg)
                                          (face-foreground 'default nil t))
                          :weight 'bold)
      (set-face-attribute 'org-queue-section nil
                          :foreground (or (bound-and-true-p brushup-fg-2)
                                          (face-foreground 'shadow nil t))
                          :weight 'bold)
      (set-face-attribute 'org-queue-detail nil
                          :foreground (or (bound-and-true-p brushup-fg-4)
                                          (face-foreground 'shadow nil t)))
      (set-face-attribute 'org-queue-guess nil
                          :foreground (or (bound-and-true-p brushup-fg-5)
                                          (face-foreground 'shadow nil t))
                          :slant 'italic)
      (set-face-attribute 'org-queue-alarm nil
                          :foreground (or (bound-and-true-p brushup-fg)
                                          (face-foreground 'default nil t))
                          :weight 'bold :underline t))
   t)

  :init
  ;; Carry-over state, not notes: keep it with the other generated data
  ;; rather than in `user-emacs-directory' proper.
  (setq org-queue-history-file
        (expand-file-name ".data/org/queue-history.el" user-emacs-directory))

  :config
  ;; A placeholder day, and known to be one.  The honest number comes from
  ;; clocking normally for a fortnight and reading it off -- until then the
  ;; packer needs *a* capacity, and one that is too generous teaches you to
  ;; distrust the plan faster than one that is too mean.
  (setq org-queue-capacity '((0 . 90)    ; Sunday
                             (1 . 300)
                             (2 . 300)
                             (3 . 300)
                             (4 . 300)
                             (5 . 240)   ; Friday
                             (6 . 90)))) ; Saturday

(general-define-key
 :keymaps 'menu-org-map
 "Q" 'org-queue-today
 "C" 'org-queue-calibration)
;;; org-queue.el ends here
