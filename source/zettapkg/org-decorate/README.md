# org-decorate

Classify a raw inbox entry against lists that already exist in the
config, with a model; a person accepts or corrects.

Decoration writes only `AI_`-prefixed properties. It never sets the
keyword, tags, dates, `Effort` or any canonical field, never refiles,
and never touches the heading or body. The person writes the words and
decides commitment or option; the model sorts against a dozen known
labels.

```org
* dryer sheets
:PROPERTIES:
:CREATED:  [2026-08-14 Fri 09:41]
:AI_KIND:  task
:AI_KEYWORD: TODO
:AI_TARGET: (todo) buy.org
:AI_CONTEXT: @errand
:AI_EFFORT: 0:10
:AI_WHY:   a purchasable household item; no date, no consequence stated
:AI_CONFIDENCE: 0.88 kind=0.95 target=0.90
:AI_STAMP: [2026-09-12 Sat 21:00] local qwen2.5:7b prompt=1 schema=1
:AI_HASH:  3f9c1a...
:END:
```

| command                    | does                                                    |
|----------------------------|---------------------------------------------------------|
| `org-decorate-inbox`       | decorate every undecorated entry in the inbox, in turn  |
| `org-decorate-this`        | decorate the entry at point                             |
| `org-decorate-accept`      | promote every proposal, strip the `AI_` set, refile: one apply |
| `org-decorate-accept-field`| one field, by completion; the rest are corrections      |
| `org-decorate-reject`      | strip, and stamp `AI_REJECTED` for this prompt version  |
| `org-decorate-git-evidence`| commits naming an entry's ID become `EVIDENCE_DONE`     |

## The contract

- Only values from the closed lists: keywords (never NEXT, PROG, DONE,
  NOPE), the agenda files' categories, refile targets, one context and
  one energy tag from `org-tag-alist`'s groups, topical tags that exist,
  a rung of `Effort_ALL`, impact 1-5 only with quoted evidence, a hard
  or soft deadline type. Anything else is dropped and the drop is
  written into `AI_WHY`.
- Dates are phrases, resolved in elisp against `CREATED`, not now:
  "tue" written on Thursday the 3rd is the 8th whatever day decoration
  runs. `org-read-date` resolves weekday names against the current date
  and ignores the base it is given, so the resolver is our own
  (`org-decorate-core-resolve-phrase`), pinned by tests.
- Idempotent on (content hash, prompt version, schema version); a
  rejection under the same prompt is not re-proposed; a `:private:`
  entry is never sent.
- A duplicate needs two signals: a similarity above the threshold and
  either an exact normalised title or the same backlink. A single high
  score is related, not duplicate. A match against a finished entry is
  not a duplicate: it came back.
- Every write goes through org-queue's apply layer, so a decoration, an
  accept and a reject are each one logged, undoable transaction.

## Shape

| file                        | role                                            | needs Org |
|-----------------------------|-------------------------------------------------|-----------|
| `org-decorate-core.el`      | validate, resolve, merge, accept, duplicates    | no        |
| `org-decorate-lists.el`     | the closed lists and the entry plist            | yes       |
| `org-decorate.el`           | the request chain, the keys, git, capture hooks | yes       |
| `prompt.org`                | the system prompt, `#+PROMPT_VERSION`           |           |
| `test/org-decorate-core-test.el` | ERT over canned proposals                  | no        |
| `test/org-decorate-test.el` | ERT over a fixture inbox with a stubbed model   | yes       |

```sh
emacs -Q --batch -L source/zettapkg/org-decorate \
  -l source/zettapkg/org-decorate/test/org-decorate-core-test.el \
  -f ert-run-tests-batch-and-exit
```

The model is reached through `gptel-request` with `:schema`;
`org-decorate-backend` is `local` (Ollama, OpenAI-compatible endpoint)
or `claude`. `org-decorate-model-function` and
`org-decorate-neighbours-function` are the seams the tests stub.
