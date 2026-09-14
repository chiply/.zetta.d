# org-routine

The daily routine as a machine-readable template.

The routine is a prose note with a table in it. Give the table a
`#+NAME: routine` line and three columns the prose never needed --
`kind`, `days`, `bucket`, plus `habit` -- and the rest of the config can
read it:

```org
#+NAME: routine
| Time        | Activity               | Notes | kind  | days     | bucket       | habit |
|-------------+------------------------+-------+-------+----------+--------------+-------|
| 05:00–05:30 | Clean apartment        |       | fixed |          | housekeeping | yes   |
| 06:00–07:00 | Lift weights           |       | fixed | Mon-Sat  | body         | yes   |
| 08:00–12:00 | Focus block 1 (4h)     |       | focus | weekdays | work         |       |
| 13:30–15:00 | Focus block 2, the dip |       | dip   | weekdays | work         |       |
| 15:00–17:00 | Focus block 2, vague   |       | focus | weekdays | work         |       |
| 18:00–20:00 | Free time / admin      |       | admin | weekdays |              |       |
```

- `kind` is `fixed`, `focus`, `dip`, `admin` or `off`.
- `days` is a weekday set: `Mon Tue`, `Mon-Fri`, `weekdays`, `weekend`;
  blank means every day.
- `bucket` names the queue bucket the row's minutes belong to; blank
  means the kind's default (`focus` and `dip` are `work`, `admin` is
  `housekeeping`).
- `habit` marks a fixed row that should exist as a habit entry.

A second table, `#+NAME: variants`, overrides rows on named days (an
interview morning, a travel day); the report says which rows a variant
removed.

## What it answers

| question                          | function                        |
|-----------------------------------|---------------------------------|
| today's blocks                    | `org-routine-blocks`            |
| is now inside the dip             | `org-routine-in-dip-p`          |
| the kick / review / quiet windows | `org-routine-windows`           |
| the queue's buckets and capacity  | `org-routine-apply-to-queue`    |
| the habits file                   | `org-routine-generate-habits`   |
| the day's shape, in a buffer      | `M-x org-routine-report`        |

Capacity for a weekday is the focus, dip and admin minutes; the packer
takes its slack from that. The derived bucket table gives `work` the
focus and dip minutes, `housekeeping` the admin minutes, and each habit
its own bucket's reservation, with `default` a fixed floor.

The habits file is **generated, never hand-edited**: it starts with a
`#+GENERATED` line and the generator refuses to overwrite a file that
lacks one. IDs are kept by title across regenerations, so the queue's
plan history keeps meaning something.

## Shape

| file                        | role                                    | needs Org |
|-----------------------------|-----------------------------------------|-----------|
| `org-routine-core.el`       | the parser and every question over it   | no        |
| `org-routine.el`            | reading the file, the queue, the habits | yes       |
| `test/org-routine-core-test.el` | ERT over a copy of the table        | no        |
| `test/org-routine-test.el`  | ERT over a fixture file and the harvest | yes       |

```sh
emacs -Q --batch -L source/zettapkg/org-routine \
  -l source/zettapkg/org-routine/test/org-routine-core-test.el \
  -f ert-run-tests-batch-and-exit
```

A malformed row fails with its line number, never with a partial
capacity: a wrong capacity is worse than none.
