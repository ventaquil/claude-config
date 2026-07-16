---
name: decide
description: >-
  Structured decision-making for design, architecture, library, or approach choices. Use when user asks
  "which/how should I", "A vs B", "what's the best way to", or when nontrivial task has several viable approaches
  and picking one shapes everything after. Genuinely distinct options, steelman each, commit to one recommendation.
---

# Decide — options, steelmen, one recommendation

Prevents: one idea dressed as three ("do X, do X with flag, do X later"); survey without committing; deciding from memory instead of codebase.

## 1. Pin decision + criteria

- Decision in one sentence + what it is NOT about (scope fence).
- Criteria that matter HERE, ranked — e.g. correctness, resulting-code simplicity, migration cost, maintenance burden, performance, team familiarity. Name dominant criterion + why. Generic criteria list → generic decision.

## 2. Ground options in evidence, not memory

- Before comparing, check reality: grep codebase for how similar problems already solved, check actual dependency versions, read specific APIs involved. Recommendation on misremembered API = worthless.
- External libraries / fast-moving tools → verify current state (docs, changelog, web), not training-data recall.

## 3. Generate 2–4 genuinely distinct options

- Options differ in kind, not degree — different architectures, different layers; "don't do this at all / solve underlying problem instead" often legitimate.
- No strawmen. Each option: steelman — strongest honest advocate case, including where it beats eventual recommendation.
- Each option: sharpest edge — scenario where choosing it most likely regretted.

## 4. Score and commit

- Compare against ranked criteria, aligned table if helps. Step-2 evidence beats intuition; mark judgment-call cells.
- Commit: exactly ONE recommendation + why it wins on dominant criteria. Survey without recommendation = hard part pushed back onto user — the job being skipped.
- State flip condition ("if X true → choose B instead") — honest uncertainty form, better than hedged recommendation.

## 5. Proportionate

Small decision → short answer: two options, three sentences each, one recommendation. Full apparatus only for expensive-to-reverse decisions. Never pad obvious decision — clear winner → say immediately, justify briefly.
