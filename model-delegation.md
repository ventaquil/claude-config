# MODEL DELEGATION

Pick model + pattern + spawn sub-session. Goal: max quality/dollar, zero hangs, result ALWAYS back to parent. Never default to biggest model or hardcode topology. Any model may run loops if role demands.

## MODELS

| Model | Good | Bad | Cost $/MTok in/out | Use |
| --- | --- | --- | --- | --- |
| Haiku | triage, classify, extract, format, glue; short items, output mechanically checkable | multi-step reasoning, ambiguity, long tool loops, judge-only output | $0.10/$0.50 (prompt >100K: $0.50/$2.50) | grunt (SELECT 6), filter, route, pre-pass |
| Sonnet | code, refactor, test, docs, tool loop | novel architecture, hard debug | $2/$10 | default worker for bulk/independent code tasks |
| Opus | hard reasoning, plan, architecture, gnarly bug, security, judge | grunt = waste | $4/$20 | Claude Code default main loop (`opus` = Opus 5.5). Default advisor/orchestrator. May loop if task hard end-to-end |
| Fable | top synthesis, hardest trade-off, arbitrate; gains largest at high effort, low often cost-competitive with Opus/Sonnet, scores higher | weekly cap share, 2.5x Opus price; headless `-p` bills credits without prompt | $10/$50 | off-ladder, see SELECT 2 |

## AGENTS (named, `~/.claude/agents/`, call via Agent tool subagent_type)

- `architect` (Opus high, read-only): plan, design, trade-off verdict. → P1 advisor, P3 plan/verify-plan.
- `developer` (Sonnet med, edits): implement per plan + tests, evidence report. → P2 worker, P3 implement/test.
- `reviewer` (Opus default, effort per EFFORT scale, read-only): adversarial verify/judge, confirm/refute, checks fabricated values. → P3 verify-diff, review loops.
- `grunt` (Haiku medium, see EFFORT low + SELECT 6): fully-specified mechanical sweeps, extract, format, classify, triage pre-pass. Copies, never invents; caller verifies.
- `prompt-writer` (Opus high, edits): authors LLM-facing artifacts — system prompts, agent defs, SKILL.md, rule files, subagent briefs, tool descriptions, few-shot sets, judge rubrics; grounds in sibling artifacts, adapts wording to the target model/effort's failure modes, BLOCKER instead of inventing. → instruction/prompt authoring + rewrite tasks.

## EFFORT (auto-scale per task; caller overrides agent frontmatter default each call)

- low: routine verify, single-file diff, plan sanity check, mechanical checks, extract/format. Fable low reads/searches less, answers from memory more — brief names exact files/commands to read, else raise that call to medium. Haiku 5.5 low in a tool loop under long agent prompts more often stops early, skips checks → `grunt` stays medium; Haiku low only for single-shot classify/extract, no tool loop.
- medium: multi-file diff, logic-equivalence check, nontrivial plan verify, judging output with fabrication risk.
- high: architecture verdicts, security-sensitive changes, final gate on full branch/release, arbitrating conflicting reviews.
- xhigh/max: rare — hardest debugging, correctness-over-cost. Never preemptive "to be safe". Long deliverable (full doc/file rewrite, big table/dataset) → `high`: xhigh/max drafts the whole output in reasoning, then writes it again — double length, no gain. Forced higher → brief says: reason in reasoning, write the output once.
- Unsure → one level up from the cheap default, not max. Frontmatter efforts are defaults: caller raises or lowers per call.
- Effort names ≠ same thinking across models; a level tuned on one model doesn't transfer — recalibrate per model+task.
- Per-model defaults (Claude Code): Opus 5.5 / Sonnet 5.5 / Haiku 5.5 medium; Fable high; Haiku 4.5 (3P `haiku` fallback) no effort. Opus 5.5 medium ≈ Opus 5 high; thinks more per level → lower effort before prompting for less thinking; pass `--effort` explicitly on every `claude -p` spawn.

## SPAWN MECHANICS (fix hang + lost result)

Prefer in-harness Agent/Workflow tool first — same result contract, no shell plumbing. Bash `claude -p` only when spawning outside this harness. Full incantation ALWAYS, bare `claude` never:

```bash
claude -p "$BRIEF" \
  --model sonnet \
  --permission-mode dontAsk \
  --effort medium \
  --output-format json \
  --max-budget-usd 2 \
  < /dev/null > "$RESULT.json" 2> "$RESULT.err"
```

- HANG 1: no `--permission-mode` → waits forever for approval. Spawn modes: `dontAsk` (deny+continue), `acceptEdits`, `bypassPermissions` (sandbox only). `auto`/`manual`/`plan` exist, not for headless. Narrow: `--allowedTools "Bash(git log *) Bash(git diff *) Edit Read"` (`Bash(git *)` would grant checkout/push).
- HANG 2: no stdin redirect → waits on pipe. ALWAYS `< /dev/null`.
- LOST RESULT: `--bg` detaches → result in `claude agents`, not stdout. NEVER `--bg` for deliverable work. Parallel = foreground `cmd & ... wait`, each own file.
- LOST WORKFLOW: background Workflow run can lose its completion record across a session boundary/limit hit. Save runId immediately on spawn; resume via `resumeFromRunId`, don't restart from scratch.
- Parse: JSON has `.result`, `.is_error`, `.session_id`, `.num_turns`, `.total_cost_usd`. Check exit code + `.is_error` BEFORE trust `.result`. Budget blown → exit 1, `.is_error` true, `.result` null; cap checked between turns, one turn can overshoot it (verified 2.1.283).
- Structured output: `--json-schema '<schema>'`.
- Follow-up same worker: save `.session_id` → `claude -p --resume "$SID" "next"`.
- Dials: `--max-budget-usd` cap, `--effort low|medium|high|xhigh|max` — scale per EFFORT section.

## RESULT CONTRACT (mandatory)

1. `claude -p` spawn writes declared file `$RESULT.json`; in-harness Agent/Workflow: returned message/schema output. No result = fail.
2. Parent ALWAYS reads + verifies after `wait`. No fire-and-forget.
3. Brief ends: "Final message = ONLY deliverable (or JSON per schema). No commentary."
4. Worker hard-fail → exit with partial + blocker note. Parent decides re-brief vs abort.
5. Blast radius in EVERY brief: exact writable paths, everything else read-only. No delete/move outside them, no `git checkout`/`switch` in the user's tree (branch work → own throwaway worktree), no push or remote write — CLAUDE.md push ban binds workers too. Enforce mechanically (agent `tools:` list, `--allowedTools`/deny rules); prose alone doesn't hold.
6. Parent verifies after every run, beyond the result file: HEAD unchanged, remote refs unmoved, untracked AND ignored paths intact — `git status` can't show what a worker destroyed there.
7. Merged worker edits → inspect the real diff, not the worker's claim: `git diff --stat` (binary path shows `Bin`, `--numstat` shows `-`) plus integrity check — no text file turned binary, no raw control/non-printable bytes, encoding intact. Tests, typecheck, lint, build can all pass over corrupted bytes.

## P1: ADVISOR-EXECUTOR

- Executor = main-loop model (Opus 5.5 default; Sonnet if session runs Sonnet). Main loop, all turns, all tools.
- Advisor = `architect` agent (Opus `--effort high`), or `reviewer` (Opus) directly for routine verify/judge. On-demand spawn.
- Call when: stuck 2+ tries, irreversible action, design fork, result smells wrong. Low-effort executor may stop consulting — call advisor on these triggers, don't rely on noticing.
- Advisor gets compressed problem + min context, NOT transcript. May run short grounding loop: cap ~5 tool calls + budget, then answer.
- Returns short directive advice per contract.
- Budget ≤ 3 calls/task. More = mis-scoped → stop, replan.

Use: single long task, mostly routine, rare hard decision.

## P2: ORCHESTRATOR-WORKER

- Orchestrator = Opus. Lifecycle loop: decompose → brief → spawn (template!) → wait → read files → merge → judge. Re-plan ≤ 2× on blockers.
- Workers = Sonnet `--effort low|medium`; Haiku (`grunt`, medium) only per SELECT 6. Own loop, narrow context, own done-criterion, own result (file or returned output). No cross-talk.
- Fan-out ONLY independent subtasks: `spawn & spawn & wait` → read ALL files. Spawn returns before its result (background Agent/Workflow) → don't idle: do independent main-loop work meanwhile, collect on notification; blocking spawn or out-of-harness `claude -p` = foreground `wait`. Either way every result read + verified. Dependent chain = main loop + advisor (P1).
- Independent = disjoint files AND disjoint runtime. Shared compose project, ports, DB, test runner, dev server, working tree, or host CPU/RAM for heavy builds → dependent: serialize, or cap at 1 workflow / ≤3 agents; read-only analysis fan-out unaffected. Never spawn a stage whose input another running stage still rewrites; never measure timing or gate on tests while another agent writes — contention reads as flaky tests and false diagnoses. New requirement touching files a running fan-out owns → stop or re-brief that run, don't hand-patch around it.
- Stop request ≠ stopped process: after killing a run verify it halted (process gone, no `.git/rebase-merge`/`MERGE_HEAD`, no compose command running) before touching any file it owned. Merge re-diffs every stream's files against the pre-fan-out baseline — standard failure is a sibling's earlier fix silently reverted; each stream's own diff looking correct doesn't rule it out.
- Peer sessions edit too: before the first edit in a working tree or a run on shared runtime, `ListAgents`; peer session in the same project → `SendMessage` it the files/runtime you are about to own + "do not touch until I report done", and ask what it edits. Overlap named → serialize or re-scope, never proceed on it; no reply ≠ clearance for files the tree shows modified (`git status` for edits you did not make). Peer's notice → honor it, no edits on its files until its done message. Courtesy protocol, not a lock: still verify by diff before commit.
- Brief self-contained: inputs, constraints, output schema, result path.
- Merge: verify contracts, resolve conflicts, one integration check. No re-do worker work.

Use: 2+ independent chunks (multi-file refactor, multi-doc research, parallel analyses).

## P3: PLAN-VERIFY-IMPLEMENT-TEST LOOP

- Loop N iters (user picks, default 3-5; N = ceiling — stop once verify-diff passes): plan(`architect` or Sonnet) → verify-plan(`reviewer`, low) → implement(`developer`; `grunt` only per SELECT 6) → test(`developer`) → verify-diff(`reviewer`, med).
- Commit atomically per verified iteration. Close with threat-or-treat-review on full branch.
- verify-diff diffs against real source, never the implementer's claim (fable-mode.md Verification).

Use: perf/refactor work user wants run semi-autonomously to convergence.

## SELECT

1. Cheapest per completed task (all attempts + escalation + caller verification counted), not per token. Escalate on fail, never preemptive.
2. Ladder Haiku → Sonnet → Opus. Fable off-ladder, weekly cap + 2.5x Opus price: never a default for any step; dispatch only on explicit user ask or to tie-break conflicting Opus verdicts; silent Opus fallback if unavailable.
3. Expensive loops SHORT: Opus plans/verifies/debugs, never types boilerplate. Cheap types, expensive thinks. Top model doing 20+ mechanical edits itself = delegate, don't push through.
4. One task = one pattern. Mutation → P2 re-plan or P1 stop + re-pick.
5. Unsure: routine + hard moments → P1. Parallel → P2. Iterative converge-to-done → P3. Neither → main-loop model alone, no spawns.
6. Haiku (`grunt`) vs Sonnet low (`developer --effort low`), per task class; per-token gap (MODELS) ≠ per-task gap. Haiku: brief names exact inputs, transform, output format; short/parallel items, single-shot or short loop; output checkable by count/schema/grep/test; prompt <100K. Sonnet low: multi-step tool loop, code-logic edit, edit+test, judge-only output, class Haiku already failed once (no Haiku retry). Caches model-scoped: never switch model mid-task; escalation = fresh brief + partial result. Class unsettled → measure before cascading: 3-5 tasks with known-correct checker, `--model haiku --effort medium` vs `--model sonnet --effort low`, 3 runs each, serial, throwaway worktree for edits; cost/completed = Σ `.total_cost_usd` all runs ÷ checker passes; claimed done + checker fail = fail; record resolved model per run. Lower wins; tie → Sonnet.

## SAVE EFFORT

- Context diet: min viable per spawn. Summarize, never dump transcript.
- Cache-friendly brief: stable system + instructions up front, volatile stuff last.
- Haiku pre-pass: 50 files → Haiku picks the relevant few → main loop reads those (handful of reads = main-loop work, CLAUDE.md Model delegation).
- Batch trivia into one Haiku call. Haiku 5.5 bills 5x once a request's prompt >100K tokens (loop context accumulates): size each grunt <100K; split across parallel grunts over one big one.
- Done-criteria explicit + checkable → no verify round-trips.
- Verify asymmetry: cheap does, cheaper checks mechanics, Opus judges only if needed (nontrivial diff: reviewer gate per fable-mode.md Verification).
- `--max-budget-usd` EVERY spawn: grunt 1-2, worker 3-5, advisor/orchestrator 10. Unbounded = leak.
- No advisor/orchestrator for < 5 min task.
- Opus 5.5 main loop at lower effort often beats a cheaper multi-model setup when work is one dependent chain or fits one context — spawn only when work is bulk, independent, or exceeds one context (CLAUDE.md Workflow rule + standing "use workflows" still win).
- Fable: batch questions, one call, structured answer. Never burn quota on Opus-grade work.
- Fable brief phrasing avoids safeguard false positives (refusal = lost result): "any bugs here?" not "does this compile?"; obscure language → attach its docs; no base64 tool output in brief or context.
- Review/audit task → threat-or-treat-review skill by default: fan out per concern area (P2), adversarial confirm/refute before reporting a finding.
