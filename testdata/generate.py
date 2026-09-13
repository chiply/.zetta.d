#!/usr/bin/env python3
"""Generate a rich, realistic two-month (todo) corpus for the time system.

Deterministic: seeded RNG and a pinned TODAY, so regenerating is reproducible.

    python3 generate.py [--today YYYY-MM-DD] [--seed N]   # --today defaults to today

Aims to exercise every consumer at once:
  * the queue      -- states, priority, effort, deadlines, blockers, carry-over
  * column view    -- Effort vs CLOCKSUM, parents summing from children
  * the smart tree -- every entry carries an :ID: for #+transclude:
  * timegrid/calfw -- timed ranges, multi-day spans, all-day events, repeaters
  * calibration    -- clocked actuals that diverge from their estimates
"""
import argparse, datetime as dt, random, pathlib, re, uuid

EFFORT_ALL = ("0 0:05 0:10 0:15 0:20 0:30 0:45 1:00 1:30 "
              "2:00 3:00 4:00 5:00 6:00 7:00")
COLUMNS = ("%40ITEM(Task) %TODO %3PRIORITY(P) %6IMPACT(Imp) "
           "%17Effort(Estimate){:} "
           "%CLOCKSUM(Clocked) %DEADLINE %SCHEDULED %TAGS")
# Finer at the short end so `org-queue-quick-threshold' (15 minutes) has
# values to actually match, and the packer has resolution below half an hour.
SIZE = {"tiny": ["0:05", "0:10", "0:15", "0:20", "0:30"],
        "mid": ["0:45", "1:00", "1:30", "2:00", "3:00"],
        "big": ["4:00", "5:00", "6:00"]}
# Energy is a second, orthogonal tag group: a shallow task can still need
# a clear head, and a deep one can sometimes be done tired.
ENERGY = ["@fresh", "@tired"]
# `org-todo-keywords' logs a note on entering WAIT, QUES, HOLD and NOPE.
# The fixture writes plausible ones so the Chase and Parked views have the
# reason text they exist to surface.
WAIT_NOTES = ["Pinged again, no reply yet.",
              "Blocked until they come back from leave.",
              "Sent the details, waiting on confirmation.",
              "Third ask. Escalate if nothing by Friday."]
HOLD_NOTES = ["Parked until the quarter turns over.",
              "Not worth doing before the migration lands.",
              "Waiting to see if this solves itself.",
              "Revisit when there is budget."]
NOPE_NOTES = ["Superseded by the new pipeline.",
              "Decided against -- cost outweighed the benefit.",
              "No longer relevant after the rewrite.",
              "Duplicate of another entry."]
# Who a WAIT/QUES is parked on.  Free text in the real schema, so the
# fixture uses a mix of people and teams.
WAITING = ["Sam", "legal", "the vendor", "Priya", "IT", "my accountant"]

def T(name, tags, size, **kw):
    d = {"t": name, "tags": tags, "size": size}
    d.update(kw)
    return d

FILES = {
"emacs": ("emacs", "Emacs configuration and tooling", [
 T("Memoize svg-line renderers with a content hash", "@deep perf", "big",
   state="PROG", prio="A",
   body="`svg-line--render' rebuilds unconditionally on every call; the only\ncache is minibuffer-freeze. Measured ~6.4ms per redisplay pass across six\nwindows, ~20x/second.\n\nSee [[file:OPTIMIZATIONS.org][OPTIMIZATIONS.org]] for the measurements.",
   sub=[("Hash the built SVG string per (NAME . window)", "1:00", "DONE"),
        ("Return the memoized display string on a match", "1:00", "PROG"),
        ("Keep store-placements outside the short-circuit", "0:30", "TODO"),
        ("Benchmark before and after", "0:30", "TODO")]),
 T("Drop the flappy-fish 5Hz mode-line timer", "@shallow perf", "tiny",
   state="DONE", body="Five forced redisplays a second to animate a string\nnothing renders -- telephone-line is not active."),
 T("Restore gc-cons-percentage in bootstrap-gcmh", "@shallow perf", "tiny", prio="A"),
 T("Move read-process-output-max back to 4MB", "@shallow perf", "tiny", prio="B"),
 T("Byte-compile modules instead of load-file", "@deep perf", "big", prio="B",
   body="662 of 702 zetta-* functions run interpreted. The .elc files exist\nand are fresh; `load-file' just can't prefer them.",
   sub=[("Prefer .elc with a per-file condition-case", "2:00", "TODO"),
        ("Verify as-elc goes 0 -> 294 via the load-history probe", "0:30", "TODO")]),
 T("Replace vc segment shell-outs with filesystem reads", "@deep perf", "mid",
   blocked=True),
 T("Make zetta-op-read lazy so startup stops blocking", "@deep startup", "mid",
   prio="A", pin=("dead", 1), body="Measured 1.05-1.21s of a 9.17s init, and that is with the\nvault already unlocked."),
 T("Add :commands to pr-review and ein", "@shallow startup", "tiny", state="DONE",
   legacy_clock=True),
 T("Fix TLS trust config in security.el", "@deep security", "mid", prio="A",
   body="gnutls-trustfiles is literally (\"zsh:1: command not found: -m\")\nwhile gnutls-verify-error is t."),
 T("Wire org-other-agenda into the org module", "@deep org", "mid",
   body="Needs TextUI vendored too -- not on MELPA.",
   sub=[("Add the textui elpaca recipe", "0:30", "TODO"),
        ("Configure org-other-agenda-series", "1:00", "TODO")]),
 T("Prototype org-transclusion live-sync task view", "@deep org", "big", prio="A",
   state="PROG", pin=("sched", 1),
   body="The only item in the plan with real design risk. Does live-sync\nfeel first class, or does the modal `e' gesture grate?"),
 T("Write ERT tests for the queue scorer", "@deep org test", "mid"),
 T("Audit which of the 145 eager use-package blocks matter", "@deep startup", "big",
   state="HOLD", body="Parked until use-package-compute-statistics says whether\nthey are actually the missing 7.7s."),
 T("Teach brushup about org-timegrid event rungs", "@shallow ui", "tiny", state="DONE"),
 T("Cut dimmer-mode, keep solaire", "@shallow ui", "tiny", state="IDEA"),
 T("Kill the Spotify HTTP buffer leak", "@deep perf", "mid",
   body="51 of 86 buffers were *http api.spotify.com:443*."),
 T("Should QUES entries be queueable at all?", "@deep org", "tiny", state="QUES"),
]),
"work": ("work", "Professional and project work", [
 # Two projects for the invariant (G8): one whose children are all done
 # or parked -- dormant, nobody has decided what comes next -- and one
 # whose children are all done, which is a project to close.
 # Serves a mission of the season (G5): the children inherit MISSION.
 T("Retrieval service launch plan", "@deep planning", "mid",
   state="PROG", mission="M-RETRIEVAL",
   sub=[("Collect input from the team", "1:00", "DONE"),
        ("Write the first draft", "2:00", "TODO"),
        ("Review with Sam", "0:30", "TODO"),
        ("Publish", "0:15", "TODO")]),
 T("Vendor evaluation", "@deep procurement", "mid", state="TODO",
   body="Three vendors shortlisted in June. The last child was parked and\nnothing has replaced it.",
   sub=[("Collect the three quotes", "1:00", "DONE"),
        ("Reference calls", "1:00", "DONE"),
        ("Draft the recommendation", "2:00", "HOLD")]),
 T("Q2 retrospective", "@shallow", "tiny", state="TODO",
   sub=[("Collect the numbers", "0:30", "DONE"),
        ("Write it up", "0:45", "DONE")]),
 T("Draft Q4 roadmap for the retrieval service", "@deep planning", "big", prio="A",
   state="PROG",
   body="Three themes so far: enrichment, gold-set curation, and whether the\nCLIP tier earns its keep.",
   sub=[("Collect input from the team", "1:00", "DONE"),
        ("Draft the enrichment section", "2:00", "PROG"),
        ("Cost the CLIP tier decision", "2:00", "TODO"),
        ("Circulate for review", "0:30", "TODO")]),
 T("Review the reranker benchmark writeup", "@deep review", "mid", prio="B",
   pin=("sched", 2)),
 T("Prepare slides for the architecture review", "@deep present", "big", prio="A",
   pin=("dead", 1)),
 T("Reply to the vendor security questionnaire", "@shallow admin", "mid",
   state="WAIT", body="Waiting on legal for the subprocessor list."),
 T("Update the on-call runbook for the index rebuild", "@deep docs", "mid"),
 T("Pair with Sam on the ingestion backpressure bug", "@deep pairing", "mid"),
 T("File expenses for the August conference", "@shallow admin", "tiny", prio="C"),
 T("Interview debrief writeup", "@shallow hiring", "tiny", state="DONE"),
 T("Decide whether to keep the CLIP tier", "@deep decision", "mid", state="QUES",
   body="Measured 36%/46% OCR-vs-CLIP split. Scores are shown rather than\nfiltered, which may be the wrong call.", blocked=True),
 T("Cut the 0.4.0 release", "@deep release", "mid", blocked=True, pin=("dead", 3)),
 T("Rotate the Algolia API key and audit its ACLs", "@deep security", "mid", prio="A",
   pin=("dead", -1),
   body="The key baked into the public bundle has addObject, deleteIndex and\nsettings ACLs. Rotate regardless."),
 T("Write the postmortem for the Aug 21 outage", "@deep docs", "big", prio="B",
   sub=[("Assemble the timeline", "1:00", "DONE"),
        ("Identify contributing factors", "2:00", "TODO"),
        ("Write up remediations", "2:00", "TODO")]),
 T("Renew the team's model API quota", "@shallow admin", "tiny"),
 T("Sync with design on the dashboard redesign", "@call", "mid"),
 T("Archive the retired ingestion prototype", "@shallow admin", "tiny", state="NOPE",
   body="Superseded -- the prototype was folded into the main pipeline."),
]),
"home": ("home", "Household, admin and errands", [
 T("Renew British passport", "@errand admin", "mid", prio="A",
   body="Needs photos and the old passport.",
   sub=[("Get passport photos", "0:30", "DONE"),
        ("Fill in the online form", "1:00", "TODO"),
        ("Post the old passport", "0:30", "TODO")]),
 T("File the 2025 tax return", "@deep admin finance", "big", prio="A",
   pin=("dead", 9)),
 T("Chase the insurer about the outstanding claim", "@call finance", "mid", state="WAIT",
   body="Third time asking. Claim ref in the email thread."),
 T("Track down the old TIAA 401k", "@call finance", "tiny", state="NEXT"),
 T("Cancel Hodinkee insurance before renewal", "@call admin", "tiny", prio="A",
   pin=("dead", 4),
   body="Covered through 2027-02-09, so cancel well before."),
 T("Cancel HBO Max", "@shallow admin", "tiny", state="HOLD",
   body="Not until Game of Thrones is finished."),
 T("Clean out the freezer", "@errand", "tiny", state="DONE", legacy_clock=True),
 T("Replace the missing Rolex bracelet link", "@errand", "tiny"),
 T("Descale the coffee machine", "@shallow housekeeping", "tiny"),
 T("Sort the recycling", "@shallow housekeeping", "tiny"),
 T("Book the dentist", "@call health", "tiny", state="DONE"),
 T("Service the car", "@errand", "mid", pin=("sched", 3)),
 T("Sort out the unemployment paperwork", "@deep admin", "mid", prio="B"),
 T("Hang the picture frames", "@errand", "tiny", state="IDEA"),
 T("Deep clean the garage", "@errand", "big", state="IDEA"),
 T("Water the plants", "@errand", "tiny", repeat="+3d"),
 T("Take the bins out", "@errand", "tiny", repeat="+1w"),
]),
"learning": ("learn", "Study and reading", [
 T("Finish the MPS garbage collector paper", "@deep reading", "mid", state="PROG",
   pin=("sched", 0),
   body="Relevant to whether feature/igc3 is worth evaluating."),
 T("Work through the Rust ownership chapter", "@deep reading", "mid"),
 T("Watch the EmacsConf talk on org-ql", "@shallow video", "tiny", state="DONE"),
 T("Read the Ravenbrook MPS design docs", "@deep reading", "big", state="IDEA"),
 T("Try the new tree-sitter query syntax", "@deep practice", "mid"),
 T("Take notes on the retrieval-augmentation survey", "@deep reading", "mid"),
 T("Read the Emacs 31 NEWS file", "@shallow reading", "tiny"),
 T("Rebuild the SQL study deck", "@shallow practice", "mid", state="HOLD"),
 T("Read up on org-element caching", "@deep reading", "mid",
   body="Prompted by org-fold-core-style being set to `overlays' by something\nunidentified."),
 T("Weekly review", "@deep review", "mid", repeat=".+1w", prio="B"),
]),
"buy": ("buy", "Things to purchase", [
 T("England shirt", "@errand", "tiny"),
 T("Replacement picture frame glass", "@errand", "tiny"),
 T("Kindle for the reading backlog", "@shallow", "tiny", state="DONE",
   body="Decided plain Kindle over Boox -- see the ereader research note."),
 T("New desk lamp", "@shallow", "tiny", state="IDEA"),
 T("Coffee grinder burrs", "@shallow", "tiny", pin=("dead", 6)),
 T("Winter walking boots", "@errand", "tiny", state="IDEA"),
 T("Standing desk mat", "@shallow", "tiny", state="NOPE"),
]),
}

# Calendar entries are commitments with real clock times, so they are built
# separately -- the timegrid and calfw need durations, spans and repeats.
EVENTS = [
 ("Architecture review",      "@meeting work",   2,  "10:00", "11:30", None),
 ("1:1 with manager",         "@meeting work",   0,  "15:00", "15:30", "+1w"),
 ("Team retro",               "@meeting work",   2,  "14:00", "15:00", "+2w"),
 ("Dentist appointment",      "@meeting health", 5,  "09:20", "10:00", None),
 ("Car service drop-off",     "@errand",         9,  "08:00", "08:30", None),
 ("Standup",                  "@meeting work",   1,  "09:30", "09:45", "+1d"),
 ("Design sync",              "@meeting work",   3,  "11:00", "12:00", "+1w"),
 ("Flight to Boston",         "@travel",        12,  "07:15", "10:40", None),
 ("Conference",               "@travel",        13,  None,    None,   None, 3),
 ("Quarterly planning offsite","@meeting work", 24,  None,    None,   None, 2),
 ("Sam's leaving drinks",     "@social",         6,  "18:00", "20:00", None),
 ("Board game night",         "@social",        -4,  "19:00", "22:00", None),
 ("Physio",                   "@health",       -11,  "08:30", "09:15", None),
]

def day(d): return d.strftime("%a")
def act(d, t=None, rep=None):
    s = f"<{d:%Y-%m-%d} {day(d)}" + (f" {t}" if t else "") + (f" {rep}" if rep else "")
    return s + ">"
def ina(d, t=None):
    return f"[{d:%Y-%m-%d} {day(d)}" + (f" {t}" if t else "") + "]"
def oid(rng):
    return str(uuid.UUID(int=rng.getrandbits(128), version=4)).upper()
def mins(e):
    h, m = map(int, e.split(":")); return h * 60 + m
def hhmm(m): return f"{m // 60}:{m % 60:02d}"

def inat(when):
    """Inactive Org stamp for a datetime, to the minute (Org drops seconds)."""
    return f"[{when:%Y-%m-%d} {day(when)} {when:%H:%M}]"

def state_line(state, frm, when):
    """One LOGBOOK state-change line, in `org-log-note-headings' layout."""
    s, f = f'"{state}"', (f'"{frm}"' if frm else "")
    return f"- State {s:<12} from {f:<12} {inat(when)}"

def work_log(rng, finish_day, spent_min, sessions, final_state):
    """State transitions for a task worked in SESSIONS totalling SPENT_MIN.

    Returns (STATE, DATETIME) events ascending.  Sessions are separated by a
    pause back to TODO, because a second PROG interval can only exist if the
    first was closed -- time spent is the sum of the closed PROG spans, which
    is exactly what `org-queue-state-minutes' measures.  The kb records work
    this way rather than with CLOCK lines."""
    sessions = max(1, min(sessions, 3))
    per = max(5, spent_min // sessions)
    chunks = [min(240, per if i < sessions - 1 else
                  max(5, spent_min - per * (sessions - 1)))
              for i in range(sessions)]
    gaps = [rng.randint(1, 3) for _ in range(sessions - 1)]
    d = finish_day - dt.timedelta(days=sum(gaps))
    events = []
    for i, chunk in enumerate(chunks):
        h = rng.choice([9, 10, 11, 13, 14, 16])
        start = dt.datetime(d.year, d.month, d.day, h, rng.choice([0, 15, 30]))
        events.append(("PROG", start))
        events.append((final_state if i == len(chunks) - 1 else "TODO",
                       start + dt.timedelta(minutes=chunk)))
        if i < len(gaps):
            d = d + dt.timedelta(days=gaps[i])
    return events

def log_lines(events):
    """Render EVENTS newest-first, the order Org writes and this kb has."""
    return [state_line(s, events[i - 1][0] if i else "", t)
            for i, (s, t) in enumerate(events)][::-1]

def clock_lines(rng, start_day, est_min, n):
    """N clock entries spread over days, summing near est_min x a drift factor."""
    out, total = [], max(10, int(est_min * rng.uniform(0.7, 1.4)))
    per = max(5, total // n)
    for i in range(n):
        d = start_day + dt.timedelta(days=i * rng.randint(1, 3))
        h = rng.choice([9, 10, 11, 13, 14, 16])
        chunk = per if i < n - 1 else total - per * (n - 1)
        chunk = max(5, chunk)
        end = h * 60 + chunk
        out.append(f"CLOCK: {ina(d, f'{h:02d}:00')}--{ina(d, f'{end // 60:02d}:{end % 60:02d}')} =>  {hhmm(chunk)}")
    return out

def render_task(rng, today, spec, level, cat):
    st = spec.get("state") or rng.choices(
        ["TODO", "PROG", "WAIT", "HOLD", "IDEA", "QUES", "DONE", "NOPE"],
        weights=[52, 8, 6, 4, 8, 3, 17, 2])[0]
    prio = spec.get("prio") or rng.choice(["", "", "", "A", "B", "C"])
    eff = rng.choice(SIZE[spec["size"]]) if rng.random() < 0.86 else None
    created = today - dt.timedelta(days=rng.randint(3, 70))
    sub = spec.get("sub", [])

    sched = dead = None
    pin = spec.get("pin")
    if pin:
        kind, off = pin
        when = today + dt.timedelta(days=off)
        if kind == "sched": sched = when
        else: dead = when
        if st in ("DONE", "NOPE", "HOLD", "IDEA"): st = "TODO"
        # A commitment inside the next day or two takes the smaller half of
        # its size class, so the pinned set fits a day with room to score.
        eff = rng.choice(SIZE[spec["size"]][:2]) if off <= 1 else eff or rng.choice(SIZE[spec["size"]])
    elif spec.get("repeat"):
        sched = today + dt.timedelta(days=rng.randint(-2, 5))
    else:
        if rng.random() < 0.36:
            # Never today: what is committed on the centre day is pinned by
            # hand below, so the day's load is a decision, not a draw.
            sched = today + dt.timedelta(days=rng.choice([-3, -2, -1] + list(range(1, 29))))
        if rng.random() < 0.34:
            # Mostly ahead: a backlog where a third of the deadlines have
            # already passed reads as neglect, not as a fixture.
            off = rng.randint(-3, -1) if rng.random() < 0.15 else rng.randint(2, 40)
            dead = today + dt.timedelta(days=off)
    if st == "NEXT":
        sched = None
    if st in ("DONE", "NOPE") and not pin:
        sched = sched or today - dt.timedelta(days=rng.randint(2, 30))
        dead = dead if rng.random() < 0.4 else None

    stars = "*" * level
    cookie = f" [{sum(1 for s in sub if s[2] == 'DONE')}/{len(sub)}]" if sub else ""
    head = f"{stars} {st} " + (f"[#{prio}] " if prio else "") + spec["t"] + cookie
    tags = spec["tags"].split()
    if rng.random() < 0.45:
        tags = tags + [rng.choice(ENERGY)]
    if tags:
        head += "  :" + ":".join(tags) + ":"
    L = [head]

    plan = []
    if sched:
        plan.append(f"SCHEDULED: {act(sched, rep=spec.get('repeat'))}")
    if dead:
        # A warning period on some deadlines exercises agenda lead time.
        warn = " -5d" if rng.random() < 0.25 else None
        plan.append(f"DEADLINE: {act(dead)[:-1]}{warn or ''}>")
    plan_idx = None
    if plan:
        L.append(" ".join(plan))
        plan_idx = len(L) - 1

    P = [":PROPERTIES:", f":ID:       {oid(rng)}", f":CREATED:  {ina(created)}"]
    if eff: P.append(f":Effort:   {eff}")
    # IMPACT is optional by design -- unset scores as neutral -- so most
    # entries carry one and a deliberate minority do not.
    if rng.random() < 0.62:
        P.append(f":IMPACT:   {rng.choices([1,2,3,4,5], weights=[8,18,34,26,14])[0]}")
    if dead and rng.random() < 0.38:
        P.append(":DEADLINE_TYPE: soft")
    if st in ("WAIT", "QUES") and rng.random() < 0.7:
        P.append(f":WAITING_ON: {rng.choice(WAITING)}")
    if st in ("HOLD", "IDEA") and rng.random() < 0.45:
        P.append(f":REVIEW_ON: {ina(today + dt.timedelta(days=rng.randint(-20, 60)))}")
    # The still-worth-it counters (G7): how often the Parked view and the
    # review pack have shown a parked item without it being pulled, and
    # when it was last kept.  A few are at the dismissal threshold.
    if st in ("HOLD", "IDEA") and rng.random() < 0.6:
        P.append(f":SURFACED: {rng.choices([1, 2, 3, 4], weights=[4, 3, 2, 1])[0]}")
        if rng.random() < 0.3:
            P.append(f":KEPT:     {ina(today - dt.timedelta(days=rng.randint(10, 80)))}")
    if spec.get("blocked"): P.append(f":BLOCKED_BY: {oid(rng)}")
    if spec.get("mission"): P.append(f":MISSION:  {spec['mission']}")
    if spec.get("repeat") and st == "DONE":
        P.append(f":LAST_REPEAT: {ina(today - dt.timedelta(days=3))}")
    P.append(":END:")
    L += P

    log = []
    if st in ("DONE", "NOPE"):
        fin = today - dt.timedelta(days=rng.randint(1, 25))
        # Actual time drifts from the estimate; that drift is the signal
        # `org-queue' calibration exists to measure.
        spent = int((mins(eff) if eff else 45) * rng.uniform(0.7, 1.4))
        events = work_log(rng, fin, spent, rng.randint(1, 3), st)
        # CREATED is drawn independently of the finish date, so pull it back
        # behind the first transition -- a task created after it was worked
        # on makes every age and lead-time calculation nonsense.
        first = events[0][1].date()
        if created >= first:
            created = first - dt.timedelta(days=rng.randint(1, 30))
            # P was copied into L above, so the line has to be rewritten in
            # L itself -- mutating P here would change nothing.
            for i, line in enumerate(L):
                if line.startswith(":CREATED:"):
                    L[i] = f":CREATED:  {ina(created)}"
                    break
        # `org-log-done' is 'time, so anything that reached a done state has a
        # CLOSED stamp on its planning line.  It shares the timestamp of the
        # state line below because a single transition wrote both, and the
        # Review view groups on CLOSED while showing the state line's text.
        closed = f"CLOSED: {inat(events[-1][1])}"
        if plan_idx is None:
            L.insert(1, closed)          # no plan line yet: right after the heading
        else:
            L[plan_idx] = closed + " " + L[plan_idx]
        if spec.get("legacy_clock"):
            # Predates the switch to state tracking: CLOCK lines and a bare
            # DONE with nothing before it, so there is no PROG interval to
            # measure.  This is what exercises the fallback in
            # `org-queue-harvest--clocked'; without such an entry the branch
            # is dead code in the fixture.
            log += clock_lines(rng, fin - dt.timedelta(days=2),
                               mins(eff) if eff else 45, rng.randint(1, 2))
            log.append(state_line(st, "", events[-1][1]))
        else:
            log += log_lines(events)
            if st == "NOPE":             # NOPE logs a note; DONE does not
                log[0] = log[0] + " \\\\"
                log.insert(1, f"  {rng.choice(NOPE_NOTES)}")
    elif st == "PROG":
        began = today - dt.timedelta(days=rng.randint(1, 8))
        # Still running: earlier sessions are closed and the last PROG is
        # open, so `org-queue-state-intervals' reports it with :open t.
        spent = int((mins(eff) if eff else 45) * rng.uniform(0.2, 0.7))
        events = work_log(rng, began, spent, rng.randint(1, 2), "TODO")
        events.append(("PROG",
                       dt.datetime(today.year, today.month, today.day,
                                   rng.choice([9, 10, 11, 13, 14]), 0)
                       - dt.timedelta(days=rng.randint(0, 2))))
        log += log_lines(events)
    elif st == "WAIT":
        w = today - dt.timedelta(days=rng.randint(2, 18))
        log.append(f'- State "WAIT"       from "TODO"       {ina(w, "11:20")} \\\\')
        log.append(f'  {rng.choice(WAIT_NOTES)}')
    elif st == "HOLD":
        h = today - dt.timedelta(days=rng.randint(5, 30))
        log.append(f'- State "HOLD"       from "TODO"       {ina(h, "16:40")} \\\\')
        log.append(f'  {rng.choice(HOLD_NOTES)}')
    if sched and rng.random() < 0.22:
        log.append(f'- Rescheduled from "{ina(sched - dt.timedelta(days=7))}" on {ina(today - dt.timedelta(days=rng.randint(1, 6)), "08:55")}')
    if dead and rng.random() < 0.18:
        log.append(f'- New deadline from "{ina(dead - dt.timedelta(days=10))}" on {ina(today - dt.timedelta(days=rng.randint(1, 9)), "12:30")}')
    if log: L += [":LOGBOOK:"] + log + [":END:"]

    if spec.get("body"): L += ["", spec["body"]]
    if rng.random() < 0.18 and not sub:
        L += ["", "- [X] first pass", "- [ ] second pass"]
    L.append("")

    for stitle, seff, sst in sub:
        L.append(f"{'*' * (level + 1)} {sst} {stitle}")
        shead_idx = len(L) - 1
        L += [":PROPERTIES:", f":ID:       {oid(rng)}", f":Effort:   {seff}", ":END:"]
        if sst == "DONE":
            f2 = today - dt.timedelta(days=rng.randint(1, 20))
            ev = work_log(rng, f2, int(mins(seff) * rng.uniform(0.7, 1.4)), 1, "DONE")
            L.insert(shead_idx + 1, f"CLOSED: {inat(ev[-1][1])}")
            L += [":LOGBOOK:"] + log_lines(ev) + [":END:"]
        L.append("")
    return L

def render_events(rng, today):
    L = ["#+TITLE: Appointments and fixed commitments", "#+CATEGORY: cal",
         f"#+PROPERTY: Effort_ALL {EFFORT_ALL}", f"#+COLUMNS: {COLUMNS}", ""]
    for ev in EVENTS:
        name, tags, off, start, end, rep = ev[:6]
        span = ev[6] if len(ev) > 6 else None
        d = today + dt.timedelta(days=off)
        st = "DONE" if off < 0 else "TODO"
        L.append(f"* {st} {name}  :" + ":".join(tags.split()) + ":")
        if st == "DONE":
            L.append(f"CLOSED: {ina(d, end if (start and end) else '18:00')}")
        # Drawer FIRST: a bare active timestamp is body text, not a planning
        # line, so a drawer placed after it is no longer a property drawer at
        # all and Org silently ignores every property in it.
        L += [":PROPERTIES:", f":ID:       {oid(rng)}",
              f":CREATED:  {ina(today - dt.timedelta(days=rng.randint(5, 50)))}"]
        if start and end:
            L.append(f":Effort:   {hhmm(mins(end) - mins(start))}")
        L.append(":END:")
        if span:                                   # multi-day event
            L.append(f"{act(d)}--{act(d + dt.timedelta(days=span))}")
        elif start:                                # timed range
            L.append(f"{act(d, f'{start}-{end}', rep)}")
        else:                                      # all-day
            L.append(f"{act(d, rep=rep)}")
        L.append("")
    return L

# Habits: time already decided, on a repeating pattern, that the planner
# subtracts from the day rather than plans.  STYLE=habit is the discriminator;
# HABIT_DAYS the weekday set ("except Sundays").
HABITS = [
 ("Lift weights",     "body",         "1:00", "Mon Tue Wed Thu Fri Sat"),
 ("Bike",             "body",         "0:45", "Mon Tue Wed Thu Fri"),
 ("Clean apartment",  "housekeeping", "0:20", None),
 ("Read",             "reading",      "1:00", None),
 ("Laundry",          "housekeeping", "0:30", "Sat"),
]

# Agent chains (G16): one in flight with a Prompt sub-heading and its
# session, one that landed this morning and waits for review, one that
# asked a question.  Their LOGBOOKs hold the kick and the landing.
def render_chains(rng, today):
    def stamp(d, hhmm): return ina(d, hhmm)
    y = today - dt.timedelta(days=1)
    L = []
    L += [f"* AGENT Port the ingestion retries to the new client  :@deep:",
          ":PROPERTIES:", f":ID:       {oid(rng)}", f":CREATED:  {ina(today - dt.timedelta(days=6))}",
          ":Effort:   1:00", ":AGENT_SESSION: 6f1c2a4e-0000-4000-8000-000000000001",
          ":AGENT_REPO: ~/source_code/information-retrieval-service", ":END:",
          ":LOGBOOK:",
          f'- State "AGENT"      from "PROG"       {stamp(today, "09:05")}',
          f'- State "PROG"       from "TODO"       {stamp(today, "08:40")}',
          ":END:",
          "Notes: the old client swallowed 429s; see the outage postmortem.",
          "** Prompt",
          "In ~/source_code/information-retrieval-service, replace the retry loop in",
          "ingest/client.py with the new backoff client; keep the tests green.", ""]
    L += [f"* NEXT Write the migration for the reranker cache  :@deep:",
          ":PROPERTIES:", f":ID:       {oid(rng)}", f":CREATED:  {ina(today - dt.timedelta(days=4))}",
          ":Effort:   0:40", ":AGENT_SESSION: 6f1c2a4e-0000-4000-8000-000000000002", ":END:",
          ":LOGBOOK:",
          f'- State "NEXT"       from "AGENT"      {stamp(today, "07:50")}',
          f'- State "AGENT"      from "PROG"       {stamp(y, "22:10")}',
          f'- State "PROG"       from "TODO"       {stamp(y, "21:45")}',
          ":END:",
          "Add an alembic migration that adds the rerank_cache table; run the tests.", ""]
    L += [f"* QUES Move the CLIP index build off the request path  :@deep:",
          ":PROPERTIES:", f":ID:       {oid(rng)}", f":CREATED:  {ina(today - dt.timedelta(days=3))}",
          ":Effort:   1:00", ":AGENT_SESSION: 6f1c2a4e-0000-4000-8000-000000000003", ":END:",
          ":LOGBOOK:",
          f'- State "QUES"       from "AGENT"      {stamp(today, "09:30")}',
          f'- State "AGENT"      from "PROG"       {stamp(today, "09:12")}',
          f'- State "PROG"       from "TODO"       {stamp(today, "09:00")}',
          ":END:",
          "Build the CLIP index in a background job.",
          "Agent asks: should the job run under the existing scheduler or a new one?", ""]
    return L

def render_routine(rng, today):
    L = ["#+TITLE: Routine", "#+CATEGORY: routine",
         f"#+PROPERTY: Effort_ALL {EFFORT_ALL}", f"#+COLUMNS: {COLUMNS}",
         "#+FILETAGS: :routine:", ""]
    for name, tag, eff, days in HABITS:
        L.append(f"* TODO {name}  :{tag}:")
        L.append(f"SCHEDULED: {act(today, rep='.+1d')}")
        L += [":PROPERTIES:", f":ID:       {oid(rng)}", ":STYLE:    habit",
              f":Effort:   {eff}",
              f":CREATED:  {ina(today - dt.timedelta(days=rng.randint(30, 200)))}"]
        if days: L.append(f":HABIT_DAYS: {days}")
        L += [":END:"]
        # Ticks (habits phase 2): three weeks of DONEs with a miss or two,
        # so the strength score and org-habit's graph have something to
        # read.  A tick is the DONE transition the repeater rolls on.
        allowed = set(days.split()) if days else None
        L.append(":LOGBOOK:")
        for back in range(21, 0, -1):
            d = today - dt.timedelta(days=back)
            if allowed and d.strftime("%a") not in allowed: continue
            if rng.random() < 0.15: continue          # a miss
            L.append(f'- State "DONE"       from "TODO"       {ina(d, "07:05")}')
        L += [":END:", ""]
    return L

def build(rng, today):
    out = {}
    for fname, (cat, title, specs) in FILES.items():
        L = [f"#+TITLE: {title}", f"#+CATEGORY: {cat}",
             f"#+PROPERTY: Effort_ALL {EFFORT_ALL}", f"#+COLUMNS: {COLUMNS}",
             "#+FILETAGS: :" + cat + ":", ""]
        for spec in specs:
            L += render_task(rng, today, spec, 1, cat)
        out[f"(todo) {fname}.org"] = "\n".join(L) + "\n"
    out["(todo) work.org"] += "\n".join(render_chains(rng, today)) + "\n"
    out["(todo) calendar.org"] = "\n".join(render_events(rng, today)) + "\n"
    out["(todo) routine.org"] = "\n".join(render_routine(rng, today)) + "\n"
    return out

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--today", default=dt.date.today().isoformat())
    ap.add_argument("--seed", type=int, default=20260908)
    a = ap.parse_args()
    today = dt.date.fromisoformat(a.today)
    rng = random.Random(a.seed)
    d = pathlib.Path(__file__).parent / "todo"
    d.mkdir(parents=True, exist_ok=True)
    committed = []
    for name, text in build(rng, today).items():
        (d / name).write_text(text)
        print(f"  {name:28} {text.count(chr(10) + '* ') + 1:3} top-level")
        # Self-check: what the centre day is committed to, before calibration.
        iso = today.isoformat()
        for block in text.split("\n* ")[1:]:
            head, _, rest = block.partition("\n")
            if head.startswith(("DONE", "NOPE", "HOLD", "IDEA")): continue
            if ":STYLE:    habit" in rest: continue      # reserved, not committed
            dead = re.search(r"DEADLINE: <(\d{4}-\d\d-\d\d)", rest)
            hit = (head.startswith("NEXT")
                   or f"SCHEDULED: <{iso}" in rest
                   or (dead and dead[1] <= iso)          # overdue counts too
                   or f"<{iso} " in rest)                 # appointment today
            # Repeaters that roll onto today are not simulated here.
            if hit:
                m = re.search(r":Effort:\s+(\d+):(\d+)", rest)
                committed.append((head.split("  :")[0], int(m[1]) * 60 + int(m[2]) if m else 30))
    total = sum(m for _, m in committed)
    print(f"\ncommitted on {today}: {len(committed)} entries, {total // 60}:{total % 60:02d} raw")
    for h, m in committed: print(f"  {m // 60}:{m % 60:02d}  {h}")
