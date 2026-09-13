;;; org-super-agenda.el --- Configure org-super-agenda -*- lexical-binding: t; -*-

;; Installed as an org-ql dependency since forever, with no module and no
;; configuration -- so the agenda kept grouping by file, which is the one
;; axis that says nothing about what to do next.
;;
;; The groups below are the two the custom commands in org-agenda.el use.
;; They are named variables rather than inline lists so that both the
;; agenda and anything else that wants the same shape can share one
;; definition, and so a change here does not mean editing a quoted list
;; three levels inside `org-agenda-custom-commands'.
;;
;; Ordering follows the same idea as `org-queue': what you have already
;; committed to first, then what is moving, then what is merely possible.

(declare-function org-super-agenda-mode "org-super-agenda")

;; `org-with-point-at' is a macro, so the compiler needs it at compile time;
;; interpreted loads expand it when a predicate first runs, by which point
;; Org is up.  This is the only require here and it is compile-only.
(eval-when-compile (require 'org-macs))

;; Used by the `:pred' helpers below.  Declared rather than required: this
;; module is loaded before org-agenda pulls Org in, and the predicates only
;; ever run from inside a built agenda, by which time Org is loaded.
(declare-function org-entry-end-position "org" ())
(declare-function org-entry-get "org" (epom property &optional inherit literal-nil))
(declare-function org-time-string-to-absolute "org" (s &optional daynr prefer buffer pos))
(declare-function org-today "org-agenda" ())

(defvar zetta-org-agenda-day-groups
  ;; Parked work is matched FIRST and displayed LAST.  Group matching runs
  ;; in list order while `:order' only controls where a group is drawn, so
  ;; this is how a HOLD item with a deadline stays visible without being
  ;; filed under "Due today" next to work you have actually agreed to do.
  '((:name "Parked -- not commitments" :todo ("HOLD" "IDEA") :order 9)
    ;; NEXT first: `org-queue-core-committed-p' treats it as a commitment
    ;; rather than a candidate, so the agenda should not bury it among
    ;; scored work either.
    (:name "Next -- you decided these" :todo "NEXT" :order -1)
    (:name "Overdue" :deadline past :order 0)
    (:name "Due today" :deadline today :order 1)
    (:name "Appointments" :time-grid t :order 2)
    (:name "Scheduled today" :scheduled today :order 3)
    (:name "Carried over" :scheduled past :order 4)
    (:name "In progress" :todo "PROG" :order 5)
    (:name "Waiting on someone" :todo ("WAIT" "QUES") :order 6)
    (:name "Due this week" :deadline future :order 7))
  "Grouping for the day block of the Day agenda.")

(defvar zetta-org-agenda-backlog-groups
  '((:discard (:todo ("HOLD" "IDEA")))
    (:name "Next -- you decided these" :todo "NEXT" :order -1)
    (:name "In progress" :todo "PROG" :order 0)
    (:name "Blocked" :todo ("WAIT" "QUES") :order 1)
    (:name "Quick -- under a quarter of an hour" :effort< "0:16" :order 2)
    (:name "Top priority" :priority "A" :order 3)
    (:auto-category t :order 9))
  "Grouping for the backlog block of the Day agenda.

HOLD and IDEA are discarded rather than grouped: they are not
commitments, and a backlog that lists everything you might ever do is
the thing a backlog view is supposed to save you from.  They stay
reachable through the Untriaged view and plain `alltodo'.")

(defvar zetta-org-agenda-context-groups
  ;; One group per context tag, ordered by what the context costs you to
  ;; get into: already at the desk, then out of the house, then waiting on
  ;; somebody else's attention.
  ;;
  ;; Contexts are named explicitly rather than collected with `:auto-tags'
  ;; because that selector groups by the whole tag SET -- an entry tagged
  ;; @deep AND release lands in its own "Tags: @deep, release" bucket, so a
  ;; corpus with any second axis of tagging shatters into singletons.
  ;; Naming them also fixes the order, which `:auto-tags' sorts
  ;; alphabetically and so cannot express.
  ;;
  ;; Tag inheritance applies here: `org-agenda-use-tag-inheritance' includes
  ;; `todo' by default, which is the type `alltodo' reports as, so tagging a
  ;; parent project @deep carries the context down to its subtasks and the
  ;; migration is a per-project job rather than a per-task one.
  ;;
  ;; The catch-all is as much the point of this view as the groups are:
  ;; until the corpus is tagged, "Uncontexted" holds nearly all of it, and
  ;; watching it shrink is the only progress bar the migration gets.
  '((:discard (:todo ("HOLD" "IDEA")))
    (:name "Deep -- needs an uninterrupted block" :tag "@deep" :order 0)
    (:name "Shallow -- fits in a gap" :tag "@shallow" :order 1)
    (:name "Errands -- needs you to be somewhere" :tag "@errand" :order 2)
    (:name "In transit" :tag "@travel" :order 3)
    (:name "Calls" :tag "@call" :order 4)
    (:name "Meetings -- needs someone else's calendar" :tag "@meeting" :order 5)
    (:name "Social -- wants energy, not focus" :tag "@social" :order 6)
    (:name "No context tag yet" :anything t :order 9))
  "Grouping for the Context view, which asks what you could do right now.

An entry matching two contexts lands in the first that matches, so the
order above is also a precedence: @deep before @shallow means a task you
have marked as both is treated as the harder one.

HOLD and IDEA are discarded for the same reason as in
`zetta-org-agenda-backlog-groups': a view about what you can do now has
no use for work you have already decided not to do.")

;;;; Shared helpers for the computed group sets
;;
;; `:pred' hands its function the agenda item as a STRING carrying agenda
;; text properties -- not a buffer position -- so anything that needs the
;; entry itself has to go back through the `org-marker' property.  That
;; property is Org's own, rather than one of org-super-agenda's internals,
;; which is why these do not use `org-super-agenda--get-marker'.
;;
;; Buckets are `:pred' groups rather than `:auto-ts'/`:auto-map' because an
;; auto group makes one group per distinct key and sorts those keys
;; alphabetically: `:auto-ts' over this corpus would produce fifty
;; singleton groups in date order nobody asked for, and `:auto-map' would
;; sort "Older than three months" above "Touched this week".  Named `:pred'
;; groups keep `:name' and `:order' under our control.

(defun zetta-org-agenda--marker (item)
  "Return the `org-marker' of agenda ITEM, or nil."
  (or (get-text-property 0 'org-marker item)
      (get-text-property 0 'org-hd-marker item)))

(defun zetta-org-agenda--entry-age (item)
  "Days since the newest timestamp anywhere in ITEM's entry.

Nil when the entry carries no timestamp at all.  The scan covers the whole
entry including its LOGBOOK, so a task whose only recent event was a state
change still counts as touched -- which is the point: staleness here means
\"nothing has happened to this\", not \"this has no planning date\".

Negative for an entry stamped in the future, which the callers fold into
the freshest bucket."
  (when-let* ((marker (zetta-org-agenda--marker item)))
    (org-with-point-at marker
      (let ((limit (org-entry-end-position))
            (latest nil))
        (save-excursion
          (while (re-search-forward
                  "[[<]\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)" limit t)
            (let ((day (ignore-errors
                         (org-time-string-to-absolute (match-string 1)))))
              (when (and day (or (null latest) (> day latest)))
                (setq latest day)))))
        (when latest (- (org-today) latest))))))

(defun zetta-org-agenda-touched-week-p (item)
  "Non-nil if ITEM was touched within the last week."
  (when-let* ((age (zetta-org-agenda--entry-age item))) (<= age 7)))

(defun zetta-org-agenda-touched-month-p (item)
  "Non-nil if ITEM was last touched between one week and a month ago."
  (when-let* ((age (zetta-org-agenda--entry-age item))) (and (> age 7) (<= age 30))))

(defun zetta-org-agenda-touched-quarter-p (item)
  "Non-nil if ITEM was last touched between one and three months ago."
  (when-let* ((age (zetta-org-agenda--entry-age item))) (and (> age 30) (<= age 90))))

(defun zetta-org-agenda-touched-long-ago-p (item)
  "Non-nil if ITEM has not been touched in over three months."
  (when-let* ((age (zetta-org-agenda--entry-age item))) (> age 90)))

(defun zetta-org-agenda-never-touched-p (item)
  "Non-nil if ITEM carries no timestamp at all."
  (null (zetta-org-agenda--entry-age item)))

(defun zetta-org-agenda-review-due-p (item)
  "Non-nil if ITEM carries a REVIEW_ON date that has arrived.

The tickler for parked work: a HOLD or IDEA with a review date is not
forgotten, it is scheduled to be reconsidered, and this is what makes the
difference visible without putting it on today's agenda."
  (when-let* ((marker (zetta-org-agenda--marker item)))
    (org-with-point-at marker
      (when-let* ((stamp (org-entry-get (point) "REVIEW_ON"))
                  (day (ignore-errors (org-time-string-to-absolute stamp))))
        (<= day (org-today))))))

(defun zetta-org-agenda-done-state-log-p (item)
  "Non-nil if ITEM is a log line recording a transition INTO a done state.

Matches the rendered prefix rather than the entry, because the state that
was logged exists nowhere else: `org-agenda-get-progress' writes it into
the item's `extra' field as \"State:     (DONE)\" and attaches no text
property for it.  `:regexp' cannot be used here -- that selector tests the
entry's buffer text, where the LOGBOOK line is present for every log item
the entry produces, so it would discard the CLOSED item too."
  (string-match-p "State:\\s-+(\\(?:DONE\\|NOPE\\))" item))

(defun zetta-org-agenda--deadline-days (item)
  "Days from today until ITEM's deadline, or nil when it has none."
  (when-let* ((marker (zetta-org-agenda--marker item)))
    (org-with-point-at marker
      (when-let* ((stamp (org-entry-get (point) "DEADLINE"))
                  (day (ignore-errors (org-time-string-to-absolute stamp))))
        (- day (org-today))))))

(defun zetta-org-agenda-due-this-week-p (item)
  "Non-nil if ITEM is due in the next seven days, but not today."
  (when-let* ((days (zetta-org-agenda--deadline-days item)))
    (and (> days 0) (<= days 7))))

(defun zetta-org-agenda-due-this-month-p (item)
  "Non-nil if ITEM is due between a week and a month out."
  (when-let* ((days (zetta-org-agenda--deadline-days item)))
    (and (> days 7) (<= days 30))))

(defun zetta-org-agenda-due-later-p (item)
  "Non-nil if ITEM is due more than a month out."
  (when-let* ((days (zetta-org-agenda--deadline-days item)))
    (> days 30)))


;;;; The computed group sets

(defvar zetta-org-agenda-inbox-groups
  ;; Captures from the `n' and `N' templates are bare headings with no TODO
  ;; keyword, so they are invisible to `alltodo' and the Inbox view has to
  ;; be an org-ql block to see them at all.  That is also the first split
  ;; worth making: deciding whether a scrap IS a task is a different motion
  ;; from deciding where it belongs.
  '((:name "Not yet a task -- decide what it is" :not (:todo t) :order 0)
    (:name "A task -- refile it somewhere" :todo t :order 1))
  "Grouping for the Inbox view.")

(defvar zetta-org-agenda-project-groups
  ;; `:auto-parent' rather than `:auto-outline-path': the immediate parent
  ;; IS the project for this corpus, and a full path turns a depth-5 entry
  ;; in \"(todo) emacs - categorized.org\" into a header wider than the
  ;; window.  Top-level entries have no parent, so the auto group skips
  ;; them and the catch-all names them rather than letting them fall into
  ;; org-super-agenda's unnamed \"Other items\".
  '((:discard (:todo ("HOLD" "IDEA")))
    (:auto-parent t)
    (:name "Standalone -- not under any project" :anything t :order 9))
  "Grouping for the Projects view.")

(defvar zetta-org-agenda-stalled-groups
  ;; Ordered freshest first so the view reads as a slope, and the bottom of
  ;; the buffer is the part that should worry you.
  '((:discard (:todo ("HOLD" "IDEA")))
    (:name "Touched this week" :pred zetta-org-agenda-touched-week-p :order 0)
    (:name "Touched this month" :pred zetta-org-agenda-touched-month-p :order 1)
    (:name "Quiet for one to three months" :pred zetta-org-agenda-touched-quarter-p :order 2)
    (:name "Quiet for over three months" :pred zetta-org-agenda-touched-long-ago-p :order 3)
    (:name "No timestamp at all -- age unknown" :pred zetta-org-agenda-never-touched-p :order 4))
  "Grouping for the Stalled view.")

(defvar zetta-org-agenda-chase-groups
  ;; WAIT and QUES only.  Discarding the complement rather than selecting
  ;; with a `todo' agenda type keeps this a plain `alltodo' block, so it
  ;; inherits the same prefix and sorting as every other backlog view.
  ;;
  ;; Grouped by age because that is the only question a chase list answers:
  ;; a thing you have been waiting on for a week is a different object from
  ;; one you have been waiting on since March.
  '((:discard (:not (:todo ("WAIT" "QUES"))))
    ;; Named people first.  `:auto-property' yields no key for an entry
    ;; without WAITING_ON, so those fall through to the age buckets below --
    ;; which is the useful split: a chase list you can act on, and under it
    ;; the ones you cannot because you never wrote down who has it.
    (:auto-property "WAITING_ON")
    (:name "Nobody named -- waiting under a week" :pred zetta-org-agenda-touched-week-p :order 5)
    (:name "Nobody named -- waiting over a week" :pred zetta-org-agenda-touched-month-p :order 6)
    (:name "Nobody named -- over a month, chase or drop" :pred zetta-org-agenda-touched-quarter-p :order 7)
    (:name "Nobody named -- over three months, almost certainly dead" :pred zetta-org-agenda-touched-long-ago-p :order 8)
    (:name "Nobody named -- undated" :anything t :order 9))
  "Grouping for the Chase view.")

(defvar zetta-org-agenda-parked-groups
  ;; The inverse of every other view here, all of which discard HOLD and
  ;; IDEA.  Without this they are reachable only through `alltodo' and the
  ;; Untriaged view, which is how a someday list quietly becomes a
  ;; graveyard.
  '((:discard (:not (:todo ("HOLD" "IDEA"))))
    (:name "Due for another look -- REVIEW_ON has arrived"
           :pred zetta-org-agenda-review-due-p :order 0)
    (:auto-todo t))
  "Grouping for the Parked view.")

(defvar zetta-org-agenda-capacity-groups
  ;; Buckets ascend and the first match wins, so each group is really
  ;; \"under X and not under any smaller X\".  `:effort<' is inclusive, so
  ;; the bounds are one minute past the intended ceiling.
  ;;
  ;; \"Unestimated\" is the catch-all for the same reason \"Uncontexted\" is
  ;; in the Context view: on an unmigrated corpus it holds everything, and
  ;; watching it drain is the only progress signal the estimate pass gets.
  '((:discard (:todo ("HOLD" "IDEA")))
    (:name "Under a quarter of an hour" :effort< "0:16" :order 0)
    (:name "Under an hour" :effort< "1:01" :order 1)
    (:name "Under three hours" :effort< "3:01" :order 2)
    (:name "Three hours or more -- probably a project" :effort> "3:00" :order 3)
    (:name "Unestimated" :anything t :order 9))
  "Grouping for the Capacity view.")

(defvar zetta-org-agenda-horizon-groups
  ;; Deadlines only.  `:deadline past' and `today' are org-super-agenda's
  ;; own; the further buckets are predicates because the built-in `future'
  ;; is a single undifferentiated bucket and `before'/`after' want a fixed
  ;; date string rather than an offset from today.
  '((:discard (:todo ("HOLD" "IDEA")))
    (:name "Overdue" :deadline past :order 0)
    (:name "Due today" :deadline today :order 1)
    (:name "Due this week" :pred zetta-org-agenda-due-this-week-p :order 2)
    (:name "Due this month" :pred zetta-org-agenda-due-this-month-p :order 3)
    (:name "Due later" :pred zetta-org-agenda-due-later-p :order 4)
    (:name "No deadline" :deadline nil :order 9))
  "Grouping for the Horizon view.")

(defvar zetta-org-agenda-priority-groups
  ;; `:auto-priority' reads the literal cookie rather than Org's computed
  ;; priority, so an un-cookied entry yields no key and would fall into
  ;; org-super-agenda's unnamed "Other items".  Naming that bucket is the
  ;; point of the view: the honest ladder is A/B/C against the pile that has
  ;; never been ranked at all, and on this corpus that pile is the majority.
  '((:discard (:todo ("HOLD" "IDEA")))
    (:auto-priority t)
    (:name "No priority cookie -- never ranked" :anything t :order 9))
  "Grouping for the Priority view.")

(defvar zetta-org-agenda-area-groups
  '((:discard (:todo ("HOLD" "IDEA")))
    (:auto-property "MISSION")
    (:auto-category t))
  "Grouping for the Areas view.

Category falls back to the file name until a file declares `#+CATEGORY',
so on an unmigrated corpus this is a file listing wearing a better name.")

(defvar zetta-org-agenda-review-groups
  ;; Log-mode items only.  `:log' matches on the agenda item's `type'
  ;; property, which only exists on entries the agenda emitted IN log mode,
  ;; so the command that uses this must turn log mode on -- and the final
  ;; discard drops the ordinary scheduled/deadline items that would
  ;; otherwise share the block.
  ;;
  ;; The middle discard exists because one DONE transition produces TWO log
  ;; items: a "closed" item from the CLOSED stamp and a "state" item from
  ;; the LOGBOOK line, at the same timestamp.  Without it every finished
  ;; task is listed twice, once per group.  It has to match on the rendered
  ;; text because the state that was logged is not carried as a text
  ;; property anywhere -- `org-agenda-get-progress' puts it only in the
  ;; item's prefix, as "State:     (DONE)" (org-agenda.el, the `statep'
  ;; branch), which only a `:pred' can see -- `:regexp' tests the entry's
  ;; buffer text instead.  Matching `:todo' would be wrong for a different
  ;; reason: an entry that moved to PROG last week and finished this week is
  ;; currently DONE, so a `:todo' test would throw away that PROG transition
  ;; as well.
  '((:name "Finished" :log closed :order 0)
    (:discard (:pred zetta-org-agenda-done-state-log-p))
    (:name "Moved -- state changed" :log state :order 1)
    (:discard (:anything t)))
  "Grouping for the Review view.")

(defvar zetta-org-agenda-blocked-groups
  ;; BLOCKED_BY is the property `org-queue-harvest' already reads, so this
  ;; view and the queue agree on what \"blocked\" means.
  '((:discard (:todo ("HOLD" "IDEA")))
    (:name "Blocked by something else" :property "BLOCKED_BY" :order 0)
    (:name "Blocked on a person" :todo ("WAIT" "QUES") :order 1)
    (:name "Ready -- nothing in the way" :anything t :order 2))
  "Grouping for the Blocked view.")

(use-package org-super-agenda
  :after org-agenda
  :config
  ;; A global minor mode, but it only does anything inside an agenda
  ;; buffer -- it advises the agenda's finalisation, so enabling it at
  ;; org-agenda load costs nothing until an agenda is actually built.
  (org-super-agenda-mode 1)
  ;; The group headers inherit a keymap that shadows `q', `j' and friends
  ;; with header-local commands; that fights every modal state in this
  ;; config, and the headers are decoration, not UI.
  (setq org-super-agenda-header-map (make-sparse-keymap)))
;;; org-super-agenda.el ends here
