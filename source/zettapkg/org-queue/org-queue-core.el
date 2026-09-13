;;; org-queue-core.el --- Scoring and packing a day's task queue -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience, calendar

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; The queue's arithmetic, with no Org in it.
;;
;; Everything here takes a list of plists and returns a list of plists, so
;; the formula can be argued with in `emacs -Q --batch' against hand-built
;; fixtures -- no agenda, no files, no clock.  `org-queue-harvest' turns
;; real Org entries into these plists; `org-queue' renders the result.
;; Nothing in this file knows either of them exists.
;;
;; A task plist:
;;
;;   (:id "abc" :file "(todo) work.org" :category "work"
;;    :title "Cut the 0.4.0 release" :state "TODO" :priority ?B
;;    :scheduled 20260908 :deadline 20260912 :effort 120 :created 20260814
;;    :tags ("@deep" "release") :clocked 0 :blocked-by ("def")
;;    :carried 1 :timestamp 20260908 :timestamp-past nil)
;;
;; `:timestamp' is the next occurrence of a plain active timestamp on or
;; after the day being planned, and `:timestamp-past' the most recent one
;; before it.  They are how appointments enter the day: a meeting is a
;; fixed point, not a task, so it is neither scored nor moved.
;;
;; Dates are integers, YYYYMMDD, because that orders correctly under `<'
;; and prints readably in a failing test.  Durations are minutes.  Absent
;; is nil and means absent -- `:effort' nil is "unestimated", NOT zero, and
;; `:priority' nil is "never triaged", which is a real value scored between
;; B and C rather than the bottom of the pile (see
;; `org-queue-priority-weights').
;;
;; The entry point is `org-queue-core-plan'.  It returns a plist describing
;; a day: what is committed, what was chosen, what was cut and why.  That
;; last part is not decoration -- a planner you cannot interrogate gets
;; distrusted and abandoned, so every task handed in comes back out in
;; exactly one of `:planned', `:cut', `:dropped' or `:deferred'.

;;; Code:

(require 'cl-lib)

(defgroup org-queue nil
  "Fill a day from the backlog."
  :group 'org
  :prefix "org-queue-")


;;;; Capacity

(defcustom org-queue-capacity
  '((0 . 120) (1 . 300) (2 . 300) (3 . 300) (4 . 300) (5 . 240) (6 . 120))
  "Minutes of task time available, by day of week (0 = Sunday).

A placeholder, not a truth: the honest number comes from clocking
normally for a fortnight and reading it off.  Monday is not Saturday,
which is why this is per-weekday rather than one number."
  :type '(alist :key-type (integer :tag "Day of week (0 = Sunday)")
                :value-type (integer :tag "Minutes"))
  :group 'org-queue)

(defcustom org-queue-slack-fraction 0.2
  "Fraction of the day's capacity left unplanned.

A plan with no slack is wrong by lunchtime.  0.2 of five hours is an
hour of nothing-in-particular, which is roughly what a day costs in
interruption."
  :type 'float
  :group 'org-queue)

(defcustom org-queue-default-effort 30
  "Minutes assumed for a task with no `:effort'.

Deliberately not a requirement: an unestimated task is still queueable,
it is just planned against a guess -- and the plan says so."
  :type 'integer
  :group 'org-queue)

(defcustom org-queue-wip-limit 3
  "Most PROG tasks allowed in one day's plan.

Committed PROG tasks count toward the limit but are never dropped by
it -- a commitment outranks a policy."
  :type 'integer
  :group 'org-queue)


;;;; Buckets
;;
;; A day is not one pool of minutes but a few with names: focus work,
;; reading, housekeeping.  Each is a reservation AND a limit -- the packer
;; fills it even when better-scoring work exists elsewhere, and never past
;; its minutes.  With no buckets defined, `org-queue-capacity' is the one
;; and only bucket and nothing below changes a thing.

(defcustom org-queue-buckets nil
  "Named budgets of minutes per day, each claiming tasks by tag or category.

Each element is (NAME . PLIST) with

  :minutes  an integer, or a per-weekday alist like `org-queue-capacity'
            (a weekday absent from the alist closes the bucket that day)
  :match    a plist of :category (a list of names), :tags (any of),
            :pred (a function of the task plist); the FIRST bucket whose
            match holds claims the task, in list order
  :spill    when non-nil, minutes this bucket did not use are handed to
            the `default' bucket at the end of packing

A task no bucket claims belongs to `default'; a table without a
`default' entry leaves such tasks with nowhere to go, and they are cut
with reason `bucket-closed' -- visibly, on purpose.  Nil means one
bucket, `default', whose minutes are `org-queue-capacity'."
  :type '(alist :key-type symbol :value-type plist)
  :group 'org-queue)

(defun org-queue-core--weekday-minutes (minutes date)
  "Resolve MINUTES, an integer or per-weekday alist, for DATE."
  (cond ((integerp minutes) minutes)
        ((consp minutes)
         (or (alist-get (org-queue-core-day-of-week date) minutes) 0))
        (t 0)))

(defun org-queue-core-bucket-specs ()
  "Return the bucket table in force: `org-queue-buckets' or the default."
  (or org-queue-buckets
      (list (list 'default :minutes org-queue-capacity))))

(defun org-queue-core--match-p (task match)
  "Return non-nil if TASK satisfies MATCH, a bucket's :match plist."
  (let ((category (plist-get match :category))
        (tags (plist-get match :tags))
        (pred (plist-get match :pred)))
    (or (and category (member (plist-get task :category) category))
        (and tags (cl-intersection tags (plist-get task :tags) :test #'equal))
        (and pred (funcall pred task)))))

(defun org-queue-core-bucket (task)
  "Return the name of the bucket that claims TASK."
  (or (cl-loop for (name . spec) in (org-queue-core-bucket-specs)
               when (and (plist-get spec :match)
                         (org-queue-core--match-p task (plist-get spec :match)))
               return name)
      'default))

(defun org-queue-core-bucket-capacity (name date)
  "Return the minutes bucket NAME has on DATE, 0 if it does not exist."
  (let ((spec (alist-get name (org-queue-core-bucket-specs))))
    (if spec (org-queue-core--weekday-minutes (plist-get spec :minutes) date) 0)))


;;;; Habits
;;
;; A habit is time already decided -- the lift, the bike, the dishes --
;; not a task to be finished.  It never competes with the backlog: it is
;; subtracted from its bucket before packing begins and shown so the day
;; adds up.  `:habit' is set by the harvest from STYLE=habit; `:habit-days'
;; is the weekday set from HABIT_DAYS, nil meaning every day.

(defun org-queue-core-habit-p (task)
  "Return non-nil if TASK is a habit rather than a task."
  (plist-get task :habit))

(defun org-queue-core-habit-applies-p (task date)
  "Return non-nil if habit TASK falls on DATE."
  (let ((days (plist-get task :habit-days)))
    (or (null days) (memq (org-queue-core-day-of-week date) days))))


;;;; Backpressure
;;
;; A deadline pushes work backwards.  START-BY is the latest day on which
;; the effort still fits into the free minutes of the days up to the
;; deadline; from that day the task is a commitment, not a candidate.
;; The horizon simulator supplies real free minutes through
;; `org-queue-core-free-minutes-function'; alone, the day packer
;; approximates with each day's bucket capacity less slack.

(defcustom org-queue-start-by t
  "When non-nil, a hard deadline commits a task from its start-by day."
  :type 'boolean
  :group 'org-queue)

(defvar org-queue-core-free-minutes-function nil
  "Function of (BUCKET DATE) returning the minutes free for planning.
Nil means the bucket's capacity less `org-queue-slack-fraction'.")

(defvar org-queue-core-slice-commitments nil
  "When non-nil, a commitment that does not fit is planned as a slice.

Bound by the horizon simulator.  A slice carries `:slice' and a
`:queue-minutes' smaller than the effort; what is left stays in the pool
for the next day.  Only commitments are sliced, never candidates.  A day
in the simulation therefore never overflows; a deadline the days cannot
cover is reported by the horizon as missed instead.")

(defvar org-queue-core-placed-soft nil
  "When non-nil, a machine placement is a candidate, not a commitment.

Bound while proposing, so the planner may move what it placed itself.
A SCHEDULED a person wrote is a commitment either way.")

(defcustom org-queue-min-slice 15
  "Smallest slice of a task worth planning, in minutes."
  :type 'integer
  :group 'org-queue)

(defun org-queue-core-free-minutes (bucket date)
  "Return the minutes BUCKET has free for planning on DATE."
  (if org-queue-core-free-minutes-function
      (funcall org-queue-core-free-minutes-function bucket date)
    (round (* (org-queue-core-bucket-capacity bucket date)
              (- 1.0 org-queue-slack-fraction)))))

(defvar org-queue-core-start-by-task nil
  "The task whose start-by is being computed, for the free-minutes function.
Its own deadline-day minutes must not count as already booked.")

(defun org-queue-core-start-by (task today minutes)
  "Return the day TASK must start by to finish MINUTES before its deadline.

Walks back from the deadline, spending each day's free minutes, and
returns the day the effort is covered -- or TODAY when it is not
covered by then, which is to say it is already late.  Nil for a task
with no hard deadline, or a deadline already passed."
  (let ((deadline (plist-get task :deadline)))
    (when (and org-queue-start-by deadline
               (not (plist-get task :deadline-soft))
               (> deadline today))
      (let ((bucket (org-queue-core-bucket task))
            (org-queue-core-start-by-task task)
            (day deadline)
            (need minutes))
        (while (and (> need 0) (> day today))
          (setq need (- need (org-queue-core-free-minutes bucket day)))
          (when (> need 0) (setq day (org-queue-core-date-add day -1))))
        day))))


;;;; Filtering

(defcustom org-queue-done-states '("DONE" "NOPE")
  "States that mean the task is over.
Kept for calibration, never planned."
  :type '(repeat string)
  :group 'org-queue)

(defcustom org-queue-agent-states '("AGENT")
  "States meaning an agent holds the entry.
Excluded from the queue with reason `in-flight'; never human capacity."
  :type '(repeat string)
  :group 'org-queue)

(defcustom org-queue-excluded-states '("HOLD" "IDEA")
  "States that are not commitments and never enter the queue.

HOLD is paused by choice and IDEA is someday/maybe; neither is work you
have agreed to do, so neither should compete for today's hours.  QUES is
deliberately absent -- an open question is still a live thread, so it
queues at a reduced weight instead (`org-queue-state-weights')."
  :type '(repeat string)
  :group 'org-queue)

(defcustom org-queue-context-tags
  '("@deep" "@shallow" "@errand" "@call" "@meeting" "@travel" "@social")
  "Tags treated as contexts -- where or how a task can be done.

Named explicitly rather than inferred from a leading @ so that a tag like
@home used as a topic does not silently become a scheduling constraint."
  :type '(repeat string)
  :group 'org-queue)

(defcustom org-queue-energy-tags '("@fresh" "@tired")
  "Tags treated as energy requirements."
  :type '(repeat string)
  :group 'org-queue)

(defcustom org-queue-contexts nil
  "Contexts available for the plan.  Nil means no restriction.

Set this to plan a day you already know the shape of -- a travel day, an
afternoon with no phone.  The queue was blind to context until now, which
is how a plan could open with an @errand you cannot run and a @call you
cannot make."
  :type '(choice (const :tag "No restriction" nil) (repeat string))
  :group 'org-queue)

(defcustom org-queue-energy nil
  "Energy available for the plan.  Nil means no restriction."
  :type '(choice (const :tag "No restriction" nil) (repeat string))
  :group 'org-queue)

(defun org-queue-core--tags-of-kind (task kind)
  "Return TASK's tags belonging to KIND, a list of known tags."
  (cl-remove-if-not (lambda (tag) (member tag kind))
                    (plist-get task :tags)))

(defun org-queue-core-available-p (task available kind)
  "Return non-nil if TASK is doable given AVAILABLE tags of KIND.

A task carrying no tag of this kind is always available.  That asymmetry
is deliberate and load-bearing: an untagged corpus must not vanish the
moment a restriction is set, so a restriction can only ever exclude work
that has explicitly declared itself unsuitable."
  (or (null available)
      (let ((own (org-queue-core--tags-of-kind task kind)))
        (or (null own)
            (cl-intersection own available :test #'equal)))))

(defcustom org-queue-wait-horizon-days 7
  "How far ahead a WAIT task's deadline has to be to earn a place.

Blocked work should nag, not occupy: WAIT is dropped unless its deadline
falls inside this many days, at which point being blocked is the
problem and you want to see it."
  :type 'integer
  :group 'org-queue)


;;;; Scoring

(defcustom org-queue-weights
  '((deadline . 10.0)
    (priority . 4.0)
    (impact   . 2.0)
    (age      . 1.5)
    (progress . 3.0)
    (quick    . 1.0)
    (carry    . 2.5)
    (stick    . 2.0)
    (mission  . 2.4)
    (glut     . 2.0))
  "Coefficients of the scoring formula.

  score =  deadline * urgency(days until deadline)
         + priority * priority weight
         + impact   * impact weight, -1 to 1 around a neutral 3
         + age      * log(1 + days since created)
         + progress * (state is PROG)
         + quick    * (effort <= `org-queue-quick-threshold')
         + carry    * (planned before and not finished)
         + stick    * (a machine placement already on this day, while proposing)
         + mission  * (serves a mission of the season; the priority-B weight)
         - glut     * (tasks already picked from this category)

The last term is the only one that is not a property of the task: it is
recomputed as the day fills, which is what stops one big file eating the
whole day."
  :type '(alist :key-type symbol :value-type float)
  :group 'org-queue)

(defcustom org-queue-priority-weights
  '((?A . 1.0) (?B . 0.6) (nil . 0.45) (?C . 0.3))
  "Weight per priority cookie.  The nil key is \"no cookie at all\".

Absent priority sits between B and C on purpose.  Most tasks are never
triaged, and a formula that treats untriaged as lowest quietly buries
the backlog it was built to surface."
  :type '(alist :key-type (choice character (const nil)) :value-type float)
  :group 'org-queue)

(defcustom org-queue-state-weights '(("QUES" . -1.5))
  "Flat score adjustments per TODO state.

PROG is not here -- it earns its boost from the `progress' weight, so
the two cannot drift apart.  QUES is docked because an open question is
not yet a commitment; whether that is right is an open question itself.

NEXT is not here either: it is handled by `org-queue-core-committed-p',
which takes it out of scoring altogether."
  :type '(alist :key-type string :value-type float)
  :group 'org-queue)

(defcustom org-queue-soft-deadline-factor 0.35
  "Multiplier applied to the urgency of a deadline marked soft.

A soft deadline still pulls -- it is a date you had a reason to write --
but at roughly a third of the weight, so it can no longer outrank work
that genuinely has to ship.  1.0 disables the distinction entirely."
  :type 'float
  :group 'org-queue)

(defcustom org-queue-impact-neutral 3
  "The IMPACT value that neither helps nor hurts a task's score.
An entry with no IMPACT is scored as this, so leaving it unset costs
nothing and the property stays optional."
  :type 'integer
  :group 'org-queue)

(defcustom org-queue-quick-threshold 15
  "Effort in minutes at or below which a task counts as quick."
  :type 'integer
  :group 'org-queue)


;;;; Calibration

(defcustom org-queue-calibrate t
  "When non-nil, scale estimates by measured clock/estimate ratios."
  :type 'boolean
  :group 'org-queue)

(defcustom org-queue-calibration-prior 3
  "Strength of the pull toward 1.0 for a thinly-evidenced category.

Two finished tasks are not a calibration.  A category's factor is the
weighted mean of what it measured and what it is assumed to be, with
this many phantom observations on the assumption's side."
  :type 'integer
  :group 'org-queue)

(defcustom org-queue-calibration-limits '(0.25 . 4.0)
  "Floor and ceiling for a calibration factor.
One catastrophically mis-clocked task should not quadruple a category."
  :type '(cons float float)
  :group 'org-queue)


;;;; Dates
;;
;; YYYYMMDD integers compare correctly with `<', which covers most of what
;; the planner asks of a date.  Differences need real day numbers, so
;; convert with the civil-to-days formula rather than pulling in calendar.el
;; -- it keeps this file dependency-free and it is exact for any Gregorian
;; date, which `float-time' arithmetic is not across a DST boundary.

(defun org-queue-core-day-number (date)
  "Return days since 1970-01-01 for DATE, an integer YYYYMMDD."
  (let* ((y (/ date 10000))
         (m (% (/ date 100) 100))
         (d (% date 100))
         (y (if (<= m 2) (1- y) y))
         (era (/ (if (>= y 0) y (- y 399)) 400))
         (yoe (- y (* era 400)))
         (doy (+ (/ (+ (* 153 (+ m (if (> m 2) -3 9))) 2) 5) (1- d)))
         (doe (+ (* yoe 365) (/ yoe 4) (- (/ yoe 100)) doy)))
    (+ (* era 146097) doe -719468)))

(defun org-queue-core-days-between (from to)
  "Return the number of days from FROM to TO, both YYYYMMDD integers."
  (- (org-queue-core-day-number to) (org-queue-core-day-number from)))

(defun org-queue-core-date-from-day-number (days)
  "Return the YYYYMMDD integer DAYS after 1970-01-01.
The inverse of `org-queue-core-day-number', same civil algorithm."
  (let* ((z (+ days 719468))
         (era (/ (if (>= z 0) z (- z 146096)) 146097))
         (doe (- z (* era 146097)))
         (yoe (/ (- doe (/ doe 1460) (- (/ doe 36524)) (/ doe 146096)) 365))
         (y (+ yoe (* era 400)))
         (doy (- doe (- (+ (* 365 yoe) (/ yoe 4)) (/ yoe 100))))
         (mp (/ (+ (* 5 doy) 2) 153))
         (d (1+ (- doy (/ (+ (* 153 mp) 2) 5))))
         (m (if (< mp 10) (+ mp 3) (- mp 9)))
         (y (if (<= m 2) (1+ y) y)))
    (+ (* y 10000) (* m 100) d)))

(defun org-queue-core-iso (date)
  "Return DATE, a YYYYMMDD integer, as YYYY-MM-DD."
  (format "%d-%02d-%02d" (/ date 10000) (% (/ date 100) 100) (% date 100)))

(defun org-queue-core-date-add (date days)
  "Return DATE, a YYYYMMDD integer, moved by DAYS."
  (org-queue-core-date-from-day-number
   (+ (org-queue-core-day-number date) days)))

(defun org-queue-core-day-of-week (date)
  "Return the day of week of DATE (YYYYMMDD), 0 = Sunday.
1970-01-01 was a Thursday, hence the offset."
  (mod (+ 4 (org-queue-core-day-number date)) 7))

(defun org-queue-core-today ()
  "Return today as a YYYYMMDD integer."
  (let ((now (decode-time)))
    (+ (* 10000 (nth 5 now)) (* 100 (nth 4 now)) (nth 3 now))))

(defun org-queue-core-capacity (date)
  "Return the planning capacity in minutes for DATE (YYYYMMDD)."
  (or (alist-get (org-queue-core-day-of-week date) org-queue-capacity)
      0))


;;;; Task accessors

(defun org-queue-core-effort (task)
  "Return TASK's effort in minutes, falling back to the default."
  (or (plist-get task :effort) org-queue-default-effort))

(defun org-queue-core-guessed-p (task)
  "Return non-nil if TASK carries no estimate of its own."
  (null (plist-get task :effort)))

(defun org-queue-core-done-p (task)
  "Return non-nil if TASK is in a done state."
  (member (plist-get task :state) org-queue-done-states))

(defun org-queue-core--annotate (task &rest properties)
  "Return a copy of TASK with PROPERTIES prepended.
The copy is shallow and the original is never modified: a task can appear
in a plan and in the caller's own list without the two aliasing."
  (append properties (copy-sequence task)))


;;;; Filtering

(defun org-queue-core-filter (tasks today)
  "Sort TASKS into what can be planned on TODAY and what cannot.

Return a plist of `:eligible', `:deferred' and `:dropped'.  `:deferred'
holds tasks scheduled after TODAY -- not rejected, just not due, and
pulled back in if the day underfills.  `:dropped' is an alist of
\(TASK . REASON), REASON being one of `done', `state', `blocked',
`waiting', `context', `energy', `event-later' or `event-past'."
  (let* ((ids (delq nil (mapcar (lambda (task) (plist-get task :id)) tasks)))
         (open-ids (delq nil (mapcar (lambda (task)
                                       (unless (org-queue-core-done-p task)
                                         (plist-get task :id)))
                                     tasks)))
         eligible deferred dropped)
    (dolist (task tasks)
      (let* ((state (plist-get task :state))
             (scheduled (plist-get task :scheduled))
             (deadline (plist-get task :deadline))
             ;; A blocker that is nowhere in TASKS cannot be checked, and
             ;; hiding work behind a dangling reference is worse than
             ;; showing it: unknown means unblocked.
             (blockers (cl-remove-if-not (lambda (id) (member id ids))
                                         (plist-get task :blocked-by)))
             (reason
              (cond
               ((org-queue-core-done-p task) 'done)
               ((org-queue-core-habit-p task) 'habit)
               ((member state org-queue-excluded-states) 'state)
               ;; A child of a project the check found dormant is not a
               ;; next step anyone chose; the project needs one first.
               ((plist-get task :dormant-parent) 'dormant-project)
               ;; An agent has the ball: no human minutes until it lands.
               ((member state org-queue-agent-states) 'in-flight)
               ((cl-some (lambda (id) (member id open-ids)) blockers) 'blocked)
               ((and (equal state "WAIT")
                     (not (and deadline
                               (<= (org-queue-core-days-between today deadline)
                                   org-queue-wait-horizon-days))))
                'waiting)
               ;; Context and energy are the only drops that describe YOU
               ;; rather than the task, which is why they sit after the
               ;; task-shaped reasons: a done or blocked task should report
               ;; that, not "wrong context".
               ((not (org-queue-core-available-p
                      task org-queue-contexts org-queue-context-tags))
                'context)
               ((not (org-queue-core-available-p
                      task org-queue-energy org-queue-energy-tags))
                'energy)
               ;; An appointment is fixed in time.  It cannot be pulled
               ;; forward to fill a quiet day the way scheduled work can,
               ;; and one that has already happened is not today's work
               ;; however long it sits there unmarked.
               ((and (not (org-queue-core-committed-p task today))
                     (plist-get task :timestamp)
                     (> (plist-get task :timestamp) today))
                'event-later)
               ((and (not (org-queue-core-committed-p task today))
                     (or (and (plist-get task :timestamp)
                              (< (plist-get task :timestamp) today))
                         (and (null (plist-get task :timestamp))
                              (plist-get task :timestamp-past))))
                'event-past))))
        (cond
         (reason (push (cons task reason) dropped))
         ((and scheduled (> scheduled today)) (push task deferred))
         (t (push task eligible)))))
    (list :eligible (nreverse eligible)
          :deferred (nreverse deferred)
          :dropped (nreverse dropped))))

(defun org-queue-core-committed-p (task today)
  "Return non-nil if TASK is a commitment for TODAY rather than a candidate.

Scheduled ON today, due today or earlier, carrying a plain active
timestamp that falls on today -- or marked NEXT.

NEXT is the one commitment that comes from a person rather than a date.
It is deliberately a commitment and not a large score bonus: a bonus can
always be out-argued by a near deadline, which makes it advice rather
than an override, and an override that loses is not one.  The cost is
symmetrical and correct -- mark six things NEXT and the day is
overcommitted, which the plan will say in as many words.

Note the asymmetry: a deadline in the past is still a commitment -- the
obligation did not expire -- but a SCHEDULE in the past is not.  A stale
schedule is a plan you already broke, and treating it as a fact means
the commitments alone overflow every day forever and the scorer never
gets to run.  It is not ignored: `org-queue-core-carried-p' hands it to
the carry-over term, so yesterday's undone plan outranks fresh work
without outranking today's actual obligations."
  (let ((scheduled (plist-get task :scheduled))
        (deadline (plist-get task :deadline))
        (timestamp (plist-get task :timestamp))
        (start-by (plist-get task :start-by)))
    (or (equal (plist-get task :state) "NEXT")
        (and scheduled (= scheduled today)
             ;; A machine placement is only a fact once the planner is
             ;; not the one asking; while proposing it may be moved.
             (not (and org-queue-core-placed-soft (plist-get task :placed))))
        (and deadline (<= deadline today))
        (and timestamp (= timestamp today))
        (and start-by (<= start-by today)))))

(defun org-queue-core-carried-p (task today)
  "Return non-nil if TASK was planned for an earlier day and not finished.

Either the planner put it on a previous day's plan (`:carried') or you
did, by scheduling it for a day that has been and gone."
  (or (plist-get task :carried)
      (let ((scheduled (plist-get task :scheduled)))
        (and scheduled (< scheduled today)))))


;;;; Scoring

(defun org-queue-core-urgency (task today)
  "Return TASK's deadline urgency on TODAY, between 0 and 1.

Convex, not linear: flat while the deadline is far off and steep in the
last few days, with anything overdue pinned to the maximum.  A task with
no deadline scores zero here and lives or dies on the other terms."
  (let ((deadline (plist-get task :deadline)))
    (if (not deadline)
        0.0
      (let* ((days (org-queue-core-days-between today deadline))
             (raw (if (<= days 0) 1.0 (/ 1.0 (+ 1.0 days)))))
        (if (plist-get task :deadline-soft)
            (* raw org-queue-soft-deadline-factor)
          raw)))))

(defun org-queue-core-impact-weight (task)
  "Return TASK's impact contribution, between -1.0 and 1.0.

Centred on `org-queue-impact-neutral' and scaled by the distance to the
ends of the 1-5 scale, so the term is symmetric and an unset IMPACT is
exactly zero rather than a quiet nudge in either direction."
  (let ((impact (or (plist-get task :impact) org-queue-impact-neutral)))
    (/ (float (- impact org-queue-impact-neutral))
       (float (max 1 (- 5 org-queue-impact-neutral))))))

(defun org-queue-core-priority-weight (task)
  "Return the weight of TASK's priority cookie."
  (let ((cell (assoc (plist-get task :priority) org-queue-priority-weights)))
    (if cell (cdr cell) (alist-get nil org-queue-priority-weights 0.45))))

(defun org-queue-core-score (task today)
  "Return TASK's static score on TODAY.

Static meaning everything but the category glut penalty, which depends
on what has already been picked and so belongs to the packer."
  (let ((w (lambda (key) (or (alist-get key org-queue-weights) 0.0)))
        (age (if (plist-get task :created)
                 (max 0 (org-queue-core-days-between
                         (plist-get task :created) today))
               0)))
    (+ (* (funcall w 'deadline) (org-queue-core-urgency task today))
       (* (funcall w 'priority) (org-queue-core-priority-weight task))
       (* (funcall w 'impact) (org-queue-core-impact-weight task))
       (* (funcall w 'age) (log (+ 1.0 age)))
       (if (equal (plist-get task :state) "PROG") (funcall w 'progress) 0.0)
       (if (<= (org-queue-core-effort task) org-queue-quick-threshold)
           (funcall w 'quick) 0.0)
       (if (org-queue-core-carried-p task today) (funcall w 'carry) 0.0)
       (if (and org-queue-core-placed-soft (plist-get task :placed)
                (eql (plist-get task :scheduled) today))
           (funcall w 'stick) 0.0)
       (if (plist-get task :mission) (funcall w 'mission) 0.0)
       (or (alist-get (plist-get task :state) org-queue-state-weights
                      0.0 nil #'equal)
           0.0))))


;;;; Calibration

(defun org-queue-core--ratio (tasks)
  "Return (N . RATIO) of clocked to estimated minutes over TASKS.
Totals rather than a mean of ratios, so a five-hour task counts for more
than a ten-minute one."
  (let ((n 0) (estimated 0) (clocked 0))
    (dolist (task tasks)
      (let ((effort (plist-get task :effort))
            (actual (plist-get task :clocked)))
        (when (and (org-queue-core-done-p task)
                   effort (> effort 0)
                   actual (> actual 0))
          (setq n (1+ n)
                estimated (+ estimated effort)
                clocked (+ clocked actual)))))
    (cons n (if (> estimated 0) (/ (float clocked) estimated) 1.0))))

(defun org-queue-core--shrink (n raw toward)
  "Pull RAW, measured over N tasks, TOWARD a prior, then clamp it."
  (let* ((prior org-queue-calibration-prior)
         (value (/ (+ (* n raw) (* prior toward)) (float (+ n prior)))))
    (min (cdr org-queue-calibration-limits)
         (max (car org-queue-calibration-limits) value))))

(defun org-queue-core-calibration (tasks)
  "Return an alist of (CATEGORY . FACTOR) learned from finished TASKS.

The entry keyed by t is the whole-corpus factor and the fallback for a
category with no history.  Each category is shrunk toward that global
factor rather than toward 1.0: if everything you do runs long, a new
category probably does too."
  (let* ((global (org-queue-core--ratio tasks))
         (global-factor (org-queue-core--shrink (car global) (cdr global) 1.0))
         (categories (delete-dups
                      (delq nil (mapcar (lambda (task) (plist-get task :category))
                                        tasks))))
         (factors (list (cons t global-factor))))
    (dolist (category categories)
      (let* ((subset (cl-remove-if-not
                      (lambda (task) (equal (plist-get task :category) category))
                      tasks))
             (ratio (org-queue-core--ratio subset)))
        (when (> (car ratio) 0)
          (push (cons category
                      (org-queue-core--shrink (car ratio) (cdr ratio)
                                              global-factor))
                factors))))
    (nreverse factors)))

(defun org-queue-core-calibration-report (tasks)
  "Return per-category calibration evidence over TASKS, for display.
Each element is a plist of `:category', `:n', `:raw' and `:factor'."
  (let ((factors (org-queue-core-calibration tasks))
        report)
    (dolist (cell factors)
      (let* ((category (car cell))
             (subset (if (eq category t)
                         tasks
                       (cl-remove-if-not
                        (lambda (task) (equal (plist-get task :category) category))
                        tasks)))
             (ratio (org-queue-core--ratio subset)))
        (push (list :category category :n (car ratio)
                    :raw (cdr ratio) :factor (cdr cell))
              report)))
    (nreverse report)))

(defun org-queue-core-factor (factors category)
  "Return the calibration factor for CATEGORY from FACTORS."
  (if (not org-queue-calibrate)
      1.0
    (or (cdr (assoc category factors))
        (alist-get t factors 1.0))))

(defcustom org-queue-review-share 0.5
  "Share of a landed entry's effort that is your minutes: the review.
An agent task's effort means your minutes per cycle, spec plus review;
when it lands, what is left is the review (Part 6 question 12 of
composite.org starts this at one half)."
  :type 'float
  :group 'org-queue)

(defun org-queue-core-minutes (task factors)
  "Return the minutes TASK should be planned against, calibrated.
A landed entry -- NEXT straight from AGENT -- is planned at
`org-queue-review-share' of its effort."
  (max 1 (round (* (org-queue-core-effort task)
                   (if (plist-get task :landed) org-queue-review-share 1.0)
                   (org-queue-core-factor factors (plist-get task :category))))))


;;;; Packing

(defun org-queue-core--sort-committed (tasks today)
  "Order committed TASKS for TODAY: soonest due, then priority, then shortest."
  (sort (copy-sequence tasks)
        (lambda (a b)
          (let ((ua (org-queue-core-urgency a today))
                (ub (org-queue-core-urgency b today)))
            (cond
             ((/= ua ub) (> ua ub))
             ((/= (org-queue-core-priority-weight a)
                  (org-queue-core-priority-weight b))
              (> (org-queue-core-priority-weight a)
                 (org-queue-core-priority-weight b)))
             (t (< (org-queue-core-effort a) (org-queue-core-effort b))))))))

(defun org-queue-core--fill (candidates state today factors reason)
  "Pick from CANDIDATES into STATE until nothing more fits.

STATE is a mutable plist-in-a-cons of the packing so far; REASON is the
`:queue-reason' stamped on everything chosen here.  Returns the tasks
left over.  The glut penalty is applied inside the loop rather than
folded into the score beforehand, because it changes every time a task
is picked -- that is the whole point of it."
  (let ((remaining (copy-sequence candidates))
        (picking t))
    (while (and picking remaining)
      (let (best best-score)
        (dolist (task remaining)
          (let ((minutes (org-queue-core-minutes task factors))
                (picks (or (cdr (assoc (plist-get task :category)
                                       (plist-get (car state) :picks)))
                           0)))
            (when (and (<= minutes (org-queue-core--room state task))
                       (or (not (equal (plist-get task :state) "PROG"))
                           (< (plist-get (car state) :wip) org-queue-wip-limit)))
              (let ((score (- (org-queue-core-score task today)
                              (* (or (alist-get 'glut org-queue-weights) 0.0)
                                 picks))))
                (when (or (null best) (> score best-score))
                  (setq best task best-score score))))))
        (if (not best)
            (setq picking nil)
          (setq remaining (delq best remaining))
          (org-queue-core--admit state best today factors reason best-score))))
    remaining))

(defun org-queue-core--bucket-state (state task)
  "Return the mutable plist of TASK's bucket in STATE, or nil if closed."
  (alist-get (org-queue-core-bucket task) (plist-get (car state) :buckets)))

(defun org-queue-core--room (state task)
  "Return the minutes TASK's bucket still has in STATE."
  (let ((bucket (org-queue-core--bucket-state state task)))
    (if bucket
        (- (plist-get bucket :usable) (plist-get bucket :minutes))
      0)))

(defun org-queue-core--admit (state task today factors reason
                                    &optional score minutes)
  "Add TASK to the plan held in STATE, stamped with REASON and SCORE.
MINUTES overrides the calibrated effort, for a slice."
  (let* ((plan (car state))
         (whole (org-queue-core-minutes task factors))
         (minutes (or minutes whole))
         (category (plist-get task :category))
         (bucket (org-queue-core--bucket-state state task))
         (picks (plist-get plan :picks)))
    (setf (alist-get category picks nil nil #'equal)
          (1+ (or (alist-get category picks 0 nil #'equal) 0)))
    (setq plan (plist-put plan :picks picks))
    (setq plan (plist-put plan :minutes (+ (plist-get plan :minutes) minutes)))
    (when bucket
      (plist-put bucket :minutes (+ (plist-get bucket :minutes) minutes)))
    (when (equal (plist-get task :state) "PROG")
      (setq plan (plist-put plan :wip (1+ (plist-get plan :wip)))))
    (setq plan
          (plist-put plan :planned
                     (cons (org-queue-core--annotate
                            task
                            :queue-reason reason
                            :queue-minutes minutes
                            :queue-bucket (org-queue-core-bucket task)
                            :queue-guessed (org-queue-core-guessed-p task)
                            :slice (and (< minutes whole) t)
                            :queue-score (or score
                                             (org-queue-core-score task today)))
                           (plist-get plan :planned))))
    (setcar state plan)))

(defun org-queue-core--cut-reason (task state factors)
  "Say why TASK did not make the plan in STATE."
  (let ((bucket (org-queue-core--bucket-state state task)))
    (cond
     ((and (equal (plist-get task :state) "PROG")
           (>= (plist-get (car state) :wip) org-queue-wip-limit))
      'wip-limit)
     ((or (null bucket) (zerop (plist-get bucket :capacity)))
      'bucket-closed)
     ((> (org-queue-core-minutes task factors)
         (org-queue-core--room state task))
      'no-room)
     (t 'no-room))))

(defun org-queue-core--bucket-states (today capacity habits)
  "Build the per-bucket packing state for TODAY.

CAPACITY, when given, overrides the default bucket's minutes -- the
older calling convention, kept for the tests and for callers with one
pool.  HABITS are subtracted from their buckets before slack is taken:
routine is fixed time, and slack is for the work that is not."
  (mapcar
   (lambda (cell)
     (let* ((name (car cell))
            (minutes (if (and capacity (eq name 'default) (null org-queue-buckets))
                         capacity
                       (org-queue-core-bucket-capacity name today)))
            (routine (cl-reduce
                      #'+ (mapcar #'org-queue-core-effort
                                  (cl-remove-if-not
                                   (lambda (habit) (eq (org-queue-core-bucket habit) name))
                                   habits))
                      :initial-value 0))
            (usable (max 0 (round (* (- minutes routine)
                                     (- 1.0 org-queue-slack-fraction))))))
       (cons name (list :capacity minutes :routine routine
                        :usable usable :minutes 0
                        :spill (plist-get (cdr cell) :spill)))))
   (org-queue-core-bucket-specs)))


;;;; The plan

(defun org-queue-core-plan (tasks &optional today capacity)
  "Plan a day of TASKS for TODAY against CAPACITY minutes.

TODAY defaults to the current date and CAPACITY to the bucket table's
minutes for that day (`org-queue-buckets', or `org-queue-capacity' when
there is none).  Returns a plist:

  :date         the day planned, YYYYMMDD
  :capacity     minutes in the day, all buckets
  :routine      the habits that fall on the day, annotated
  :usable       minutes for tasks after routine and slack, all buckets
  :minutes      minutes planned
  :buckets      one plist per bucket: :name :capacity :routine :usable
                :minutes :overcommitted
  :planned      the day, committed first, each task annotated with
                `:queue-reason', `:queue-minutes', `:queue-bucket',
                `:queue-score', `:queue-guessed' and `:slice'
  :overcommitted non-nil when commitments alone exceed some bucket
  :cut          (TASK . REASON) for eligible tasks that did not fit
  :dropped      (TASK . REASON) for tasks that never competed
  :deferred     tasks scheduled later and not needed to fill the day
  :calibration  the (CATEGORY . FACTOR) alist used

Every task handed in comes back in exactly one of :planned, :cut,
:dropped or :deferred."
  (let* ((today (or today (org-queue-core-today)))
         (factors (org-queue-core-calibration tasks))
         (sorted (org-queue-core-filter tasks today))
         (habits (cl-remove-if-not
                  (lambda (task) (org-queue-core-habit-applies-p task today))
                  (mapcar #'car
                          (cl-remove-if-not (lambda (cell) (eq (cdr cell) 'habit))
                                            (plist-get sorted :dropped)))))
         (buckets (org-queue-core--bucket-states today capacity habits))
         (sum (lambda (key)
                (cl-reduce #'+ (mapcar (lambda (b) (plist-get (cdr b) key)) buckets)
                           :initial-value 0)))
         (usable (funcall sum :usable))
         ;; Start-by is a property of the task on this day, so stamp it
         ;; before the commitment check reads it.
         (eligible (mapcar (lambda (task)
                             (let ((start-by (org-queue-core-start-by
                                              task today
                                              (org-queue-core-minutes task factors))))
                               (if start-by
                                   (org-queue-core--annotate task :start-by start-by)
                                 task)))
                           (plist-get sorted :eligible)))
         (committed (org-queue-core--sort-committed
                     (cl-remove-if-not
                      (lambda (task) (org-queue-core-committed-p task today))
                      eligible)
                     today))
         (candidates (cl-remove-if
                      (lambda (task) (org-queue-core-committed-p task today))
                      eligible))
         (state (list (list :minutes 0 :usable usable :wip 0
                            :picks nil :planned nil :buckets buckets)))
         cut)
    ;; Commitments are facts, not candidates: they are never scored and
    ;; never dropped for want of room.  If they alone overflow a bucket,
    ;; that is the finding -- say it and plan nothing else in it.  The
    ;; horizon simulator is the one exception: there a commitment that
    ;; is not yet due may be sliced to what fits, or carried a day.
    (dolist (task committed)
      (let* ((minutes (org-queue-core-minutes task factors))
             (room (org-queue-core--room state task)))
        (cond
         ((or (not org-queue-core-slice-commitments)
              (<= minutes room)
              ;; An appointment has a time of day; it cannot be sliced or
              ;; carried, so it is admitted whole even in the simulation.
              (eql (plist-get task :timestamp) today))
          (org-queue-core--admit state task today factors 'committed))
         ((>= room org-queue-min-slice)
          (org-queue-core--admit state task today factors 'committed nil room))
         (t (push (cons task 'no-room) cut)))))
    (let* ((overcommitted-buckets
            (cl-remove-if-not
             (lambda (b) (> (plist-get (cdr b) :minutes) (plist-get (cdr b) :usable)))
             buckets))
           (overcommitted (and overcommitted-buckets t))
           (open (cl-remove-if
                  (lambda (task)
                    (assq (org-queue-core-bucket task) overcommitted-buckets))
                  candidates))
           (blocked (cl-remove-if-not
                     (lambda (task)
                       (assq (org-queue-core-bucket task) overcommitted-buckets))
                     candidates)))
      (dolist (task blocked) (push (cons task 'overcommitted) cut))
      (let ((leftover (org-queue-core--fill open state today factors 'scored)))
        ;; Spill: a bucket that allows it hands what it did not use to
        ;; the default bucket, and the default's candidates get one more
        ;; pass.
        (let ((spilled 0))
          (dolist (b buckets)
            (when (and (plist-get (cdr b) :spill) (not (eq (car b) 'default)))
              (setq spilled (+ spilled (max 0 (- (plist-get (cdr b) :usable)
                                                 (plist-get (cdr b) :minutes)))))))
          (when-let* ((default (and (> spilled 0) (alist-get 'default buckets))))
            (plist-put default :usable (+ (plist-get default :usable) spilled))
            (setcar state (plist-put (car state) :usable
                                     (+ (plist-get (car state) :usable) spilled)))
            (setq leftover (org-queue-core--fill leftover state today factors 'scored))))
        (dolist (task leftover)
          (push (cons task (org-queue-core--cut-reason task state factors)) cut)))
      ;; A day that still has room after the backlog is exhausted may
      ;; reach forward: scheduled-later work is deferred, not refused.
      (let ((deferred (plist-get sorted :deferred)))
        (setq deferred (org-queue-core--fill
                        (cl-remove-if
                         (lambda (task)
                           (assq (org-queue-core-bucket task) overcommitted-buckets))
                         deferred)
                        state today factors 'pulled-forward))
        ;; Tasks in an overcommitted bucket were never offered; put them back.
        (setq deferred (append deferred
                               (cl-remove-if-not
                                (lambda (task)
                                  (assq (org-queue-core-bucket task) overcommitted-buckets))
                                (plist-get sorted :deferred))))
        (list :date today
              :capacity (funcall sum :capacity)
              :routine (mapcar (lambda (habit)
                                 (org-queue-core--annotate
                                  habit
                                  :queue-minutes (org-queue-core-effort habit)
                                  :queue-bucket (org-queue-core-bucket habit)
                                  :queue-guessed (org-queue-core-guessed-p habit)))
                               habits)
              :usable (plist-get (car state) :usable)
              :minutes (plist-get (car state) :minutes)
              :buckets (mapcar (lambda (b)
                                 (list :name (car b)
                                       :capacity (plist-get (cdr b) :capacity)
                                       :routine (plist-get (cdr b) :routine)
                                       :usable (plist-get (cdr b) :usable)
                                       :minutes (plist-get (cdr b) :minutes)
                                       :overcommitted
                                       (> (plist-get (cdr b) :minutes)
                                          (plist-get (cdr b) :usable))))
                               buckets)
              :planned (nreverse (plist-get (car state) :planned))
              :overcommitted overcommitted
              :wip (plist-get (car state) :wip)
              :cut (nreverse cut)
              :dropped (plist-get sorted :dropped)
              :deferred deferred
              :calibration factors)))))

(defun org-queue-core-summary (plan)
  "Return a one-line summary string for PLAN."
  (let ((minutes (plist-get plan :minutes))
        (usable (plist-get plan :usable)))
    (format "%d task%s, %s of %s%s"
            (length (plist-get plan :planned))
            (if (= 1 (length (plist-get plan :planned))) "" "s")
            (org-queue-core-format-minutes minutes)
            (org-queue-core-format-minutes usable)
            (if (plist-get plan :overcommitted) " -- OVERCOMMITTED" ""))))

(defun org-queue-core-format-minutes (minutes)
  "Format MINUTES as H:MM."
  (format "%d:%02d" (/ minutes 60) (% minutes 60)))

(provide 'org-queue-core)
;;; org-queue-core.el ends here
