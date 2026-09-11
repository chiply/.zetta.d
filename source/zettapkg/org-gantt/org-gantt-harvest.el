;;; org-gantt-harvest.el --- Org entries and org-ql queries into chart rows -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (org-ql "0.8") (org-queue "0.1.0"))
;; Keywords: convenience, calendar

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; The Org half: a query, a set of files and a date range in, chart rows
;; out.  The arithmetic is all in `org-gantt-core'; nothing here computes
;; a duration.
;;
;; ONE PARSER.  The state log is read by `org-queue-state-log', not by a
;; second regexp of this package's own.  That parser already knows the
;; two things that matter about the real kb -- that the `from' field is
;; usually blank, and that STARTED/CANCELLED/OBSOLETE are this kb's older
;; vocabulary and must measure as well as PROG does -- and a chart that
;; disagreed with the queue about how long something took would be worse
;; than no chart.  See `org-queue-harvest.el'.
;;
;; TWO CLOCKS, DELIBERATELY.  `:worked' counts only what falls inside the
;; charted range, so the numbers under the chart add up to the bars on
;; it.  `:lifetime' is measured from the entry's first transition ever to
;; its last, whether or not either is on screen, so a task that has been
;; open for three weeks says so in a one-week view.
;;
;; THE PLAN LAYER has two sources and they are drawn differently, because
;; they are different claims:
;;
;;   queue     the day's committed plan, from `org-queue-history' -- you
;;             said you would do this, on this day
;;   schedule  a SCHEDULED stamp plus `:Effort:' -- it merely has a date
;;
;; Neither source records an hour: `org-queue-record-plan' writes ids,
;; and a date-only SCHEDULED is a day, not a time.  So only a stamp that
;; names an hour becomes a fixed block; everything else is handed to
;; `org-gantt-core-place-plans' as a day and a duration and flows through
;; the day's windows.  The planned lane is therefore the SHAPE of the
;; day, not a claim about 09:15, and it should not be read as one.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-ql)
(require 'org-duration)
(require 'org-queue-harvest)
(require 'org-gantt-core)

;; `org-ql-defpred' rewrites this at expansion time; it exists at runtime
;; because org-ql is required above, but the compiler cannot see that.
(declare-function org-ql--normalize-query "org-ql" (query))

(defcustom org-gantt-files nil
  "Files to chart.  Nil means `org-agenda-files'.

Which, with `zetta-org-toggle-todo-source', is whichever corpus is
live -- so the chart follows the toggle rather than keeping a second
opinion about where the tasks are."
  :type '(choice (const :tag "org-agenda-files" nil) (repeat file))
  :group 'org-gantt)

(defcustom org-gantt-default-effort 30
  "Minutes a plan is assumed to want when the entry carries no `:Effort:'.

The queue makes the same assumption for the same reason: refusing to
plan an unestimated task teaches you to estimate by punishing you, and
the whole system loses to a checkbox list the week that happens."
  :type 'integer
  :group 'org-gantt)


;;;; Time helpers

(defun org-gantt-harvest--seconds (time)
  "Return Emacs TIME as integer epoch seconds, or nil for nil."
  (when time (floor (float-time time))))

(defun org-gantt-time (spec &optional default)
  "Resolve SPEC to epoch seconds.

SPEC may be a number of days relative to today (negative for the past,
which is how `org-ql' spells it), an Org timestamp or date string, an
Emacs time value, or nil for DEFAULT.  One reader for every place a
range can be typed."
  (cond
   ((null spec) default)
   ((numberp spec)
    (+ (org-gantt-core-day-start (floor (float-time)))
       (* spec 60 60 24)))
   ((stringp spec)
    (org-gantt-harvest--seconds (org-time-string-to-time spec)))
   (t (org-gantt-harvest--seconds spec))))


;;;; One entry

(defun org-gantt-harvest--title ()
  "Return the current heading, without keyword, priority, tags or cookie.

The cookie goes because a chart row is already a progress bar and two
progress readings on one line disagree the moment a child moves."
  (let ((heading (org-get-heading t t t t)))
    (string-trim (replace-regexp-in-string
                  "\\[[0-9]*\\(?:%\\|/[0-9]*\\)\\]" "" heading))))

(defun org-gantt-harvest--effort ()
  "Return the current entry's `:Effort:' in minutes, or nil."
  (when-let* ((effort (org-entry-get nil "Effort")))
    (ignore-errors (round (org-duration-to-minutes effort)))))

(defun org-gantt-harvest--property-time (property)
  "Return PROPERTY of the current entry as epoch seconds, or nil."
  (when-let* ((value (org-entry-get nil property)))
    (org-gantt-harvest--seconds
     (ignore-errors (org-time-string-to-time value)))))

(defun org-gantt-harvest--intervals (&optional now)
  "Return the current entry's intervals in the core's shape.

`org-queue-state-intervals' does the reading; this only changes the
units.  Its last interval always runs to NOW -- for a finished entry
that is the DONE interval, which the core drops, and for a live one it
is the open bar."
  (mapcar (lambda (interval)
            (list :state (plist-get interval :state)
                  :start (org-gantt-harvest--seconds (plist-get interval :start))
                  :end (org-gantt-harvest--seconds (plist-get interval :end))
                  :open (plist-get interval :open)))
          (org-queue-state-intervals nil now)))

(defconst org-gantt-harvest--timed-stamp-re
  (concat "<\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}"
          "[^>\n]*?[0-9]\\{1,2\\}:[0-9]\\{2\\}[^>\n]*\\)>")
  "Matches an active timestamp that names an hour.
Only these can become fixed blocks; a date-only stamp is a day.")

(defun org-gantt-harvest--appointments ()
  "Return the current entry's timed active stamps as fixed plans.

Its own body only: the LOGBOOK is skipped, since a stamp in there is
history rather than an appointment, and children are not read, so a
parent is never credited with its subtree's meetings."
  (save-excursion
    (save-restriction
      (widen)
      (org-back-to-heading t)
      (let ((end (save-excursion (outline-next-heading) (point)))
            plans)
        (forward-line)
        (while (re-search-forward org-gantt-harvest--timed-stamp-re end t)
          (unless (save-excursion
                    (goto-char (match-beginning 0))
                    (or (org-at-planning-p)
                        (looking-back "^[ \t]*- State.*" (line-beginning-position))))
            (when-let* ((start (org-gantt-harvest--seconds
                                (ignore-errors
                                  (org-time-string-to-time (match-string 1))))))
              (push (list :kind 'schedule
                          :start start
                          :end (+ start (* 60 (or (org-gantt-harvest--effort)
                                                  org-gantt-default-effort))))
                    plans))))
        (nreverse plans)))))

(defun org-gantt-harvest--scheduled-plan (from to)
  "Return a plan from the current entry's SCHEDULED stamp, if it lands in FROM..TO.

A stamp that names an hour is a fixed block; a date-only stamp becomes
a day and a duration for the packer to place."
  (when-let* ((scheduled (org-get-scheduled-time nil))
              (seconds (org-gantt-harvest--seconds scheduled)))
    (when (and (>= seconds from) (< seconds to))
      (let ((minutes (or (org-gantt-harvest--effort) org-gantt-default-effort))
            (timed (let ((raw (org-entry-get nil "SCHEDULED")))
                     (and raw (string-match-p "[0-9]:[0-9][0-9]" raw)))))
        (if timed
            (list :kind 'schedule :start seconds :end (+ seconds (* 60 minutes)))
          (list :kind 'schedule
                :day (org-gantt-core-day-start seconds)
                :minutes minutes))))))

(defun org-gantt-harvest--queue-plans (id from to)
  "Return plans for ID from the recorded queue history between FROM and TO.

The history records which ids a day planned, never how long they were
given (see `org-queue-record-plan'), so the duration is the entry's
`:Effort:' as it stands now.  A plan reconstructed from an estimate
that has since changed is a reconstruction, and the chart says so in
its header rather than pretending otherwise."
  (when id
    (let ((minutes (or (org-gantt-harvest--effort) org-gantt-default-effort)))
      (delq nil
            (mapcar
             (lambda (record)
               (when (member id (plist-get record :ids))
                 (let* ((date (plist-get record :date))
                        (day (org-gantt-core-day-start
                              (floor (float-time
                                      (encode-time
                                       (list 0 0 12
                                             (% date 100)
                                             (% (/ date 100) 100)
                                             (/ date 10000)
                                             nil -1 nil)))))))
                   (when (and (>= day from) (< day to))
                     (list :kind 'queue :day day :minutes minutes)))))
             (org-queue-history))))))

(defun org-gantt-harvest-entry (from to &optional now)
  "Return the entry at point as a chart row, measured over FROM..TO."
  (let* ((now (or now (floor (float-time))))
         (id (org-entry-get nil "ID"))
         (all (org-gantt-harvest--intervals now))
         (within (delq nil
                       (mapcar (lambda (interval)
                                 (let ((start (max (plist-get interval :start) from))
                                       (end (min (or (plist-get interval :end) now) to)))
                                   (when (< start end)
                                     (list :state (plist-get interval :state)
                                           :start start :end end
                                           :open (and (plist-get interval :open)
                                                      (>= to now))))))
                               all)))
         (born (when all (plist-get (car all) :start)))
         (died (when all (apply #'max (mapcar (lambda (i)
                                                (or (plist-get i :end) now))
                                              all)))))
    (list :id (or id (format "%s:%d" (buffer-file-name) (point)))
          :marker (point-marker)
          :title (org-gantt-harvest--title)
          :file (buffer-file-name)
          :category (org-get-category)
          :state (org-get-todo-state)
          :priority (org-entry-get nil "PRIORITY")
          :tags (org-get-tags nil t)
          :effort (org-gantt-harvest--effort)
          :created (org-gantt-harvest--property-time "CREATED")
          :closed (org-gantt-harvest--property-time "CLOSED")
          :deadline (org-gantt-harvest--seconds (org-get-deadline-time nil))
          :scheduled (org-gantt-harvest--seconds (org-get-scheduled-time nil))
          :lifetime (when born (org-gantt-core-minutes born died))
          :born born
          :truncated (and born (< born from))
          :intervals within
          :plans (append (delq nil (list (org-gantt-harvest--scheduled-plan from to)))
                         (cl-remove-if-not
                          (lambda (plan) (and (>= (plist-get plan :start) from)
                                              (< (plist-get plan :start) to)))
                          (org-gantt-harvest--appointments))
                         (org-gantt-harvest--queue-plans id from to)))))


;;;; org-ql predicates

;; Two predicates the query language cannot otherwise express, both over
;; the derived clock.  Without them a chart can only be scoped by static
;; metadata -- and "everything tagged @deep" over a week is ninety rows,
;; eighty of which were never touched.  What you actually want to ask is
;; "what did I work on", and that question lives in the LOGBOOK.

(defun org-gantt-harvest--matching-interval-p (from to states)
  "Return non-nil when the entry at point held one of STATES between FROM and TO."
  (let ((from (or from 0))
        (to (or to most-positive-fixnum))
        (now (floor (float-time))))
    (cl-some (lambda (interval)
               (let ((start (plist-get interval :start))
                     (end (or (plist-get interval :end) now)))
                 (and (or (null states)
                          (member (plist-get interval :state) states))
                      (< start to)
                      (> end from))))
             (org-gantt-harvest--intervals))))

(org-ql-defpred worked-on (&optional from to)
  "Return non-nil if the entry was in a working state between FROM and TO.

FROM and TO are days relative to today when numbers (so -7 is a week
ago), or date strings.  Both may be omitted, which asks whether the
entry was ever worked on at all.

This is the derived clock, not `clocked': nothing here writes CLOCK
lines, and the evidence is the state log."
  :body
  (org-gantt-harvest--matching-interval-p
   (org-gantt-time from) (org-gantt-time to)
   org-gantt-working-states))

(org-ql-defpred state-during (state &optional from to)
  "Return non-nil if the entry held STATE between FROM and TO.

STATE may be a string or a list of them.  \"What sat in WAIT all
week\" is the question this exists for; the answer is not derivable
from the entry's current state, because by the time you ask it has
usually moved."
  :body
  (org-gantt-harvest--matching-interval-p
   (org-gantt-time from) (org-gantt-time to)
   (if (listp state) state (list state))))


;;;; The harvest

(defcustom org-gantt-query '(and (not (tags "ARCHIVE")) (worked-on))
  "The org-ql query a chart starts from.

Deliberately the widest useful net rather than the smallest: the range
does most of the filtering, `worked-on' drops everything the range
never touched, and scoping further is a keystroke in the chart (`s')
where it is cheap to change your mind."
  :type 'sexp
  :group 'org-gantt)

(defun org-gantt-harvest-files ()
  "Return the files to chart."
  (or org-gantt-files (org-agenda-files)))

(cl-defun org-gantt-harvest (&key query files from to now (prune t))
  "Return chart rows for QUERY over FILES, measured across FROM..TO.

Rows carry every field the table prints and the chart draws; the
measuring is `org-gantt-core-chart's job, not this one's.

Unless PRUNE is nil, a row that neither happened nor was planned inside
the range is dropped.  The query says which tasks are interesting; the
range says which of them this chart is about, and a query like
`(worked-on)' -- ever worked on -- otherwise fills a week's chart with
rows whose bars are all in some other month."
  (let* ((now (or now (floor (float-time))))
         (from (or from (- now (* 7 60 60 24))))
         (to (or to now))
         (query (or query org-gantt-query))
         (rows (org-ql-select (or files (org-gantt-harvest-files))
                 query
                 :action (lambda () (org-gantt-harvest-entry from to now)))))
    (if prune
        (cl-remove-if (lambda (row)
                        (and (null (plist-get row :intervals))
                             (null (plist-get row :plans))))
                      rows)
      rows)))

(provide 'org-gantt-harvest)
;;; org-gantt-harvest.el ends here
