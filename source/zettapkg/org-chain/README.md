# org-chain

Agent chains: kick, flight, landing, review.

One state, `AGENT`, says an agent has the ball. The lifecycle uses
states that already exist: PROG while you write the prompt, AGENT on
kickoff, NEXT when the run finished or QUES when the agent stopped to
ask, PROG while you review, then DONE, AGENT again, or NOPE. Every hop
is a logged transition, so the derived clock gets the split for free:
PROG intervals are your minutes, AGENT intervals the machine's.

| command           | does                                                          |
|-------------------|---------------------------------------------------------------|
| `org-chain-kick`  | write `AGENT_SESSION`, open `claude --session-id UUID "<prompt>"`, transition to AGENT; refused without a prompt or past `org-chain-limit` (C-u overrides, logged); C-u C-u runs `claude -p` in a worktree |
| `org-chain-land`  | apply the landing log: AGENT to NEXT on a stop, to QUES on a question, once per line; orphans reported |
| `org-chain-watch` | watch the log with file-notify, and read it every minute besides |
| `org-chain-chains`| every chain with its metrics: iterations, latency, review lag, your minutes and the machine's |

The prompt is the task: the entry's body, or the body of a `Prompt`
sub-heading when the entry holds notes too, passed through untouched.

## Landing

The Claude Code Stop and Notification hooks append one plist per line
to the landing log:

```elisp
(:session "UUID" :at 1789000000 :cwd "/path" :event stop :text "...")
```

No hook evaluates elisp; Emacs reads the file. A landing never raises a
prompt: a stop is a notification (held in a quiet window of the
routine), a question a mark in the mode line.

## The morning line

Each chain lands every `latency + cycle` minutes and each landing costs
you `cycle` minutes. Three chains at fifteen minutes of latency and a
twenty-minute cycle need 360 minutes of you in a four-hour block; two
need 240. The line says when fewer would do. Latency and cycle are
medians over the chains measured so far, with defaults until then.

## Shape

| file                        | role                                             | needs Org |
|-----------------------------|--------------------------------------------------|-----------|
| `org-chain-core.el`         | prompt, kick rule, landing, metrics, the line    | no        |
| `org-chain.el`              | the entry, the terminal, the log, the views      | yes       |
| `test/org-chain-core-test.el` | ERT over a landing log and a transition fixture | no       |
| `test/org-chain-test.el`    | ERT over a temp corpus with a stubbed terminal   | yes       |

```sh
emacs -Q --batch -L source/zettapkg/org-chain \
  -l source/zettapkg/org-chain/test/org-chain-core-test.el \
  -f ert-run-tests-batch-and-exit
```
