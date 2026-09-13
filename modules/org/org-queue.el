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
  :commands (org-queue-today org-queue-calibration org-queue-plan
             org-queue-undo-apply org-queue-horizon org-queue-propose
             org-queue-close org-queue-dormant-check org-queue-day-log
             org-queue-review-week org-queue-still-worth-it
             org-queue-season org-queue-intake
             org-queue-timer org-queue-habit-update org-queue-mail-waiting)

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
                          :weight 'bold :underline t)
      ;; org-habit's graph: red, yellow and green become rungs of the
      ;; ink ladder.  A missed day is a rung down, not a colour; nothing
      ;; resets to zero on screen because nothing resets to zero in the
      ;; score.
      (when (facep 'org-habit-clear-face)
        (let ((fg   (or (bound-and-true-p brushup-fg) (face-foreground 'default nil t)))
              (fg-3 (or (bound-and-true-p brushup-fg-3) (face-foreground 'shadow nil t)))
              (fg-5 (or (bound-and-true-p brushup-fg-5) (face-foreground 'shadow nil t)))
              (bg   (or (bound-and-true-p brushup-bg) (face-background 'default nil t)))
              (bg-2 (or (bound-and-true-p brushup-bg-2) (face-background 'default nil t))))
          (dolist (spec `((org-habit-clear-face          ,bg-2 nil)
                          (org-habit-clear-future-face   ,bg   nil)
                          (org-habit-ready-face          ,fg-3 nil)
                          (org-habit-ready-future-face   ,bg-2 nil)
                          (org-habit-alert-face          ,fg   nil)
                          (org-habit-alert-future-face   ,bg-2 nil)
                          (org-habit-overdue-face        ,fg   t)
                          (org-habit-overdue-future-face ,fg-5 nil)))
            (set-face-attribute (nth 0 spec) nil :background (nth 1 spec)
                                :foreground bg :underline (nth 2 spec))))))
   t)

  :init
  ;; Carry-over state, not notes: keep it with the other generated data
  ;; rather than in `user-emacs-directory' proper.
  (setq org-queue-history-file
        (expand-file-name ".data/org/queue-history.el" user-emacs-directory)
        org-queue-apply-log-file
        (expand-file-name ".data/org/queue-applies.el" user-emacs-directory)
        org-queue-rejections-file
        (expand-file-name ".data/org/queue-rejections.el" user-emacs-directory))
  ;; The horizon and the proposal, the close, the project check and the
  ;; day log live in their own files, loaded with the package so their
  ;; commands are there when the keys below are pressed.
  (with-eval-after-load 'org-queue
    (require 'org-queue-propose)
    (require 'org-queue-close)
    (require 'org-queue-dormant)
    (require 'org-queue-daylog)
    (require 'org-queue-review)
    (require 'org-queue-season)
    (require 'org-queue-intake)
    (require 'org-queue-timer)
    (require 'org-queue-habit)
    (require 'org-queue-mail)
    (setq org-queue-review-floors-function #'org-queue-season-floors)
    ;; Habits are scored once a day, at the close (habits phase 2).
    (advice-add 'org-queue-close :after
                (lambda (&rest _) (ignore-errors (org-queue-habit-update nil t)))))
  ;; org-habit: the consistency graph in the agenda, only for today's
  ;; habits, its column past the prefix the agenda draws (the graph
  ;; overwrites that column).  The faces are re-skinned below: no streak
  ;; colours, the ink ladder.
  (with-eval-after-load 'org
    (add-to-list 'org-modules 'org-habit)
    (setq org-habit-show-habits-only-for-today t
          org-habit-graph-column 56
          org-habit-preceding-days 21
          org-habit-following-days 3))
  ;; The mail stub is outside the agenda and the refile targets, found
  ;; by text search only (Karl Voit's pattern).
  (with-eval-after-load 'org-agenda
    (setq org-agenda-text-search-extra-files '(agenda-archives)))
  ;; The close counts the inbox; the queue itself never plans from it.
  (setq org-queue-inbox-file (zetta-kb-file "inbox.org"))

  :config
  ;; A placeholder day, and known to be one.  The honest number comes from
  ;; clocking normally for a fortnight and reading it off -- until then the
  ;; packer needs *a* capacity, and one that is too generous teaches you to
  ;; distrust the plan faster than one that is too mean.
  ;;
  ;; Weekends are flat with weekdays FOR NOW: the fixture is being exercised
  ;; on whatever day it happens to be, and a 90-minute Saturday makes every
  ;; run read as overcommitted before the packer is even tested.  Restore a
  ;; smaller weekend once real clock data says what one is worth.
  (setq org-queue-capacity '((0 . 300)   ; Sunday
                             (1 . 300)
                             (2 . 300)
                             (3 . 300)
                             (4 . 300)
                             (5 . 300)   ; Friday
                             (6 . 300))) ; Saturday

  ;; Buckets: the day as a few named pools rather than one.  Each is a
  ;; reservation and a limit; the first match claims a task and anything
  ;; unclaimed is `default'.
  ;;
  ;; THE FALLBACK.  org-routine.el derives this table and `org-queue-capacity'
  ;; from the routine table in schedule.org the moment this package loads
  ;; (`org-routine-apply-to-queue'); what is set here is only in force when
  ;; that table is absent or malformed, and the echo area says so.  With
  ;; habits in (todo) routine.org, the lift and the bike come out of `body'
  ;; before anything is packed.  Set to nil to fall back to one pool.
  (setq org-queue-buckets
        '((work         :minutes 300     ; flat across the week while testing
                        :match (:category ("work" "emacs" "cal")))
          (reading      :minutes 60
                        :match (:tags ("reading") :category ("learn")))
          (body         :minutes 120
                        :match (:tags ("body")))
          (housekeeping :minutes 60
                        :match (:tags ("housekeeping") :category ("home" "buy")))
          (default      :minutes 60)))
  ;; Now the table, if there is one.  After the `setq' above, not before:
  ;; `with-eval-after-load' forms run at `provide' time, which is before
  ;; this :config block, and the hand-written fallback would win.
  (when (fboundp 'zetta-org-routine-follow-source)
    (zetta-org-routine-follow-source)))

(general-define-key
 :keymaps 'menu-org-map
 "Q" 'org-queue-today
 "C" 'org-queue-calibration
 "u" 'org-queue-undo-apply
 "P" 'org-queue-horizon    ; the read-only many-day view; h/H are org-metaleft
 "p" 'org-queue-propose
 "x" 'org-queue-close      ; close the day; the smart tree's old key
 "m" 'org-queue-review-week   ; Monday: the pack
 "y" 'org-queue-still-worth-it
 "n" 'org-queue-season        ; horizoNs: the season
 "I" 'org-queue-intake        ; what a deadline would cost
 "e" 'org-queue-timer)        ; a unit timer, inside the dip only
;;; org-queue.el ends here
