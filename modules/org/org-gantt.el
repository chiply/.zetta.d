;;; org-gantt.el --- Configure org-gantt -*- lexical-binding: t; -*-

;; Thin wrapper around the in-tree `org-gantt' package (under
;; `source/zettapkg/').  When it is factored out to its own repo, swap
;; `:ensure nil' + `:load-path' for `:ensure t'.
;;
;; `M-x org-gantt' (,-o-w) draws the last week as a Gantt: one row per
;; task, what was planned above what happened, and under the chart the
;; table it was drawn from -- press TAB on a row to see the state
;; transitions its bar was built from.  `,-o-W' shows the same data as a
;; week grid, with the plan and the actual in each day column.
;;
;; No clock runs anywhere in this config.  Time comes from the LOGBOOK
;; transitions that `org-todo-keywords' already writes, read by
;; `org-queue-state-log' -- one parser, so the chart and the queue can
;; never disagree about how long something took.  See the package README
;; and Part 3.2 of productivity.org (G15).
;;
;; Three things are configured here, and all three are local facts the
;; package cannot know: which states count as work, what a working day
;; looks like, and how the chart should look in this theme.

(defvar brushup-styles)
(defvar brushup-fg)
(defvar brushup-fg-1)
(defvar brushup-fg-2)
(defvar brushup-fg-3)
(defvar brushup-fg-4)
(defvar brushup-fg-5)
(defvar brushup-fg-6)
(defvar org-queue-working-states)
;; Private, hence guarded at the call site: a redraw of an open chart is
;; the only way a theme change reaches an SVG whose colours are baked in.
(declare-function org-gantt--draw "org-gantt" (&optional keep-point))

(defcustom zetta-org-gantt-rungs
  '((org-gantt-worked        . brushup-fg)
    (org-gantt-waiting       . brushup-fg-3)
    (org-gantt-idle          . brushup-fg-5)
    (org-gantt-span          . brushup-fg-6)
    (org-gantt-plan-queue    . brushup-fg-2)
    (org-gantt-plan-schedule . brushup-fg-4)
    (org-gantt-deadline      . brushup-fg)
    (org-gantt-axis          . brushup-fg-4)
    (org-gantt-rule          . brushup-fg-6)
    (org-gantt-label         . brushup-fg-1)
    (org-gantt-number        . brushup-fg-3)
    (org-gantt-group         . brushup-fg)
    (org-gantt-transition    . brushup-fg-4)
    (org-gantt-now           . brushup-fg-2)
    (org-gantt-table-header  . brushup-fg-2))
  "Map each chart face to a brushup ink variable.

A prominence ladder, not a code.  Work is the most present thing on a
row; waiting sits a rung down, because \"blocked for three days\" and
\"ignored for three days\" are different findings and a chart that drew
them alike would hide the more actionable one.  The plan is quieter
than the actual everywhere, because the chart is about what happened
and the plan is what it is measured against.

Nothing here is red-for-late.  A deadline is a fact rather than an
alarm, so it earns the top rung and a shape -- a diamond -- and no
colour of its own."
  :type '(alist :key-type face :value-type symbol)
  :group 'zetta)

(defun zetta-org-gantt-apply-palette ()
  "Take the chart's faces from the theme, per `zetta-org-gantt-rungs'.

Also redraw any live chart: the buffer holds one SVG whose colours were
baked in when it was rendered, so a theme change that did not redraw
would leave the old theme's ink on screen until the next keypress."
  (when (facep 'org-gantt-worked)
    (pcase-dolist (`(,face . ,rung) zetta-org-gantt-rungs)
      (set-face-attribute
       face nil
       :foreground (or (and (boundp rung) (symbol-value rung))
                       (face-foreground 'default nil t))))
    ;; Two faces carry weight as well as ink; the ladder cannot say that.
    (dolist (face '(org-gantt-deadline org-gantt-group org-gantt-table-header))
      (set-face-attribute face nil :weight 'bold)))
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'org-gantt-mode)
        (ignore-errors (org-gantt--draw t))))))

(use-package org-gantt
  :ensure nil
  :load-path "source/zettapkg/org-gantt"
  :commands (org-gantt org-gantt-today
             org-gantt-timegrid-composite
             org-gantt-timegrid-spent
             org-gantt-timegrid-planned)
  :autoload (org-dblock-write:org-gantt-table)

  :brushup
  (add-to-list 'brushup-styles '(zetta-org-gantt-apply-palette))

  :init
  ;; The working day, as minutes after midnight.  This is the only place
  ;; the config asserts what a day looks like, and it is a placeholder
  ;; with a known replacement: G6's routine table in ~/kb/notes/schedule.org
  ;; is already an Org table of exactly this shape, and when it is parsed
  ;; this variable is set from it and every number follows.
  ;;
  ;; The weekend is short rather than absent, to agree with
  ;; `org-queue-capacity', which budgets 90 minutes on a Saturday: a grid
  ;; that clipped the weekend to nothing would show Saturday's work
  ;; vanishing while the queue kept planning it.
  (setq org-gantt-window
        '((0 . ((600 . 690)))          ; Sunday, 10:00-11:30
          (6 . ((600 . 690)))          ; Saturday
          (t . ((480 . 720) (810 . 1080)))))

  :config
  ;; Once on load as well as on every theme change: `brushup-styles' may
  ;; already have run before this package's faces existed.
  (zetta-org-gantt-apply-palette)

  ;; One vocabulary for "this counts as work", shared with the queue --
  ;; including STARTED, which is this kb's older name for PROG and which
  ;; the real files still carry.  Set rather than defaulted, so a change
  ;; in one place cannot leave the chart and the calibration disagreeing.
  (with-eval-after-load 'org-queue-harvest
    (setq org-gantt-working-states org-queue-working-states))

  ;; The chart's keymap is single-letter and dense -- n/p/j/k move, f/b
  ;; page the range, s scopes, g refreshes, q quits -- every one of which
  ;; evil's normal state would shadow with a motion.  Same call as
  ;; org-timegrid, for the same reason.
  (with-eval-after-load 'evil
    (evil-set-initial-state 'org-gantt-mode 'emacs)))

;; `,ow' the timeline, `,oW' the week grid -- next to `,oc', the writable
;; planning grid, since the three are one family: what you intend, what
;; you committed to, and what actually happened.
(general-define-key
 :keymaps 'menu-org-map
 "w" 'org-gantt
 "W" 'org-gantt-timegrid-composite)
;;; org-gantt.el ends here
