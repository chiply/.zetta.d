;;; org-gantt-core.el --- Bars, clipping and axes for a Gantt over state transitions -*- lexical-binding: t; -*-

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

;; The chart's arithmetic, with no Org and no SVG in it.
;;
;; Everything here takes plists and returns plists, so the geometry can be
;; argued with in `emacs -Q --batch' against hand-built fixtures -- no
;; agenda, no files, no window.  `org-gantt-harvest' turns real Org entries
;; into these plists; `org-gantt-svg' draws the result; neither is known to
;; this file.
;;
;; A row plist, as handed in:
;;
;;   (:id "abc" :title "Draft the roadmap" :category "work" :state "PROG"
;;    :effort 360 :created S :closed nil :deadline S :scheduled S
;;    :intervals ((:state "PROG" :start S :end E :open t) ...)
;;    :plans ((:kind queue :day D :minutes 120)
;;            (:kind schedule :start S :end E)))
;;
;; Times are INTEGER EPOCH SECONDS throughout -- they order under `<',
;; subtract without a library, and print as a number a failing test can be
;; read against.  Durations are minutes.  Absent is nil and means absent:
;; `:effort' nil is unestimated, NOT zero, and a row with no `:intervals'
;; is one that was never worked, which is a finding rather than a gap.
;;
;; THE CLIP.  An interval is wall time: a task moved to PROG on Tuesday
;; afternoon and to DONE on Wednesday morning spans eighteen hours,
;; because nothing marked the evening.  That is the right answer for a
;; Gantt (the task really was open that long) and the wrong one for "how
;; long did it take".  So both numbers are kept and neither is a
;; correction of the other: `:elapsed' is raw wall time and `:worked' is
;; the working-state time after clipping to `org-gantt-window'.  The week
;; grid draws the clipped segments, because a night painted solid is a
;; lie about a day; the Gantt draws the raw ones, because the point of a
;; Gantt is how long a thing was open.  When G6's routine table exists it
;; replaces `org-gantt-window' and nothing else changes.
;;
;; The entry point is `org-gantt-core-chart'.

;;; Code:

(require 'cl-lib)
(require 'calendar)

(defgroup org-gantt nil
  "A Gantt chart and a week grid over Org state transitions."
  :group 'org
  :prefix "org-gantt-")


;;;; What a state means

;; The `from' field of a state-change line is not consulted anywhere here
;; -- like `org-queue-state-log', which reads the drawer, this treats the
;; state that OPENS an interval as the state of that interval.  That is
;; what lets the older STARTED/CANCELLED vocabulary in the real kb measure
;; as well as today's PROG does.

(defcustom org-gantt-working-states '("PROG" "STARTED")
  "States whose duration counts as time spent.

Kept separate from `org-queue-working-states' rather than derived from
it: this file must load in batch with no Org and no org-queue.  The
module keeps the two in step."
  :type '(repeat string)
  :group 'org-gantt)

(defcustom org-gantt-waiting-states '("WAIT" "QUES" "HOLD")
  "States that count as blocked rather than idle.

Drawn on their own rung, because \"three days waiting on legal\" and
\"three days I never looked at it\" are different findings and a chart
that renders them alike hides the more actionable one."
  :type '(repeat string)
  :group 'org-gantt)

(defcustom org-gantt-done-states '("DONE" "NOPE" "CANCELLED" "OBSOLETE")
  "States that close a row's bar.

CANCELLED and OBSOLETE are this kb's older names and are listed so
historical entries end where they really ended."
  :type '(repeat string)
  :group 'org-gantt)

(defun org-gantt-core-class (state)
  "Return the bar class of STATE: `working', `waiting', `done' or `idle'."
  (cond ((null state) 'idle)
        ((member state org-gantt-working-states) 'working)
        ((member state org-gantt-waiting-states) 'waiting)
        ((member state org-gantt-done-states) 'done)
        (t 'idle)))


;;;; Time

(defun org-gantt-core-day-start (time)
  "Return midnight opening the local day containing TIME, in epoch seconds."
  (let ((decoded (decode-time time)))
    (floor (float-time
            (encode-time (list 0 0 0
                               (nth 3 decoded) (nth 4 decoded) (nth 5 decoded)
                               nil -1 nil))))))

(defun org-gantt-core-day-after (time)
  "Return midnight opening the day after the one containing TIME.
Re-derived through `decode-time' rather than by adding 86400, so the
two days a year that are not 24 hours long land on midnight anyway."
  (org-gantt-core-day-start (+ (org-gantt-core-day-start time) 90000)))

(defun org-gantt-core-dow (time)
  "Return the day of week of TIME, 0 for Sunday."
  (nth 6 (decode-time time)))

(defun org-gantt-core-minutes (from to)
  "Return whole minutes between epoch seconds FROM and TO, never negative."
  (max 0 (floor (- to from) 60)))

(defun org-gantt-core-format-minutes (minutes)
  "Return MINUTES as H:MM, or \"-\" when it is nil."
  (if (null minutes)
      "-"
    (format "%d:%02d" (/ minutes 60) (% minutes 60))))

(defun org-gantt-core-format-span (minutes)
  "Return MINUTES as a coarse span: minutes, hours, then days."
  (cond ((null minutes) "-")
        ((< minutes 60) (format "%dm" minutes))
        ((< minutes (* 60 24)) (format "%.1fh" (/ minutes 60.0)))
        (t (format "%.1fd" (/ minutes (* 60.0 24))))))


(defun org-gantt-core-day-minutes (seconds)
  "Return epoch SECONDS as minutes since the absolute Gregorian epoch.

The coordinate `org-timegrid' draws in: whole days from
`calendar-absolute-from-gregorian', times 1440, plus the minute of the
day.  Kept here rather than in the grid backend so the round trip has a
batch test."
  (let* ((decoded (decode-time seconds))
         (absolute (calendar-absolute-from-gregorian
                    (list (nth 4 decoded) (nth 3 decoded) (nth 5 decoded)))))
    (+ (* absolute 1440) (* 60 (nth 2 decoded)) (nth 1 decoded))))

(defun org-gantt-core-from-day-minutes (minutes)
  "Return absolute Gregorian MINUTES as epoch seconds.

The inverse of `org-gantt-core-day-minutes', through `encode-time' so
that a spring-forward hour is the system's opinion and not this file's."
  (let* ((absolute (floor minutes 1440))
         (rest (- minutes (* absolute 1440)))
         (gregorian (calendar-gregorian-from-absolute absolute)))
    (floor (float-time
            (encode-time (list 0 (% rest 60) (/ rest 60)
                               (nth 1 gregorian) (nth 0 gregorian) (nth 2 gregorian)
                               nil -1 nil))))))


;;;; The working window

(defcustom org-gantt-window
  '((0 . nil)
    (6 . nil)
    (t . ((480 . 720) (810 . 1080))))
  "Working windows per weekday, as minutes after local midnight.

Keys are days of the week, 0 for Sunday, with t as the fallback.  A nil
value is a day with no working window at all, so nothing clips into it.

A placeholder, and known to be one: it is the same 08:00-12:00 /
13:30-18:00 shape the routine assumes, and its only job is to keep a
task left in PROG overnight from painting the night solid.  The honest
version is the routine table (G6), which will supply exactly this
structure from a file you already maintain; when it does, set this from
it and every number here follows."
  :type '(alist :key-type (choice (integer :tag "Day of week (0 = Sunday)")
                                  (const :tag "Any other day" t))
                :value-type (choice (const :tag "No working window" nil)
                                    (repeat (cons (integer :tag "From (minutes)")
                                                  (integer :tag "To (minutes)")))))
  :group 'org-gantt)

(defun org-gantt-core-day-window (dow)
  "Return the window list for DOW, honouring the t fallback."
  (if (assoc dow org-gantt-window)
      (cdr (assoc dow org-gantt-window))
    (cdr (assq t org-gantt-window))))

(defun org-gantt-core-windows (from to)
  "Return working windows intersecting FROM..TO as (START . END) second pairs.

Ordered, non-overlapping, and generated day by day so daylight saving is
whatever `encode-time' says it is rather than whatever arithmetic on
86400 would have made it."
  (let ((day (org-gantt-core-day-start from))
        windows)
    (while (< day to)
      (dolist (window (org-gantt-core-day-window (org-gantt-core-dow day)))
        (let ((start (+ day (* 60 (car window))))
              (end (+ day (* 60 (cdr window)))))
          (when (and (< start to) (> end from))
            (push (cons start end) windows))))
      (setq day (org-gantt-core-day-after day)))
    (nreverse windows)))

(defun org-gantt-core-clip (segments windows)
  "Return the parts of SEGMENTS that fall inside WINDOWS.

A segment crossing a window edge is cut, not dropped, and a segment
spanning several windows becomes several segments -- which is why an
overnight PROG shows up as Tuesday's last hour and Wednesday's first
two, and never as the night between them.  Only the piece that still
reaches the segment's own end keeps `:open': the earlier pieces are
finished, whatever the entry is doing now."
  (let (clipped)
    (dolist (segment segments)
      (dolist (window windows)
        (let ((start (max (plist-get segment :start) (car window)))
              (end (min (plist-get segment :end) (cdr window))))
          (when (< start end)
            (push (list :state (plist-get segment :state)
                        :class (plist-get segment :class)
                        :start start :end end
                        :open (and (plist-get segment :open)
                                   (= end (plist-get segment :end))))
                  clipped)))))
    (sort (nreverse clipped)
          (lambda (a b) (< (plist-get a :start) (plist-get b :start))))))


;;;; Intervals to segments

(defun org-gantt-core-segments (row &optional now)
  "Return ROW's intervals as classified segments, oldest first.

NOW closes an interval still open.  Each segment is

  (:state S :class C :start SEC :end SEC :open BOOL)

and a `done' interval is dropped: a row's bar ends when the work does,
so the days after DONE are not drawn as anything at all."
  (let ((now (or now (floor (float-time)))))
    (delq nil
          (mapcar
           (lambda (interval)
             (let* ((state (plist-get interval :state))
                    (class (org-gantt-core-class state))
                    (start (plist-get interval :start))
                    (end (or (plist-get interval :end) now)))
               (unless (or (eq class 'done) (>= start end))
                 (list :state state :class class
                       :start start :end end
                       :open (and (plist-get interval :open) t)))))
           (plist-get row :intervals)))))


;;;; Attribution: who gets the minute when three things are in PROG

(defcustom org-gantt-overlap 'wall
  "How minutes are attributed when several rows are working at once.

- `wall'   each row is credited in full, the way Jira counts time in
           status.  The default, because it is what `org-queue' already
           does and changing it would silently move every calibration
           factor the queue has recorded.
- `share'  the minute is split equally between the rows holding it, so
           the total over a day can never exceed the day.
- `latest' only the most recently started row is credited, which reads a
           context switch as an interruption rather than as parallelism."
  :type '(choice (const :tag "Each in full (Jira)" wall)
                 (const :tag "Split equally" share)
                 (const :tag "Most recent only" latest))
  :group 'org-gantt)

(defun org-gantt-core--boundaries (spans)
  "Return the sorted distinct endpoints of SPANS, a list of (START END ...)."
  (let (points)
    (dolist (span spans)
      (push (nth 0 span) points)
      (push (nth 1 span) points))
    (sort (delete-dups points) #'<)))

(defun org-gantt-core-attribute (rows &optional policy)
  "Return an alist of (ROW-INDEX . MINUTES) worked, under POLICY.

ROWS is a list of `:clipped' segment lists in row order.  POLICY
defaults to `org-gantt-overlap'.  Only `working' segments are counted:
time spent waiting is elapsed, not worked, and adding it would make
every estimate calibrate as generous."
  (let* ((policy (or policy org-gantt-overlap))
         (spans (cl-loop for segments in rows
                         for index from 0
                         append (cl-loop for segment in segments
                                         when (eq (plist-get segment :class) 'working)
                                         collect (list (plist-get segment :start)
                                                       (plist-get segment :end)
                                                       index))))
         (points (org-gantt-core--boundaries spans))
         (totals (make-hash-table)))
    (cl-loop for (start end) on points
             while end
             do (let ((active (cl-remove-if-not
                               (lambda (span)
                                 (and (<= (nth 0 span) start) (>= (nth 1 span) end)))
                               spans))
                      (seconds (- end start)))
                  (when active
                    (pcase policy
                      ('wall
                       (dolist (span active)
                         (cl-incf (gethash (nth 2 span) totals 0) seconds)))
                      ('share
                       (let ((each (/ (float seconds) (length active))))
                         (dolist (span active)
                           (cl-incf (gethash (nth 2 span) totals 0) each))))
                      ('latest
                       (let ((winner (car (sort (copy-sequence active)
                                                (lambda (a b) (> (nth 0 a) (nth 0 b)))))))
                         (cl-incf (gethash (nth 2 winner) totals 0) seconds)))))))
    (cl-loop for index from 0 below (length rows)
             collect (cons index (floor (/ (gethash index totals 0) 60))))))


;;;; Row summaries

(defun org-gantt-core-summarize (rows &optional now)
  "Return ROWS with their measurements filled in.

Adds, to each row:

  :segments  raw classified segments, for the Gantt
  :clipped   the same, cut to `org-gantt-window', for the grid and the sums
  :worked    working minutes after clipping, under `org-gantt-overlap'
  :elapsed   wall minutes from first touch to last, or to NOW while open
  :sessions  how many separate times it was picked up
  :first     when it was first touched, :last when it was last left
  :open      still in a working state
  :stale     open, and opened before today -- a PROG someone forgot
  :ratio     worked over :effort, or nil when unestimated

`:elapsed' is deliberately raw.  A row that took an hour of work spread
over nine days reports 60 worked and 9 days elapsed, and the gap between
those two numbers is the most useful thing on the chart."
  (let* ((now (or now (floor (float-time))))
         (today (org-gantt-core-day-start now))
         (rows (mapcar (lambda (row)
                         (let* ((segments (org-gantt-core-segments row now))
                                (windows (when segments
                                           (org-gantt-core-windows
                                            (plist-get (car segments) :start)
                                            (apply #'max (mapcar (lambda (s) (plist-get s :end))
                                                                 segments))))))
                           (append (list :segments segments
                                         :clipped (org-gantt-core-clip segments windows))
                                   row)))
                       rows))
         (worked (org-gantt-core-attribute
                  (mapcar (lambda (row) (plist-get row :clipped)) rows))))
    (cl-loop for row in rows
             for index from 0
             collect
             (let* ((segments (plist-get row :segments))
                    (working (cl-remove-if-not
                              (lambda (s) (eq (plist-get s :class) 'working))
                              segments))
                    (first (when segments (plist-get (car segments) :start)))
                    (last (when segments
                            (apply #'max (mapcar (lambda (s) (plist-get s :end)) segments))))
                    (open (cl-find-if (lambda (s)
                                        (and (plist-get s :open)
                                             (eq (plist-get s :class) 'working)))
                                      segments))
                    (minutes (cdr (assq index worked)))
                    (effort (plist-get row :effort))
                    (stale (and open (< (plist-get open :start) today))))
               (append
                (list :worked minutes
                      ;; A row still in PROG since a previous day has been
                      ;; accruing every working hour since, because nothing
                      ;; marked the end.  That is the honest reading of time
                      ;; in status and a bad number to calibrate against, so
                      ;; it is kept and labelled rather than quietly capped.
                      :provisional (and stale (> minutes 0))
                      :elapsed (when first (org-gantt-core-minutes first last))
                      :sessions (length working)
                      :first first
                      :last last
                      :open (and open t)
                      :stale (and stale
                                  (org-gantt-core-day-start (plist-get open :start)))
                      ;; No ratio when nothing was worked.  "0.00" in a
                      ;; ratio column reads as a measurement; the truth is
                      ;; that there is nothing yet to compare the estimate
                      ;; against, and the empty cell says so.
                      :ratio (when (and effort (> effort 0) minutes (> minutes 0))
                               (/ (float minutes) effort)))
                row)))))


;;;; Plans

(defun org-gantt-core-subtract (spans busy)
  "Return SPANS with every part of BUSY removed.

Both are lists of (START . END) second pairs.  Used to keep the packer
out of the hours a fixed appointment already owns."
  (let ((result (copy-sequence spans)))
    (dolist (block (sort (copy-sequence busy) (lambda (a b) (< (car a) (car b)))))
      (setq result
            (cl-loop for span in result
                     append (cond
                             ((or (<= (cdr span) (car block))
                                  (>= (car span) (cdr block)))
                              (list span))
                             (t (delq nil
                                      (list (when (< (car span) (car block))
                                              (cons (car span) (car block)))
                                            (when (> (cdr span) (cdr block))
                                              (cons (cdr block) (cdr span))))))))))
    result))

(defun org-gantt-core--allocate (free minutes)
  "Take MINUTES out of FREE, a list of (START . END) spans.

Returns (SPAN . REMAINING-FREE), SPAN being (START END SHORT-P).  The
first span with room wins; if none has room the largest is taken and
flagged short, because a plan that does not fit is a fact about the day
worth drawing rather than an error worth hiding."
  (let* ((seconds (* 60 minutes))
         (fitting (cl-find-if (lambda (span) (>= (- (cdr span) (car span)) seconds))
                              free)))
    (if fitting
        (let ((end (+ (car fitting) seconds)))
          (cons (list (car fitting) end nil)
                (delq nil (mapcar (lambda (span)
                                    (cond ((not (eq span fitting)) span)
                                          ((< end (cdr span)) (cons end (cdr span)))))
                                  free))))
      (let ((largest (car (sort (copy-sequence free)
                                (lambda (a b) (> (- (cdr a) (car a))
                                                 (- (cdr b) (car b))))))))
        (when largest
          (cons (list (car largest) (cdr largest) t)
                (remq largest free)))))))

(defun org-gantt-core-place-plans (rows &optional windows)
  "Return ROWS with every day-and-duration plan given a start and an end.

A plan already carrying `:start' and `:end' is a fixed point -- a
meeting, or a SCHEDULED stamp that named an hour -- and is left exactly
where it is.  A plan carrying only `:day' and `:minutes' is a
commitment without a time: the queue packs a day by capacity, not by
clock, and a date-only SCHEDULED says nothing about when.  Those are
laid end to end through the day's working windows, in row order,
flowing around the fixed ones.

So the planned lane reads as the shape of the day rather than as a
claim about any particular hour, which is the most the recorded data
supports: `org-queue-record-plan' writes ids, not times.  WINDOWS
overrides `org-gantt-window' for every day, which is what the tests
use."
  (let ((free (make-hash-table :test #'equal))
        (busy (make-hash-table :test #'equal)))
    ;; Fixed plans first, so the flowing ones can avoid them.
    (dolist (row rows)
      (dolist (plan (plist-get row :plans))
        (when (and (plist-get plan :start) (plist-get plan :end))
          (let ((day (org-gantt-core-day-start (plist-get plan :start))))
            (push (cons (plist-get plan :start) (plist-get plan :end))
                  (gethash day busy))))))
    (mapcar
     (lambda (row)
       (append
        (list :plans
              (mapcar
               (lambda (plan)
                 (if (or (plist-get plan :start) (null (plist-get plan :day)))
                     plan
                   (let ((day (plist-get plan :day)))
                     ;; `gethash' with a sentinel, not a nil test: a day
                     ;; whose windows are all spent has an EMPTY free list,
                     ;; and treating that as "not yet computed" would hand
                     ;; the day back out to every later plan.
                     (when (eq 'unseen (gethash day free 'unseen))
                       (puthash day
                                (org-gantt-core-subtract
                                 (or windows
                                     (org-gantt-core-windows
                                      day (org-gantt-core-day-after day)))
                                 (gethash day busy))
                                free))
                     (let ((taken (org-gantt-core--allocate
                                   (gethash day free)
                                   (or (plist-get plan :minutes) 30))))
                       (if (null taken)
                           ;; No window left in the day.  Say so rather
                           ;; than inventing an hour: an unplaceable plan
                           ;; IS the overcommitment finding.
                           (append (list :unplaced t) plan)
                         (puthash day (cdr taken) free)
                         (list :kind (plist-get plan :kind)
                               :placed t
                               :start (nth 0 (car taken))
                               :end (nth 1 (car taken))
                               :short (nth 2 (car taken))))))))
               (plist-get row :plans)))
        row))
     rows)))


;;;; Layout

(defun org-gantt-core--x (time from to)
  "Return TIME as a fraction of the span FROM..TO, clamped to 0.0-1.0."
  (max 0.0 (min 1.0 (/ (float (- time from)) (max 1 (- to from))))))

(defun org-gantt-core-layout (rows from to)
  "Return ROWS with drawing coordinates for the span FROM..TO.

Adds `:bars' and `:marks', both in fractions of the span, so the
renderer multiplies by a pixel width and knows nothing about time.

Two rails per row.  The plan rail carries what was committed; the
actual rail carries what happened, segmented by the state held.  A row
whose plan rail is empty was never planned, and a row whose actual rail
is empty was never touched -- in both cases the absence is drawn as
absence rather than filled in."
  (mapcar
   (lambda (row)
     (let* ((bars
             (append
              ;; The plan rail.
              (delq nil
                    (mapcar
                     (lambda (plan)
                       (when (and (plist-get plan :start) (plist-get plan :end)
                                  (< (plist-get plan :start) to)
                                  (> (plist-get plan :end) from))
                         (list :rail 'plan
                               :class (plist-get plan :kind)
                               :short (plist-get plan :short)
                               :x0 (org-gantt-core--x (plist-get plan :start) from to)
                               :x1 (org-gantt-core--x (plist-get plan :end) from to))))
                     (plist-get row :plans)))
              ;; The actual rail: the whole open span, then the states on it.
              (when-let* ((first (plist-get row :first))
                          (last (plist-get row :last)))
                (when (and (< first to) (> last from))
                  (list (list :rail 'actual :class 'span
                              :x0 (org-gantt-core--x first from to)
                              :x1 (org-gantt-core--x last from to)
                              :continues-left (< first from)
                              :continues-right (> last to)))))
              (delq nil
                    (mapcar
                     (lambda (segment)
                       (when (and (< (plist-get segment :start) to)
                                  (> (plist-get segment :end) from))
                         (list :rail 'actual
                               :class (plist-get segment :class)
                               :state (plist-get segment :state)
                               :open (plist-get segment :open)
                               :x0 (org-gantt-core--x (plist-get segment :start) from to)
                               :x1 (org-gantt-core--x (plist-get segment :end) from to))))
                     (plist-get row :segments)))))
            (marks
             (delq nil
                   (list
                    (when-let* ((deadline (plist-get row :deadline)))
                      (when (and (>= deadline from) (<= deadline to))
                        (list :kind 'deadline :x (org-gantt-core--x deadline from to))))
                    (when-let* ((closed (plist-get row :closed)))
                      (when (and (>= closed from) (<= closed to))
                        (list :kind 'closed :x (org-gantt-core--x closed from to))))
                    (when (plist-get row :open)
                      (when-let* ((last (plist-get row :last)))
                        (when (<= last to)
                          (list :kind 'open :x (org-gantt-core--x last from to)))))))))
       (append (list :bars bars :marks marks) row)))
   rows))


;;;; The axis

(defconst org-gantt-core--day (* 60 60 24))

(defun org-gantt-core-ticks (from to)
  "Return axis ticks across FROM..TO, coarsening as the span grows.

Each tick is (:x F :label S :major BOOL).  Majors carry a rule down the
chart; minors only a mark on the axis.  The thresholds are the points
at which a label stops fitting rather than round numbers: a fortnight
of day labels is legible, a quarter of them is a smear."
  (let* ((span (- to from))
         (unit (cond ((<= span (* 2 org-gantt-core--day)) 'hour)
                     ((<= span (* 16 org-gantt-core--day)) 'day)
                     ((<= span (* 120 org-gantt-core--day)) 'week)
                     (t 'month)))
         (day (org-gantt-core-day-start from))
         ticks)
    (pcase unit
      ('hour
       (while (< day to)
         (dotimes (hour 12)
           (let ((at (+ day (* hour 2 60 60))))
             (when (and (>= at from) (< at to))
               (push (list :x (org-gantt-core--x at from to)
                           :label (if (= hour 0)
                                      (format-time-string "%a %-d %b" at)
                                    (format-time-string "%-H" at))
                           :major (= hour 0))
                     ticks))))
         (setq day (org-gantt-core-day-after day))))
      ('day
       (while (< day to)
         (when (>= day from)
           (push (list :x (org-gantt-core--x day from to)
                       :label (format-time-string "%a %-d" day)
                       :major (= 1 (org-gantt-core-dow day)))
                 ticks))
         (setq day (org-gantt-core-day-after day))))
      ('week
       (while (< day to)
         (when (and (>= day from) (= 1 (org-gantt-core-dow day)))
           (push (list :x (org-gantt-core--x day from to)
                       :label (format-time-string "%-d %b" day)
                       :major (< (nth 3 (decode-time day)) 8))
                 ticks))
         (setq day (org-gantt-core-day-after day))))
      ('month
       (while (< day to)
         (when (and (>= day from) (= 1 (nth 3 (decode-time day))))
           (push (list :x (org-gantt-core--x day from to)
                       :label (format-time-string "%b" day)
                       :major (= 1 (nth 4 (decode-time day))))
                 ticks))
         (setq day (org-gantt-core-day-after day)))))
    (nreverse ticks)))


;;;; Grouping and totals

(defun org-gantt-core-sort (rows)
  "Return ROWS in reading order: first touched first, untouched last.

Untouched rows go to the bottom rather than the top even though they
sort as nil, because a chart is read down the left edge and the rows
with bars on them are the ones worth reading first."
  (sort (copy-sequence rows)
        (lambda (a b)
          (let ((x (plist-get a :first)) (y (plist-get b :first)))
            (cond ((and x y) (if (= x y)
                                 (string< (or (plist-get a :title) "")
                                          (or (plist-get b :title) ""))
                               (< x y)))
                  (x t)
                  (y nil)
                  (t (string< (or (plist-get a :title) "")
                              (or (plist-get b :title) ""))))))))

(defun org-gantt-core-group (rows key)
  "Return ROWS gathered under KEY, a row property or nil for one flat group.

Each group is (:name NAME :rows ROWS :worked N :elapsed N :effort N),
with the group's span running from its earliest touch to its latest so
a collapsed group still draws one honest bar."
  (if (null key)
      (let ((sorted (org-gantt-core-sort rows)))
        (list (append (list :name nil :rows sorted) (org-gantt-core-totals sorted))))
    (let (groups)
      (dolist (row rows)
        (let* ((name (or (plist-get row key) "(none)"))
               (cell (assoc name groups)))
          (if cell
              (setcdr cell (cons row (cdr cell)))
            (push (cons name (list row)) groups))))
      (mapcar (lambda (cell)
                (let ((members (org-gantt-core-sort (nreverse (cdr cell)))))
                  (append (list :name (car cell) :rows members)
                          (org-gantt-core-totals members))))
              (sort (nreverse groups)
                    (lambda (a b) (string< (car a) (car b))))))))

(defun org-gantt-core-totals (rows)
  "Return the summed measurements of ROWS as a plist."
  (let ((worked 0) (provisional 0) (effort 0) (estimated 0) (touched 0) first last)
    (dolist (row rows)
      (cl-incf worked (or (plist-get row :worked) 0))
      (when (plist-get row :provisional)
        (cl-incf provisional (or (plist-get row :worked) 0)))
      (when (plist-get row :effort)
        (cl-incf effort (plist-get row :effort))
        (cl-incf estimated))
      (when (plist-get row :first)
        (cl-incf touched)
        (setq first (if first (min first (plist-get row :first)) (plist-get row :first))
              last (if last (max last (plist-get row :last)) (plist-get row :last)))))
    (list :worked worked
          :provisional provisional
          :effort (when (> estimated 0) effort)
          :estimated estimated
          :touched touched
          :count (length rows)
          :first first
          :last last
          :elapsed (when first (org-gantt-core-minutes first last))
          :ratio (when (and (> effort 0) (> worked 0)) (/ (float worked) effort)))))


;;;; The chart

(cl-defun org-gantt-core-chart (rows from to &key now group)
  "Return a drawable chart of ROWS over FROM..TO.

The one function the renderer calls.  It measures, places the plans,
lays out the bars, cuts the axis and groups the result:

  (:from S :to S :ticks (...) :groups (...) :totals (...) :rows (...))

Rows keep every field they came in with, so the table under the chart
and the chart itself are the same data seen twice -- which is the
point: a bar you cannot read the numbers off is a decoration."
  (let* ((now (or now (floor (float-time))))
         (measured (org-gantt-core-summarize rows now))
         (placed (org-gantt-core-place-plans measured))
         (laid (org-gantt-core-layout placed from to)))
    (list :from from :to to :now now
          :now-x (when (and (>= now from) (<= now to))
                   (org-gantt-core--x now from to))
          :ticks (org-gantt-core-ticks from to)
          :rows laid
          :groups (org-gantt-core-group laid group)
          :totals (org-gantt-core-totals laid))))

(defun org-gantt-core-lines (chart)
  "Return CHART's groups flattened into the lines a view draws.

Each line is (:kind group|row :group G) or (:kind row :row R).  The
chart and the table under it both walk this list, which is what keeps
line seven of the table describing bar seven of the chart -- two views
of one list, rather than two lists that agree until they do not."
  (cl-loop for group in (plist-get chart :groups)
           append (append
                   (when (plist-get group :name)
                     (list (list :kind 'group :group group)))
                   (mapcar (lambda (row) (list :kind 'row :row row))
                           (plist-get group :rows)))))

(provide 'org-gantt-core)
;;; org-gantt-core.el ends here
