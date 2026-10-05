---
paths:
  - "**/adr/**/*.md"
  - "**/adrs/**/*.md"
  - "**/docs/decisions/**/*.md"
  - "**/doc/adr/**/*.md"
  - "**/architecture/decisions/**/*.md"
  - "**/.adr-dir"
---
# Architecture Decision Records

Invariants for ADR files. Procedure (create, transition, supersede, find) = `/adr` skill (`~/.claude/skills/adr/SKILL.md`). Precedence: this file wins over the skill, and over CLAUDE.md "Docs follow the change" for ADR commit placement. Repo precedent (template, filename/number width, markdownlint config, doc language) wins over this file's format defaults — never over Lifecycle, Immutability, No fabrication.

## When to write one

- Write when ≥1 holds: expensive to reverse; cross-cutting (spans modules/services/teams); chose a non-obvious option over the obvious one; newcomer would ask "why is it like this?".
- Skip: routine dependency bumps, local refactors, choices reversible in an hour. Mirrors /decide step 5 proportionality.
- User explicitly asks for an ADR → write regardless of threshold.

## Status lifecycle

- `Proposed` → `Accepted` | `Rejected`. `Accepted` → `Deprecated` | `Superseded by NNNN`. Any other transition (revive Rejected/Deprecated, deprecate Proposed) → refuse, offer a new ADR instead.
- Superseding ADR status: `Accepted (supersedes NNNN)`.
- Rejected ADRs stay in the dir — the record stops re-litigating. Never delete an ADR — change its status instead.

## Immutability

- `Proposed`: body freely editable until accepted.
- `Accepted`/`Rejected`/`Deprecated`/`Superseded`: body never edited — only the Status line changes (+ `Superseded by` link to the new file). Content change = new superseding ADR. Editing the body rewrites what was approved; history of why is lost.

## No fabrication

- Context, drivers, options, pros/cons, rationale, consequences, revisit trigger: only what was actually discussed in the conversation or stated in a named source (issue, MR, design doc, /decide output). Never plausible generic filler, never placeholder text.
- Gap → `BLOCKER: <section> — <exact question>` to the user; section stays unwritten until answered.

## Numbering

- Sequential, never reused (numbers of rejected/deprecated/superseded ADRs stay taken). 4-digit zero-padded, filename `NNNN-kebab-case-title.md`, unless existing ADRs use another width/pattern — precedent wins.
- Parallel-branch collision (same number on base and branch) → the later-merged ADR renumbers to the next free number; every reference (other ADRs, links, index) updated in the same change.

## Commit placement

- ADR lands in the same commit as the first change it justifies.
- Decision needs review before implementation → ADR in its own commit, Status `Proposed`, at the start of the branch/MR; the implementing commit flips it to `Accepted`.
- Supersede = new ADR + old ADR's Status line in one commit.

## Formatting

- ADR = human-facing doc: CLAUDE.md "Claude-facing files" telegraphic/compact-table style never applies — write complete sentences. Follow CLAUDE.md Markdown (aligned table columns, 120-col limit) + user-docs formatting (no emoji, no mid-sentence hard wraps narrower than needed).
- Repo markdownlint config / existing ADR language wins over these defaults.
- Target ~1 page; longer → link a design doc from Links instead.

## Reading side

- Change to code an `Accepted` ADR covers contradicts it → stop before editing, name the ADR (path + title), propose a superseding ADR via /adr; user decides. Never silently override, never edit the old ADR to match the code.
