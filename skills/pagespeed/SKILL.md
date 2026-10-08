---
name: pagespeed
description: >-
  Web performance and Lighthouse-score optimization. Use when user mentions PageSpeed/PSI, Lighthouse, Core Web
  Vitals, FCP/LCP/CLS/INP/TBT, render-blocking resources, a low performance/accessibility/best-practices/SEO score,
  pastes a PSI report or screenshot, says the site/page is slow, or asks to "get to 100". Baseline where the user
  measured, split measurement artifacts from real issues, owner-gate trade-offs, fix per audit, prove with
  same-source before/after plus visual identity. Not for backend latency/profiling (use /debug).
---

# PageSpeed / Lighthouse optimization

Goal: real-user speed, every change proven by measurement. Score = evidence, not goal. Owner-rejected trade-off stays rejected, whatever the score.
Tool commands: Read `~/.claude/skills/pagespeed/references/recipes.md` before running any measurement.

## Roles
- Main loop: owner gates (Phase 4), decisions, briefs. Measuring loops never run in main loop → `web-perf-auditor`.
- `web-perf-auditor` (baseline, classify, snapshot, verify). Brief carries: phase(s); page paths; source to match (PSI / prod / quick tunnel / localhost); scratch dir = only writable path; pre-change snapshot dir (verify) or, when none exists, Recovery inputs (Phase 6); tunnel allowed y/n; location of the repo's header/server config (server conf, platform header file such as `_headers`, framework middleware) + Dockerfile path or `none`. Item missing → auditor returns `BLOCKER: <item>`.
- `developer` (fixes). Brief = approved Phase 3 rows + Phase 5 section of this file + owner gate decisions quoted verbatim. Sent only after the Snapshot step is done.
- `reviewer` (code check) against the plan + pre-change snapshot.
- Done needs BOTH auditor verify (Phase 6) AND reviewer verdict — on a sample site code review missed a simulated LCP regression the measuring lane caught.
- Sources disagree → main loop or `architect` arbitrates with all numbers. Auditor reports all, never picks one silently.

## Phase 1 — Baseline where the user measured
- Record source: tool (PSI / Lighthouse CLI), form factor, URL, origin (prod = public URL on its own host, no tunnel / quick tunnel = local version exposed for PSI / localhost). Per page: Perf, A11y, BP, SEO + FCP/LCP/CLS/TBT.
- User screenshot/paste → transcribe values, mark `from user screenshot`.
- PSI API without key often returns HTTP 429 → report `PSI not run (429)`, fall back to Lighthouse CLI: prod → against the same public URL; local version → localhost + quick-tunnel Lighthouse. Never write a PSI number no run this session returned.
- 5 representative pages, one per distinct page type (home, listing, longest content page, static pages). Median of 3 runs per page per source.
- Brief may lower the run count only explicitly; brief silent → 3. Lowered rows labelled `n=<runs>` (`n=1` = single run); a delta on an `n=1` row is never reported as a change.

## Phase 2 — Artifact vs real
| symptom | check | verdict |
|---|---|---|
| SEO drop on `*.trycloudflare.com` | `curl -sI <url>` shows `x-robots-tag: none`; grep the repo's header/server config (server conf, platform header file e.g. `_headers`, framework middleware) → none set it | tunnel artifact; no SEO fix; cite local Lighthouse SEO |
| render-blocking script in served HTML, absent from the repo's build output (grep), e.g. `/cdn-cgi/scripts/*/email-decode.min.js` | script observed in served HTML (`curl` the URL) and not in build output; for email-decode: HTML contains an email address (mailto or text) | injected by an edge/CDN/proxy in front of the measured origin (e.g. Cloudflare zone Email Address Obfuscation) = owner setting → Phase 4 gate, not a bug; never assume an edge without this evidence |
| lab-simulated (Lantern), observed (unthrottled), tunnel/PSI disagree | report all three per page | never merged into one verdict; arbitration per Roles |
| score differs run to run | medians of 3 | single-run delta never reported as a change; `n=1` labelling per P1 |
| insight marked unscored (PSI `Unscored` or its localized label; e.g. `network-dependency-tree-insight`, `cache-insight`) | perf `auditRefs` weight 0 (recipes Median-of-3 unscored check) | no score effect: report with its cost; any fix gated per P4; never presented as a score fix |
| web fonts (preloaded or late) in `network-dependency-tree-insight` | fonts listed are custom fonts the page uses | expected cost of custom fonts (measured on a sample site, tunnel PSI: font files on the critical path); preloading a font not needed above the fold on every page made LCP worse (recipes Variants) → report, never chase with more preloads |
| simulated LCP ~constant across every variant while observed LCP is far lower (measured on a sample site: simulated LCP constant across variants, observed far lower) | compare variant medians, simulated vs observed | Lantern modelling artifact; report it, never chase it with more variants |

Perf score = weighted metrics only; insights (incl. `render-blocking-insight`) carry weight 0 and move the score only through the metrics they affect → a fix is justified by a metric change, never by clearing an insight.

General Lighthouse guidance (not measured here): PSI field data (CrUX) and lab data are separate sources; lab results never prove a field improvement.

## Phase 3 — Plan per failing audit
- One row per failing audit: `audit id | root cause file:line | candidate fix (Phase 5) | expected metric change | gate y/n`. One fix per audit.
- Grep how the repo already does it (font file naming, header files, colour tokens) before proposing; follow that precedent.
- Needed value absent from repo or run output → `BLOCKER: <value>`, never a placeholder.

## Phase 4 — Owner gates: STOP and ask, one cost/benefit line each, before
- Removing/weakening a protection: email obfuscation, bot/WAF features, CSP directives incl. adding `style-src 'unsafe-inline'`. Offer protection-keeping alternatives first. User says "just remove it" → still give the one cost/benefit line first, then proceed. Approved removal → Phase 6 removal branch.
- Visible design change (colour, token, layout). Offer first: switch failing elements to an existing higher-contrast token; never change a shared token (also used decoratively).
- New dependency; CI / Dockerfile / header / infra file outside the task; URL/slug change.
- Cache trade-off: inlining CSS = bytes per HTML + lost cross-page cache; unhashed asset cache lifetime (`immutable` on an unhashed path = file replaced under the same name stays stale up to a year).
- Any fix for an unscored insight (P2).
- Edge/CDN/proxy dashboard, DNS, or hosting-panel settings (only when evidence shows such a layer, e.g. Cloudflare zone): never changed from code or by an agent. Owner approves → state consequences, owner applies.
- Approved → implement exactly the approved change, nothing wider. Rejected → record `rejected by owner`, never re-raise to chase the score; report names it as remaining cost.

## Snapshot — after Phase 3 rows + Phase 4 gates approved, before `developer` starts
- Owner: main loop, or `web-perf-auditor` briefed with phase `snapshot`.
- Copy every existing file the approved rows touch to `<scratch>/pre/` (repo-relative paths kept). Set uncertain → copy the whole tree minus ignored files (recipes Snapshot).
- `<scratch>/pre.new` = files the plan says it will create, one repo-relative path per line (empty file if none).
- Done: every planned existing path present under `<scratch>/pre/`; `pre.new` exists. Only then send the `developer` brief.
- Fix already applied without snapshot → Phase 6 Recovery, never a bare BLOCKER.

## Phase 5 — Fix catalog (measured on a sample site unless marked UNTESTED)
- Google Fonts (cross-origin css2 → woff2 chain; measured on a sample site: main FCP cost): self-host the exact woff2 Google serves — fetch css2 with a modern Chrome UA, download latin + latin-ext per family/style, copy `unicode-range` verbatim, keep `font-display: swap`, follow repo font file naming. Subsets: scan built HTML for non-ASCII chars (accented letters → latin-ext subset).
- Font preload: `<link rel="preload" as="font" type="font/woff2" crossorigin>` — without `crossorigin` = double fetch. Preload fonts carrying glyphs of above-the-fold text on EVERY page, latin-ext included when its glyph (a non-ASCII letter) sits above the fold on every page. Never preload fonts used only on some pages or below the fold (e.g. a style or family used only in body content) — extra preloads compete with the LCP resource. Each extra preload proven by A/B, medians of 3 (recipes Variants).
- Before reasoning which font to preload: read the LCP element from the Lighthouse JSON (recipes Median-of-3 loop) — measured on a sample site: guessed `h1` was wrong, real LCP was a styled paragraph, first misidentified as the heading.
- Measured on a sample site (Lighthouse 13.5.0 mobile, medians of 3): latin-ext preload of the font carrying an above-the-fold non-ASCII glyph lowered FCP on pages with the glyph, adopted; extra preloads of fonts not needed above the fold on every page made LCP + perf worse; no preloads clearly worst. Table: recipes Variants.
- Render-blocking site CSS: inline where the framework supports it. Cost: bytes per HTML, no cross-page cache, needs CSP `style-src 'unsafe-inline'` → Phase 4 gate. Scripts stay external unless CSP allows inline scripts.
- After self-hosting: remove third-party origins from CSP in EVERY mirrored header file; mirrors stay byte-identical; any doc describing those headers updated in the same change.
- Self-hosted font cache lifetime (`cache-insight`, unscored; measured on a sample site: self-hosted woff2 flagged for a short cache lifetime) → P4 gate. Gated fix (owner approves): route fonts through the bundler → content-hashed URLs, covered by the existing immutable hashed-asset rule; preload href = SAME hashed URL as CSS `url()` (else double fetch); separate cache rule for the old unhashed font path removed from EVERY mirrored header file + any doc describing those headers, same change. Rejected: `immutable` on unhashed paths. Steps + verify checks: recipes Stack notes.
- Contrast: failing elements → existing higher-contrast token, or opacity tweak (measured on a sample site: a small opacity increase lifted a failing element above WCAG AA 4.5:1).
- Inactive controls: `aria-disabled="true"` (WCAG 1.4.3 exempts inactive components; axe skips them).
- Identical link text, different targets: `aria-label` STARTING with the visible text (WCAG 2.5.3), e.g. `<visible link text>: <target>`.
- Every build/tool run: `DO_NOT_TRACK=1` + the framework's telemetry opt-out.

## Phase 6 — Verify, same source
- "Before" build = copy of CURRENT tree, files the fix touched restored from `<scratch>/pre/` (whole-tree snapshot → only the touched files), files listed in `<scratch>/pre.new` deleted. Never git HEAD for a file that had uncommitted changes before the task — peer sessions edit concurrently.
- Recovery (fix applied, no snapshot): scratch copy of current tree, each touched file reverted from the first available: pre-task copy → `git show HEAD:<path>` ONLY if that file had no uncommitted changes before the task (pre-task `git status`) → owner-supplied version → reconstruction from this session's diff. Report per file: before source + confidence (`high` = pre-task copy / clean HEAD / owner-supplied; `reduced` = reconstructed). No source for a file → `BLOCKER: no pre-task version of <path>`.
- Variants (A/B, regression checks): built or patched ONLY in `<scratch>/<variant>/` (copy of built output or of source), never in the repo (recipes Variants).
- Build both copies in scratch, never in the user's tree (shared `dist/` with dev server + peers). Serve each from its own temp server applying the repo's matching header/server config (headers change scores): repo ships a Dockerfile/server image → temp container `psi-<side>`; else repo's own preview/start command or a local static server in scratch, on a free port (recipes Temp serving). Never reuse/restart/stop user containers or processes.
- Both sides: same tool version, form factor, pages, run count.
- Visual identity: pixel diff 0 px outside masked intentional changes, then LOOK at crops (non-ASCII glyphs). Mobile widths 320/360/375/402/440 — below target device too (measured on a sample site: non-wrapping text overflowed at narrow widths).
- Mirror check = script output (diff/cmp of the normalized rule sets, recipes Header mirror check), never reading the files; no script output → report `mirror check not run`.
- Per-page checks (preload href == CSS `url()`, preload count, request count) run on EVERY page in the set; report passed/total (e.g. 5/5). Fewer pages checked → report `<k>/<total>`, never a pass (recipes Per-page checks).
- Every "0 found" check (pixel diff, console/CSP errors, audit items, double fetch) needs a control that fails if the check is blind: e.g. injected CSP violation → console counter fires; 1 px-shifted screenshot → comparer reports nonzero. No control run → result reported `unverified (no control)` (recipes Controls).
- Protection kept (e.g. email obfuscation) → check via real path (tunnel/prod): no plain address in raw HTML, decoded address renders, mailto works, no CSP console errors.
- Protection removal owner-approved → expectation flips: protection script absent from HTML, render-blocking audit 0 items, address plain in HTML. Report states which branch applied.
- Regression in any source → /debug. Read the LCP element from the JSON first. Cause labelled UNTESTED until the cheapest disproving check ran (variant without preloads / fewer preloads; scan above-the-fold fonts + glyphs), medians of 3, same setup. No revert before that check.
- Variant picked → re-run visual identity (masks + crops read) on the kept variant before done.
- End: every temp server you started removed. Docker path: every `psi-*` container/network/image removed, proof `docker ps -a --filter name=psi-` empty. Process path: each recorded PID gone (`ps -p <pid>` header only) + its port no longer listening (`ss -ltn`). Host cloudflared started → its PID gone + tunnel URL no longer 200 (recipes Temp serving, Tunnel).

Done when all hold: auditor verify report per source; reviewer `VERDICT`; 0 px outside masks (kept variant included); before source + confidence stated if Recovery used; mirror-check script diff empty; per-page checks k/k; every "0 found" check has a control that fired; temp-server cleanup proof (for each path used: `psi-*` list empty, or started PIDs gone + ports free) + host tunnel stopped (if used); every gate approved, rejected, or listed pending; each original ask marked done/skipped/changed. Nothing committed or pushed unasked.

## Report format
Per page, separate table per source (lab-simulated / observed / tunnel / PSI), values `before → after`:

| page | Perf | A11y | BP | SEO | FCP ms | LCP ms | CLS | TBT ms | render-blocking |
|---|---|---|---|---|---|---|---|---|---|
| `/` | <b> → <a> | <b> → <a> | <b> → <a> | <b> → <a> | <b> → <a> | <b> → <a> | <b> → <a> | <b> → <a> | <b> → <a> |

Then: Lighthouse version, form factor, run count (`n=<runs>` rows marked), source snapshot (or Recovery: before source + confidence per file); variants tried + kept; LCP element per page; artifacts excluded + evidence; unscored insights + cost; per-page check counts; controls run + result; owner gates taken/pending/rejected; UNTESTED hypotheses; cleanup proof; uncommitted state.

## Pitfalls (index; rule lives in the named phase)
- Tunnel `x-robots-tag: none` → P2. Edge-injected script (e.g. Cloudflare email-decode) → P2/P4. PSI 429 → P1. Lantern vs observed vs tunnel disagree → P2.
- HEAD as baseline in dirty tree → P6. Snapshot after fixes started → Snapshot step / P6 Recovery. Variant built in repo → P6.
- Preload without `crossorigin` → P5. Extra preloads competing with LCP → P5. LCP element guessed, not read from JSON → P5/P6. Lantern LCP constant across variants → P2.
- Changing a shared token used decoratively → P4. Non-wrapping text overflow at narrow widths → P6.
- Framework drops HTML comments passed through slots (e.g. a comment directive the platform reads) → recipes Stack notes.
- Telemetry off on every build/tool run → P5.
- Brief silently lowering run count / `n=1` delta reported → P1. Unscored insight sold as score fix → P2/P4. `immutable` on unhashed paths → P4/P5.
- Mirror check by reading files → P6. Per-page check on one page → P6. "0 found" without control → P6.
