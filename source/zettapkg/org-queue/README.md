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
| `org-queue.el`              | commands, buffer, keymap          | yes       |
| `test/org-queue-core-test.el` | ERT over hand-built fixtures    | no        |

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
