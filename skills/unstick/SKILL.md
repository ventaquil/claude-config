---
name: unstick
description: >-
  Recover from thrashing. Use after 2–3 failed attempts at same fix, when edits cycle variations of one idea, when
  each fix surfaces new error, when re-running same command hoping for different result, or when progress stalled —
  stop, re-ground on verified facts, change strategy instead of iterating harder.
---

# Unstick — stop digging, re-ground, change strategy

Thrashing looks like effort, is opposite: each blind attempt adds working-tree noise + false memories to investigation. Exit never "same idea slightly harder".

## 1. Stop and stabilize

- Stop editing. Speculative changes accumulated → `git stash` or revert to last known-good. Debugging atop own failed experiments = chasing two bugs at once.
- Write down ORIGINAL goal, one-two sentences, user's words. Thrashing drifts: last three attempts may solve subproblem that no longer matters.

## 2. Separate verified from assumed

Two explicit lists:

- **Verified**: facts observed this session — outputs read, tests run, code actually opened. Each with how.
- **Assumed**: everything else treated as true — "config is loaded", "this function is called", "build picked up my change", "test runs this code path", "environment matches".

Bug in approach almost always in second list. Pick assumption which, if false, explains all failed attempts — test directly. Classic unexamined assumptions: stale build/cache, editing file that isn't the one executed, wrong environment/version, test fixture masking behavior, error message describing downstream symptom not fault.

## 3. Change strategy, not parameters

- Enumerate three approaches DIFFERENT IN KIND from current — different layer, different tool, opposite direction. Kind-changes: stop reading code, instrument instead; stop fixing forward, bisect history instead (`git bisect`, dependency diffs); shrink to minimal repro in scratch file; delete suspect abstraction, inline it, see actual behavior.
- Layer question explicit: problem even in component being edited? Repeated failure at one layer = evidence fault lives elsewhere.

## 4. Know when to surface

One full pass, no traction → honest move = findings report, not attempt #7: what tried, what each attempt ruled out, verified/assumed lists, most promising untested hypothesis. Precise stuck-investigation account genuinely useful; seventh blind patch not. Never degrade into deleting failing test, silencing error, claiming partial success to escape loop.
