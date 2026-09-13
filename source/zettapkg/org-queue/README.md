# org-queue

Fill a day from the Org backlog, and say what it left out.

`M-x org-queue-today` reads `org-agenda-files`, decides what today can
actually hold, and draws the result:

```
Tuesday 8 September 2026   3:47 planned of 4:00 usable (5:00 capacity, 20% slack)

Committed
    1:30  cal     Architecture review                      appointment
    0:13  work    File expenses for the August conference  due today

Chosen
    0:36  emacs   Restore gc-cons-percentage in bootstrap-gcmh   12.4
    0:14  home    Take the bins out                              12.3

25 cut, 47 excluded, 4 deferred.  TAB to see why.
```

| key   | does                                  |
|-------|---------------------------------------|
| `RET` | jump to the task                      |
| `o`   | show it in another window             |
| `g`   | replan                                |
| `TAB` | expand what was cut, deferred, excluded |
| `c`   | estimate-versus-clock calibration      |

Each line shows minutes, category, TODO state and title. The rest of
the metadata is one key per column, so the default stays readable and
the full picture is there when you argue with a decision:

| key | column   | shows                                   |
|-----|----------|-----------------------------------------|
| `s` | state    | the TODO keyword (on by default)        |
| `#` | priority | the cookie, `#A`                        |
| `e` | estimate | the entry's own `:Effort:`, `?` if none |
| `i` | impact   | `:IMPACT:`, as `i4`                     |
| `d` | dates    | `S` scheduled, `D` deadline, `~` = soft |
| `w` | age      | days since `:CREATED:`                  |
| `k` | clocked  | minutes the derived clock has measured  |
| `t` | tags     | after the title                         |
| `f` | file     | after the title                         |
| `a` | all      | everything on, or back to state alone   |

The choice is remembered for the session (`org-queue-columns`).

Five keys write to the entry under point, the only writes this buffer
makes. Each is a decision you took on one line:

| key | writes                                              |
|-----|-----------------------------------------------------|
| `S` | SCHEDULED on this day, stamped `:PLACED:`           |
| `L` | SCHEDULED on a day you choose, stamped `:PLACED:`   |
| `N` | state NEXT                                          |
| `H` | state HOLD (the state asks for its note)            |
| `U` | removes SCHEDULED (asks first if a person wrote it) |

`M-x org-queue-undo-apply` reverses the last write, and is itself logged.

## Buckets

A day is a few named pools, not one. Each bucket is a reservation and a
limit: the packer fills it even when better-scoring work exists
elsewhere, and never past its minutes.

```elisp
(setq org-queue-buckets
      '((work         :minutes 300 :match (:category ("work" "emacs")))
        (reading      :minutes 60  :match (:tags ("reading")))
        (housekeeping :minutes 30  :match (:tags ("housekeeping")))
        (default      :minutes 60)))
```

`:minutes` is an integer or a per-weekday alist; the first bucket whose
`:match` holds claims a task; anything unclaimed is `default`; `:spill t`
hands a bucket's unused minutes to `default`. With no buckets,
`org-queue-capacity` is the only bucket and nothing changes. Overcommitment
is reported per bucket, and the other buckets still fill.

## Habits

An entry with `:STYLE: habit` is time already decided, not a task: it is
subtracted from its bucket before packing and listed under **Routine**.
`:HABIT_DAYS: Mon Tue Wed Thu Fri Sat` is the weekday set ("except
Sundays"); absent means every day. Slack is taken after the routine, so a
five-hour day with an hour of habits has `(300 - 60) * 0.8` usable minutes.

## Backpressure

A hard deadline commits a task from its **start-by** day: the latest day
on which the calibrated effort still fits into the free minutes of the
days up to and including the deadline. The note reads "start by <day>,
due <day>". Soft deadlines get none of this.

## The horizon and the proposal

`M-x org-queue-horizon` runs the day packer across a range (today,
tomorrow, 3 days, week, fortnight, month, backlog, or until a date) with
the pool evolving as it goes: a task planned on one day is gone the next,
deferred work arrives on its day, and a commitment too big for its day is
**sliced** across the days before its deadline. Read-only; TAB opens a
day.

`M-x org-queue-propose` turns that simulation into a list of placements
for review, and is the only bulk writer:

- schedules what has no date, moves what the machine placed before,
  unschedules a machine placement the simulation no longer uses;
- never touches a date a person wrote, never proposes a deadline or a
  state; a deadline the days cannot cover is a **finding**;
- skips what a date already fixes (an appointment on its day, a task on
  its deadline day);
- is idempotent: accept everything, run again, and it is empty;
- remembers a rejection for `org-queue-rejection-days` (14).

| key       | does                                                |
|-----------|-----------------------------------------------------|
| `a` / `r` | accept / reject the line, or every line in the region |
| `A` / `R` | accept / reject the whole day                       |
| `C-c C-a` | accept everything                                   |
| `e`       | change the day; the placement becomes yours (no stamp) |
| `g`       | propose again, keeping marks on unchanged lines     |
| `C-c C-c` | apply the accepted lines, all or none, and log them |
| `q`       | abandon; nothing is written                         |

An accepted placement is a SCHEDULED stamp with `:PLACED:`, so the day
packer treats it as a commitment on its day and `,-o-Q` reads it back like
anything a person wrote.

## How it decides

**Commitments** come first and are never scored: scheduled *on* today,
due today or earlier, or carrying a plain active timestamp that falls on
today. If those alone overflow the day the plan says so and stops —
overcommitment is information, not a bug to route around.

**Candidates** are then scored:

```
score =  deadline * urgency(days until deadline)   convex; overdue pinned to 1
       + priority * priority weight                A > B > none > C
       + age      * log(1 + days since created)
       + progress * (state is PROG)                finishing beats starting
       + quick    * (effort <= 15 min)
       + carry    * (was on an earlier plan, or scheduled for a day gone by)
       - glut     * (tasks already picked from this category)
```

and packed into the day highest first, leaving
`org-queue-slack-fraction` unplanned, capped at `org-queue-wip-limit`
PROG items. A task with no `:Effort:` is planned against
`org-queue-default-effort` and marked as guessed — an estimate is
encouraged, never required.

Estimates are scaled by what the clock has actually measured, per
category, shrunk toward the overall factor so two finished tasks cannot
swing the packing. `c` shows the evidence; `org-queue-calibrate` turns it
off.

## Shape

| file                        | role                              | needs Org |
|-----------------------------|-----------------------------------|-----------|
| `org-queue-core.el`         | scoring, packing, calibration     | no        |
| `org-queue-harvest.el`      | `org-ql` query → task plists      | yes       |
| `org-queue-horizon.el`      | many-day simulation, proposals    | no        |
| `org-queue-apply.el`        | the writes, their log, undo       | yes       |
| `org-queue.el`              | commands, buffer, keymap          | yes       |
| `org-queue-propose.el`      | horizon and proposal buffers      | yes       |
| `test/*-test.el`            | ERT: core, horizon (no Org); harvest, apply (Org) | mixed |

The core takes a list of plists and returns a list of plists, so the
formula can be argued with in batch:

```sh
emacs -Q --batch -L source/zettapkg/org-queue \
  -l source/zettapkg/org-queue/test/org-queue-core-test.el \
  -f ert-run-tests-batch-and-exit
```

Every task handed to `org-queue-core-plan` comes back out in exactly one
of `:planned`, `:cut`, `:dropped` or `:deferred`, each with a reason. A
planner you cannot interrogate gets abandoned.
