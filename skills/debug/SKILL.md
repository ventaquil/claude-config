---
name: debug
description: >-
  Evidence-driven root-cause debugging. Use when investigating any bug, failure, crash, flaky test, wrong output,
  regression, or unexplained behavior — BEFORE proposing or applying any fix. Reproduce first, falsify hypotheses,
  fix root cause (not symptom), prove fix with test.
---

# Root-cause debugging

Goal never "make error go away". Goal: understand exactly why system misbehaves, fix that cause, prove fix. Fix without understanding = new bug with better timing.

## Phase 1 — Reproduce before anything

- Reliable repro before reading any "suspect" code. Repro = ground truth for hypotheses + later proof fix works. Minimize: smallest input, fewest steps, one command.
- Cannot repro (prod-only, race, missing data) → say so explicitly, switch to forensic mode: logs, traces, timestamps, working-vs-broken environment diffs. No pretend certainty.
- Capture exact error verbatim (full stack trace, exit code, log lines). No paraphrasing errors from memory.

## Phase 2 — Observe actual system

- Read real code path that produced error — stack-trace top down, not file user happened to mention. Follow data through layers; find where reality first diverges from expectation.
- Check recent history: `git log -p` on involved files, dependency bumps, config changes. Most regressions shipped, not spontaneous.
- Targeted instrumentation (prints/logs/debugger) at boundary where good state becomes bad; binary-search that boundary. One measurement beats ten speculations.

## Phase 3 — Hypothesize, then try to kill hypothesis

- Write hypothesis, one sentence: "X fails because Y." Design cheapest observation that would DISPROVE it — run that first. Confirmation-only hypothesis = guess wearing lab coat.
- One variable at a time. Touched three things and works → unknown which mattered; revert, reapply singly.
- Symptom pattern-matching familiar failure may have different cause here. Verify against this codebase's actual behavior, not memory of similar bugs.
- After 2–3 failed hypotheses: stop, widen. Question layer (bug even in this component?), question untested assumption (env, versions, caching, stale build artifacts, test pollution).

## Phase 4 — Fix cause

- Fix where invariant breaks, not where error surfaces. Null-check at crash site while real bug = upstream data corruption → symptom-painting.
- Fix minimal, separate from cleanup. Investigation revealed unrelated problems → report, no fixing in same change.
- Hunt sibling bugs: same mistake class in copy-pasted/parallel code. Grep pattern once root cause understood.

## Phase 5 — Prove

- Re-run exact Phase-1 repro, show passing. Where practical: encode repro as regression test failing without fix, passing with — run both ways, prove test actually bites.
- Run surrounding suite; check fix broke nothing.

## Report

Root cause one sentence (mechanism, not vibes); how confirmed; what fix changes; how proven; found-but-left-unfixed. Distinguish "verified by running X" from "inferred, not executed".
