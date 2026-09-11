# org-gantt

A Gantt chart, a week grid and a clock table over Org **state transitions**.

Nothing here clocks. Time is expressed the way Jira expresses it — as the
interval between two TODO state changes, each already stamped into the
LOGBOOK by the `!` and `@` flags in `org-todo-keywords`:

```org
* PROG Draft the roadmap
  :LOGBOOK:
  - State "DONE"       from "PROG"       [2026-09-08 Tue 10:40]
  - State "PROG"       from "TODO"       [2026-09-08 Tue 09:12]
  :END:
```

is 88 minutes of work, and no ritual was needed to record it. Entering a
working state starts the clock; leaving it stops it.

## The views

| Command                        | Shows                                                     |
|--------------------------------|-----------------------------------------------------------|
| `org-gantt`                    | the chart: one row per task, plan rail over actual rail    |
| `org-gantt-today`              | the same, for today                                       |
| `org-gantt-timegrid-composite` | a week grid with the plan and the actual in each day       |
| `org-gantt-timegrid-spent`     | a week grid of time spent only                            |
| `org-gantt-timegrid-planned`   | a week grid of the plan only                              |

In the chart buffer:

| key       | does                                                    |
|-----------|---------------------------------------------------------|
| `n` / `p` | move the cursor (`j` / `k` too)                         |
| `TAB`     | show the transitions the row's bar was built from       |
| `RET`     | visit the entry                                         |
| `f` / `b` | move the range forward / back by its own length         |
| `+` / `-` | double / halve the range                                |
| `r`       | chart the last N days                                   |
| `s`       | set the org-ql query                                    |
| `G`       | group by category, file, state, or nothing              |
| `o`       | cycle the overlap policy                                |
| `t`       | show or hide the table                                  |
| `g` / `q` | refresh / quit                                          |

## Two rails, and two clocks

Each chart row draws **what was planned** as a thin upper rail and **what
happened** as a thick lower rail, cut into the states that were held.
Neither is invented when it is missing: a row with no upper rail was never
planned, a row with no lower rail was never touched, and both absences are
findings.

The plan has two sources, drawn differently because they are different
claims:

- **queue** — a day `org-queue` committed to, from `org-queue-history`
- **schedule** — a `SCHEDULED` stamp plus `:Effort:`

Neither source records an *hour*: `org-queue-record-plan` writes ids, and a
date-only `SCHEDULED` is a day. So only a stamp naming a time becomes a
fixed block; everything else is laid through the day's working windows in
order. The planned lane is the *shape* of a day, not a claim about 09:15.

Two numbers are kept for every row and neither corrects the other:

- `worked` — working-state minutes, clipped to `org-gantt-window`
- `open` — raw wall time from first touch to last

A task moved to PROG on Tuesday afternoon and DONE on Wednesday morning is
eighteen hours open and three hours worked. Painting the night solid on a
week grid would be a lie about the day; erasing it from the Gantt would be a
lie about the task. So **the grid clips and the Gantt runs raw**.

A number carrying a `~` is provisional: it comes from an entry still sitting
in PROG from a previous day, which has been accruing every working hour
since. That is the honest reading of time-in-status and a bad number to
calibrate against, so it is labelled rather than quietly capped.

## Scoping

Any `org-ql` query, plus two predicates this package adds over the derived
clock:

```elisp
(worked-on -7)                  ; worked on in the last week
(worked-on "2026-09-01" "2026-09-08")
(state-during "WAIT" -14)       ; sat blocked at some point in a fortnight
(and (tags "@deep") (worked-on -7))
```

`worked-on` is not `clocked`: nothing here writes CLOCK lines, and the
evidence is the state log.

## Layout

```
org-gantt-core.el       the arithmetic: plists in, plists out, no Org, no SVG
org-gantt-harvest.el    org-ql and the LOGBOOK in, rows out
org-gantt-svg.el        rows in, one image out
org-gantt-timegrid.el   the same rows as a read-only org-timegrid backend
org-gantt.el            the buffer, the keys, the table, the dynamic block
```

The state log is parsed by `org-queue-state-log`, not by a second regexp of
this package's own: a chart that disagreed with the queue about how long
something took would be worse than no chart.

The grid views are a **backend**, not a fork. `org-timegrid` takes its
events from a struct of functions whose mutation slots may be nil, so a
read-only source of derived events inherits the whole renderer. Every
mutation slot is left nil deliberately — dragging a derived block would mean
rewriting a LOGBOOK stamp to move work that already happened.

## The dynamic block

```org
#+BEGIN: org-gantt-table :days 7 :group :category
#+END:
```

The same numbers as the chart, in a table a weekly review file can keep.

## Tests

```sh
emacs -Q --batch -L source/zettapkg/org-gantt \
  -l source/zettapkg/org-gantt/test/org-gantt-core-test.el \
  -f ert-run-tests-batch-and-exit
```

23 tests, no Org, no files, no clock. The fixtures pin both the time and the
zone: a suite that passes in London and fails in Sydney is testing the
machine.

If a run disagrees with the source you just edited, delete any stale `.elc`
in the package directory — batch Emacs loads a byte-compiled file in
preference to a newer source one.
