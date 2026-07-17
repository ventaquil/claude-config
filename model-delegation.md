# MODEL DELEGATION

Pick model + pattern + spawn sub-session. Goal: max quality/dollar, zero hangs, result ALWAYS back to parent. Never default to biggest model or hardcode topology. Any model may run loops if role demands.

## MODELS

| Model | Good | Bad | Cost | Use |
| --- | --- | --- | --- | --- |
| Haiku | triage, classify, extract, format, glue | multi-step reasoning, ambiguity | very low | grunt, filter, route, pre-pass |
| Sonnet | code, refactor, test, docs, tool loop | novel architecture, hard debug | low-mid | default worker/executor. 90% tasks |
| Opus | hard reasoning, plan, architecture, gnarly bug, security, judge | grunt = waste | high | default advisor/orchestrator. May loop if task hard end-to-end |
| Fable | top synthesis, hardest trade-off, arbitrate | weekly limits, disabled soon | max, rationed | Rationed but routine verify/judge step. Unavailable → silent Opus fallback |

## AGENTS (named, `~/.claude/agents/`, call via Agent tool subagent_type)

- `architect` (Opus high, read-only): plan, design, trade-off verdict. → P1 advisor, P3 plan/verify-plan.
- `developer` (Sonnet med, edits): implement per plan + tests, evidence report. → P2 worker, P3 implement/test.
- `reviewer` (Fable, effort per EFFORT scale, read-only): adversarial verify/judge, confirm/refute, checks fabricated values. → P3 verify-diff, review loops. Unavailable → re-call with model=opus.
- `grunt` (Haiku low): mechanical sweeps, extract, format, triage pre-pass. Copies, never invents; caller verifies.

## EFFORT (auto-scale per task; caller overrides agent frontmatter default each call)

- low: routine verify, single-file diff, plan sanity check, mechanical checks, extract/format.
- medium: multi-file diff, logic-equivalence check, nontrivial plan verify, judging output with fabrication risk.
- high: architecture verdicts, security-sensitive changes, final gate on full branch/release, arbitrating conflicting reviews.
- xhigh/max: rare — hardest debugging, correctness-over-cost. Never preemptive "to be safe".
- Unsure → one level up from the cheap default, not max. Frontmatter efforts are floors/defaults, not caps.

## SPAWN MECHANICS (fix hang + lost result)

Prefer in-harness Agent/Workflow tool first — same result contract, no shell plumbing. Bash `claude -p` only when spawning outside this harness. Full incantation ALWAYS, bare `claude` never:

```bash
claude -p "$BRIEF" \
  --model sonnet \
  --permission-mode dontAsk \
  --output-format json \
  --max-budget-usd 2 \
  < /dev/null > "$RESULT.json" 2> "$RESULT.err"
```

- HANG 1: no `--permission-mode` → waits forever for approval. Spawn modes: `dontAsk` (deny+continue), `acceptEdits`, `bypassPermissions` (sandbox only). `auto`/`manual`/`plan` exist, not for headless. Narrow: `--allowedTools "Bash(git *) Edit Read"`.
- HANG 2: no stdin redirect → waits on pipe. ALWAYS `< /dev/null`.
- LOST RESULT: `--bg` detaches → result in `claude agents`, not stdout. NEVER `--bg` for deliverable work. Parallel = foreground `cmd & ... wait`, each own file.
- LOST WORKFLOW: background Workflow run can lose its completion record across a session boundary/limit hit. Save runId immediately on spawn; resume via `resumeFromRunId`, don't restart from scratch.
- Parse: JSON has `.result`, `.is_error`, `.session_id`, `.num_turns`, `.total_cost_usd`. Check exit code + `.is_error` BEFORE trust `.result`. Budget blown → exit 1, `.is_error` true, `.result` null (verified 2.1.205).
- Structured output: `--json-schema '<schema>'`.
- Follow-up same worker: save `.session_id` → `claude -p --resume "$SID" "next"`.
- Dials: `--max-budget-usd` cap, `--effort low|medium|high|xhigh|max` — scale per EFFORT section.

## RESULT CONTRACT (mandatory)

1. Every spawn writes declared file `$RESULT.json`. No file = fail.
2. Parent ALWAYS reads + verifies after `wait`. No fire-and-forget.
3. Brief ends: "Final message = ONLY deliverable (or JSON per schema). No commentary."
4. Worker hard-fail → exit with partial + blocker note. Parent decides re-brief vs abort.

## P1: ADVISOR-EXECUTOR

- Executor = Sonnet. Main loop, all turns, all tools.
- Advisor = `architect` agent (Opus `--effort high`), or `reviewer` (Fable) directly for routine verify/judge. On-demand spawn.
- Call when: stuck 2+ tries, irreversible action, design fork, result smells wrong.
- Advisor gets compressed problem + min context, NOT transcript. May run short grounding loop: cap ~5 tool calls + budget, then answer.
- Returns short directive advice per contract.
- Budget ≤ 3 calls/task. More = mis-scoped → stop, replan.

Use: single long task, mostly routine, rare hard decision.

## P2: ORCHESTRATOR-WORKER

- Orchestrator = Opus. Lifecycle loop: decompose → brief → spawn (template!) → wait → read files → merge → judge. Re-plan ≤ 2× on blockers.
- Workers = Sonnet `--effort low|medium` (Haiku if trivial). Own loop, narrow context, own done-criterion, own result file. No cross-talk.
- Fan-out ONLY independent subtasks: `spawn & spawn & wait` → read ALL files. Dependent chain = single Sonnet + advisor.
- Brief self-contained: inputs, constraints, output schema, result path.
- Merge: verify contracts, resolve conflicts, one integration check. No re-do worker work.

Use: 2+ independent chunks (multi-file refactor, multi-doc research, parallel analyses).

## P3: PLAN-VERIFY-IMPLEMENT-TEST LOOP

- Loop N iters (user picks, default 3-5): plan(`architect` or Sonnet) → verify-plan(`reviewer`, low) → implement(`developer`; `grunt` only if trivial) → test(`developer`) → verify-diff(`reviewer`, med).
- Commit atomically per verified iteration. Close with threat-or-treat-review on full branch.
- Cheap implementer (Haiku esp.) can fabricate values (invented version/config not in repo) — verify-diff step must diff against real source, not trust implementer's claim.

Use: perf/refactor work user wants run semi-autonomously to convergence.

## SELECT

1. Cheapest plausible first. Escalate on fail, never preemptive.
2. Ladder Haiku → Sonnet → Opus. Fable off-ladder: direct dispatch for routine verify/judge, silent Opus fallback if unavailable.
3. Expensive loops SHORT: Opus plans/verifies/debugs, never types boilerplate. Cheap types, expensive thinks. Top model doing 20+ mechanical edits itself = delegate, don't push through.
4. One task = one pattern. Mutation → P2 re-plan or P1 stop + re-pick.
5. Unsure: routine + hard moments → P1. Parallel → P2. Iterative converge-to-done → P3. Neither → plain Sonnet, no spawns.

## SAVE EFFORT

- Context diet: min viable per spawn. Summarize, never dump transcript.
- Cache-friendly brief: stable system + instructions up front, volatile stuff last.
- Haiku pre-pass: 50 files → Haiku pick 5 → Sonnet read 5.
- Batch trivia into one Haiku call.
- Done-criteria explicit + checkable → no verify round-trips.
- Verify asymmetry: cheap does, cheaper checks mechanics, Opus judges only if needed.
- `--max-budget-usd` EVERY spawn: grunt 1-2, worker 3-5, advisor/orchestrator 10. Unbounded = leak.
- No advisor/orchestrator for < 5 min task.
- Fable: batch questions, one call, structured answer. Never burn quota on Opus-grade work.
- Review/audit task → threat-or-treat-review skill by default: fan out per concern area (P2), adversarial confirm/refute before reporting a finding.
