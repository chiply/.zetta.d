;;; org-agenda.el --- Configure org-agenda -*- lexical-binding: t; -*-

;; The agenda was stock until now -- no custom commands anywhere in the
;; config -- which is most of why it went unused: `M-x org-agenda' on an
;; unconfigured Org drops you at a dispatcher offering a week of
;; everything, sorted by file, and nothing there answers "what am I doing
;; today".
;;
;; These commands do answer it.  The first four are the zoom levels; the
;; rest each slice the same backlog along one axis, so the question you
;; arrived with picks the key:
;;
;;   ,-o-v d   Day        today, then the backlog under it
;;   ,-o-v w   Week       seven days, ungrouped so the days stay days
;;   ,-o-v c   Context    the open backlog by @-tag, uncontexted last
;;   ,-o-v u   Untriaged  what has no estimate, priority or date yet
;;
;;   ,-o-v i   Inbox      captures not yet decided on or refiled
;;   ,-o-v p   Projects   the backlog by parent heading
;;   ,-o-v n   Neglected  by how long since anything happened to it
;;   ,-o-v W   Chase      WAIT/QUES only, by how long you have waited
;;   ,-o-v I   Parked     HOLD/IDEA, which every other view discards
;;   ,-o-v E   Capacity   by effort, for "what fits in 40 minutes"
;;   ,-o-v h   Horizon    by deadline distance
;;   ,-o-v P   Priority   the cookie ladder
;;   ,-o-v f   Areas      by category
;;   ,-o-v r   Review     what closed or moved in the last seven days
;;   ,-o-v b   Blocked    stuck on a thing, stuck on a person, or ready
;;
;; Views that group on computed buckets (Neglected, Chase, Horizon) do it
;; with named `:pred' functions in org-super-agenda.el rather than
;; `:auto-ts'/`:auto-map', which would emit one group per distinct date and
;; sort the buckets alphabetically.
;;
;; The grouping lives in `modules/org/org-super-agenda.el'; the queries in
;; the Untriaged view are org-ql blocks, because Org's own match syntax
;; cannot express "has no priority cookie" -- it reports an un-cookied
;; entry as B, which is exactly the distinction the triage view exists to
;; surface.
;;
;; `org-agenda-files' is rebuilt by `zetta-logseq-update-agenda-files' in
;; org.el and follows `zetta-org-todo-source', so every command here reads
;; the test corpus or the real kb according to the toggle.

(defvar zetta-org-agenda-day-groups)
(defvar zetta-org-agenda-backlog-groups)
(defvar zetta-org-agenda-context-groups)
(defvar zetta-org-agenda-inbox-groups)
(defvar zetta-org-agenda-project-groups)
(defvar zetta-org-agenda-stalled-groups)
(defvar zetta-org-agenda-chase-groups)
(defvar zetta-org-agenda-parked-groups)
(defvar zetta-org-agenda-capacity-groups)
(defvar zetta-org-agenda-horizon-groups)
(defvar zetta-org-agenda-priority-groups)
(defvar zetta-org-agenda-area-groups)
(defvar zetta-org-agenda-review-groups)
(defvar zetta-org-agenda-blocked-groups)
(defvar zetta-org-inbox-file)

(use-package org-agenda
  :ensure nil
  :defer t
  :config
  ;; org-ql supplies the `org-ql-block' agenda block type used below.
  ;; Required here rather than at startup: the cost lands on the first
  ;; agenda of the session, not on every session.
  (require 'org-ql-search nil t)

  (setq org-agenda-restore-windows-after-quit t
        ;; Match `org-tags-column' in org.el: tags right after the
        ;; headline rather than flushed to a column that no longer lines
        ;; up once the prefix carries an effort.
        org-agenda-tags-column 0
        org-agenda-block-separator nil
        org-agenda-start-on-weekday 1
        org-agenda-span 'day
        org-agenda-skip-scheduled-if-done t
        org-agenda-skip-deadline-if-done t
        ;; A deadline you have already scheduled work for does not need to
        ;; shout for the whole warning period as well.
        org-agenda-skip-deadline-prewarning-if-scheduled 'pre-scheduled
        org-deadline-warning-days 7
        ;; Effort in the prefix is what makes the agenda answer "will this
        ;; fit", which is the same question `org-queue' answers in bulk.
        org-agenda-prefix-format
        '((agenda  . " %i %-9:c%?-12t %-5e% s")
          (todo    . " %i %-9:c %-5e")
          (tags    . " %i %-9:c %-5e")
          (search  . " %i %-9:c"))
        org-agenda-sorting-strategy
        '((agenda habit-down time-up deadline-up priority-down category-keep)
          (todo priority-down effort-up category-keep)
          (tags priority-down category-keep)
          (search category-keep)))

  (setq org-agenda-custom-commands
        '(("d" "Day -- what today asks of you"
           ((agenda ""
                    ((org-agenda-span 1)
                     (org-agenda-overriding-header "")
                     (org-super-agenda-groups zetta-org-agenda-day-groups)))
            (alltodo ""
                     ((org-agenda-overriding-header "Backlog")
                      (org-super-agenda-groups
                       zetta-org-agenda-backlog-groups)))))

          ("w" "Week -- the shape of the next seven days"
           ((agenda ""
                    ((org-agenda-span 7)
                     (org-agenda-start-on-weekday nil)
                     ;; No grouping here on purpose: super-agenda groups
                     ;; across the whole block, which would dissolve the
                     ;; day boundaries that are the entire point of a week
                     ;; view.
                     (org-super-agenda-groups nil)))))

          ("c" "Context -- what you could do in the state you are in"
           ((alltodo ""
                     ((org-agenda-overriding-header "")
                      (org-super-agenda-groups
                       zetta-org-agenda-context-groups)))))

          ("i" "Inbox -- process what has been captured"
           ((org-ql-block '(level 1)
                          ((org-ql-block-header "Inbox")
                           (org-super-agenda-groups
                            zetta-org-agenda-inbox-groups))))
           ;; An org-ql block, not `alltodo': the `n' and `N' templates
           ;; capture a bare heading with no TODO keyword, and `alltodo'
           ;; cannot see those at all -- which is most of why the inbox
           ;; went unprocessed.  Restricted to the inbox file itself so
           ;; this stays a processing queue rather than another backlog.
           ((org-agenda-files (list (expand-file-name zetta-org-inbox-file)))))

          ("p" "Projects -- the backlog by parent heading"
           ((alltodo ""
                     ((org-agenda-overriding-header "")
                      (org-super-agenda-groups
                       zetta-org-agenda-project-groups)))))

          ;; `s' is Org's own dispatcher key for search, and the built-ins
          ;; are matched before custom commands, so Stalled takes `n' for
          ;; neglected.  Capacity takes `E' for the same reason: `e' is
          ;; export.
          ("n" "Neglected -- what has gone quiet"
           ((alltodo ""
                     ((org-agenda-overriding-header "")
                      (org-super-agenda-groups
                       zetta-org-agenda-stalled-groups)))))

          ("W" "Chase -- what someone else is sitting on"
           ((alltodo ""
                     ((org-agenda-overriding-header "")
                      (org-super-agenda-groups
                       zetta-org-agenda-chase-groups)))))

          ("I" "Parked -- the someday pile every other view hides"
           ((alltodo ""
                     ((org-agenda-overriding-header "")
                      (org-super-agenda-groups
                       zetta-org-agenda-parked-groups)))))

          ("E" "Capacity -- what fits in the time you have"
           ((alltodo ""
                     ((org-agenda-overriding-header "")
                      (org-super-agenda-groups
                       zetta-org-agenda-capacity-groups)))))

          ("h" "Horizon -- what is coming, by deadline"
           ((alltodo ""
                     ((org-agenda-overriding-header "")
                      (org-super-agenda-groups
                       zetta-org-agenda-horizon-groups)))))

          ("P" "Priority -- the cookie ladder, honestly"
           ((alltodo ""
                     ((org-agenda-overriding-header "")
                      (org-super-agenda-groups
                       zetta-org-agenda-priority-groups)))))

          ("f" "Areas -- the backlog by category"
           ((alltodo ""
                     ((org-agenda-overriding-header "")
                      (org-super-agenda-groups
                       zetta-org-agenda-area-groups)))))

          ("r" "Review -- what actually moved this past week"
           ((agenda ""
                    ((org-agenda-span 7)
                     (org-agenda-start-day "-7d")
                     ;; Without this the global `org-agenda-start-on-weekday'
                     ;; snaps the window back to Monday, so a Wednesday
                     ;; review covers last week and silently omits the three
                     ;; days you actually want to review.
                     (org-agenda-start-on-weekday nil)
                     (org-agenda-overriding-header "")
                     ;; `:log' matches the agenda item's `type' property,
                     ;; which only exists in log mode -- without this the
                     ;; block renders and every group is empty.
                     ;;
                     ;; It has to be `org-agenda-show-log' and not
                     ;; `org-agenda-start-with-log-mode': the latter is read
                     ;; once by `org-agenda-mode', which runs when the buffer
                     ;; is prepared and so BEFORE per-block settings are
                     ;; bound, leaving the block-level value with nothing to
                     ;; do.  The value must also be the explicit item list
                     ;; rather than t, because a bare t defers to
                     ;; `org-agenda-log-mode-items' -- (closed clock) --
                     ;; which drops exactly the state changes wanted here.
                     (org-agenda-show-log '(closed state))
                     (org-super-agenda-groups
                      zetta-org-agenda-review-groups)))))

          ("b" "Blocked -- what is stuck, and what is not"
           ((alltodo ""
                     ((org-agenda-overriding-header "")
                      (org-super-agenda-groups
                       zetta-org-agenda-blocked-groups)))))

          ("u" "Untriaged -- what has no metadata yet"
           ((org-ql-block '(and (todo)
                                (not (todo "HOLD" "IDEA"))
                                (not (property "Effort")))
                          ((org-ql-block-header "No estimate")))
            (org-ql-block '(and (todo)
                                (not (todo "HOLD" "IDEA"))
                                (not (priority)))
                          ((org-ql-block-header "No priority")))
            (org-ql-block '(and (todo)
                                (not (todo "HOLD" "IDEA"))
                                (not (scheduled))
                                (not (deadline))
                                (not (ts-active)))
                          ((org-ql-block-header "No date of any kind"))))))))

(general-define-key
 :keymaps 'menu-org-map
 "v" 'org-agenda)
;;; org-agenda.el ends here
