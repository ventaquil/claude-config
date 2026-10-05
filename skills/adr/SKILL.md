---
name: adr
description: >-
  Create, transition, supersede, or find Architecture Decision Records. Use when user says "record/log this
  decision", "write/add an ADR", "accept/reject/deprecate ADR NNNN", "supersede ADR NNNN", "which ADR covers X",
  invokes /adr, or accepts the /adr offer at the end of /decide. Not for choosing between options — that is /decide;
  not for routine dependency bumps, local refactors, or hour-reversible choices unless the user asks.
---

# ADR — record, transition, supersede, find decisions

Read `~/.claude/rules/adr.md` first — invariants (threshold, lifecycle, immutability, no fabrication, numbering, commit placement, formatting) live there; this skill = procedure. Conflict → rule file wins.

Blocker format, every step: `BLOCKER: <section or step> — <exact question>`. Ask, never guess.

## Operations

| op | trigger | action |
| --- | --- | --- |
| new | "record/log this decision", "write/add an ADR", /adr | steps 1–8. Status `Proposed`; `Accepted` only when the user states the decision is made |
| accept | "accept ADR NNNN" | `Proposed` ADR: Status line → `Accepted`; steps 6, 8 |
| reject | "reject ADR NNNN" | `Proposed` ADR: Status line → `Rejected`; file kept; steps 6, 8 |
| deprecate | "deprecate ADR NNNN" | `Accepted` ADR: Status line → `Deprecated`; steps 6, 8 |
| supersede | "supersede ADR NNNN" | target must be `Accepted` (`Proposed` → edit it instead). New ADR via steps 1–8 with Status `Accepted (supersedes NNNN)` (NNNN = old number) + old ADR in its Links; old ADR Status line → `Superseded by MMMM` (MMMM = new number, linked to the new file) — nothing else in the old file changes; both in one change |
| find/list | "which ADR covers X", "list ADRs" | step 1, then grep the ADR dir for area keywords + Status lines; report path, number, title, status per hit. No hit → say so; never answer from memory |

Transition target missing (no file with that number) or transition not in the rule's lifecycle → refuse with the reason, name the allowed transitions.

## 1. Detect ADR dir — precedent wins

- From repo root probe in order: `adr/`, `adrs/`, `docs/adr/`, `docs/adrs/`, `docs/decisions/`, `doc/adr/`, `docs/architecture/decisions/`, plus a `.adr-dir` file (adr-tools) naming the dir.
- Several found → `BLOCKER: ADR dir — which of <list> is canonical?`
- None found → create `docs/adr/` only when the user explicitly invoked /adr or asked for an ADR; state the choice in one line. Otherwise stop and report no ADR dir.
- Before `new`: grep the dir for the area. Accepted ADR already covers this decision → switch to `supersede`, tell the user.

## 2. Template precedent

- Repo `template.md`, `0000-*.md`, existing ADRs' section shape, filename pattern, language → wins over the built-in template (named-reference rule, fable-mode.md). Existing ADRs differ → follow the highest-numbered one.
- No precedent → built-in template below.

## 3. Number + filename

- Next number = highest existing number in the dir + 1 (gaps never refilled). 4-digit zero-padded unless precedent uses another width.
- Filename `NNNN-kebab-case-title.md` (lowercase ASCII, hyphens), title = the decision statement.

## 4. Gather content — sourced only

- Content comes ONLY from the conversation and named sources (issues, MRs, docs read this session): options actually considered, reasons actually given.
- /decide output in context → map directly: criteria → Decision drivers; options + steelmen → Considered options; recommendation → Decision; sharpest edges → Consequences; flip condition → Revisit when.
- Any required section (Context, Decision drivers, Considered options, Decision, Consequences, Revisit when) without sourced content → BLOCKER question; write the file only after answers. Never invent a rationale, driver, option, pro/con, or consequence.
- Deciders: only if known. Links: only real references.

## 5. Write

- Date = today, ISO (`date +%F`). Formatting per rule file Formatting (human-facing doc, aligned tables, 120 cols).
- Target ~1 page; longer → link a design doc in Links instead of expanding.

Built-in template (trimmed MADR):

```markdown
# NNNN. <Decision as short imperative statement>

- Status: Proposed
- Date: YYYY-MM-DD
- Deciders: <names; omit line if unknown>

## Context

<Problem, forces, constraints as stated in conversation/sources.>

## Decision drivers

- <Driver, ranked when a ranking was given.>

## Considered options

### <Option name>

<One-line description.>

- Pros: <...>
- Cons: <...>

## Decision

<Chosen option and why it wins on the drivers.>

## Consequences

- Positive: <...>
- Negative: <...>

## Revisit when

<Concrete trigger that reopens this decision.>

## Links

- <Related ADRs, issues, MRs; omit section if none.>
```

One `###` block per option actually discussed — never pad with options nobody raised.

## 6. Index

- ADR dir has a hand-maintained index (`README.md` listing ADRs) → update it in the same change, matching its existing line format (status column too, on transitions).
- No index → don't create one.

## 7. No commit

- Skill never commits. Commit placement per rule file Commit placement; name the commit the ADR belongs in.

## 8. Report

Path, number, status, BLOCKERs (or "none"), index updated yes/no, and that the change is uncommitted.
