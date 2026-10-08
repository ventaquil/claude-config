# pagespeed recipes

Read before running any measurement. Placeholders (`<ver>`, `<rev>`, `<tag>`, `<port>`, `<scratch>`, `<repo>`, `<cloudflared>` = PATH `cloudflared` or `<scratch>/tools/cloudflared`) are filled from `--version`/`--help` output, repo files, or the brief — never from memory. All installs, builds, outputs live under `<scratch>`; nothing is written into `<repo>`.

## Host setup
- Tools dir: `<scratch>/tools`. Never `npm install` in `<repo>`.
- Every command: `export DO_NOT_TRACK=1` + framework telemetry opt-out — copy the variable the repo already sets (grep `TELEMETRY` in Dockerfile, CI, package scripts, env files); none found → note it in the report.
- Playwright CLI version must match the cached browser build: `npx playwright@<ver> install chromium-headless-shell`, or `npm i playwright@<ver>` in `<scratch>/tools`.
- Chromium for Lighthouse: `find ~ -path '*chromium-*/chrome-linux64/chrome' 2>/dev/null` → `<chrome>` (Playwright cache `chromium-<rev>/chrome-linux64/chrome`).
- Lighthouse run (default form factor = mobile; other flags only after checking `npx lighthouse@<ver> --help`):
```bash
CHROME_PATH=<chrome> npx lighthouse@<ver> "<url>" --output=json --output-path=<out>.json \
  --chrome-flags="--headless=new --no-sandbox" --quiet
```
- Record `.lighthouseVersion` and form factor from the JSON for the report.

## Median-of-3 loop
- First JSON → confirm audit ids (they vary by Lighthouse version): `jq -r '.audits|keys[]' <f>.json | grep -iE 'render-blocking|first-contentful|largest-contentful|layout-shift|blocking-time|^metrics$'`. Use the ids found, never assumed ones.
- Per run extract: `.categories.performance.score`, `.categories.accessibility.score`, `.categories["best-practices"].score`, `.categories.seo.score` (×100); `.audits["<fcp id>"].numericValue`, LCP, CLS, TBT likewise; observed LCP `.audits.metrics.details.items[0].observedLargestContentfulPaint` (confirm key exists); render-blocking count `.audits["<render-blocking id>"].details.items | length`.
- Loop: `for side in <sides>; for page in <paths>; for i in 1 2 3` → `<scratch>/lh/<source>/<side>/<page-slug>-<i>.json`.
- Median = middle of the 3 sorted values, per metric. One TSV per build+source: `page	run	perf	a11y	bp	seo	fcp	lcp	cls	tbt	obs_lcp	rb`, plus a median row per page.
- Lab-simulated (`numericValue`) and observed (`observed*`) go in separate columns/tables, never averaged together.
- Run count lowered by explicit brief wording → TSV rows + report rows labelled `n=<runs>`; no median row; no delta on an `n=1` row reported as a change (SKILL.md Phase 1).
- Unscored check (SKILL.md Phase 2): `jq '.categories.performance.auditRefs[] | select(.id=="<id>") | {weight, group}' <f>.json` → weight 0 = unscored. Never use `scoreDisplayMode` (measured LH 13.5.0: `cache-insight` = "metricSavings", `network-dependency-tree-insight` + `first-contentful-paint` = "numeric"). Measured LH 13.5.0: every group "insights" audit (incl. `render-blocking-insight`) weight 0; weighted = first-contentful-paint (10), largest-contentful-paint (25), total-blocking-time, cumulative-layout-shift, speed-index. Report item count + estimated cost from `.details`, never a score impact.
- LCP element: `jq -r '.audits|keys[]' <f>.json | grep -iE 'lcp|largest-contentful'` → id of the LCP-element audit or its insight equivalent (use the id found); `jq '.audits["<id>"].details' <f>.json` → quote the node snippet/selector it names. Never infer the element from page layout.

## Snapshot (SKILL.md Snapshot step)
```bash
mkdir -p <scratch>/pre
(cd <repo> && cp -a --parents -- <planned existing paths> <scratch>/pre/)   # planned set
git -C <repo> ls-files -z --cached --others --exclude-standard \
  | rsync -a --from0 --ignore-missing-args --files-from=- <repo>/ <scratch>/pre/   # set uncertain: whole tree minus ignored
printf '%s\n' <planned new paths> > <scratch>/pre.new                        # `: > <scratch>/pre.new` if none
```
- Untracked files are included on purpose: a fix may edit untracked files (header files, server conf).

## Same-source builds
```bash
for side in before after; do
  rsync -a --exclude node_modules --exclude dist --exclude .git <repo>/ <scratch>/<side>/
done
cp -a <scratch>/pre/. <scratch>/before/                       # planned-set snapshot: touched files back to pre-change
(cd <scratch>/before && xargs -r rm -f -- < <scratch>/pre.new)  # files the change created
```
- Whole-tree snapshot → replace the `cp -a` line with `(cd <scratch>/pre && cp -a --parents -- <touched paths> <scratch>/before/)`; touched paths = `developer` changed-file list, each confirmed to differ from its `pre/` copy.
- Both copies taken at the same moment (peer sessions edit `<repo>` concurrently).
- No snapshot (SKILL.md Phase 6 Recovery): per touched file, in `<scratch>/before/`, first available: pre-task copy (`cp`); `git -C <repo> show HEAD:<path> > <scratch>/before/<path>` only if the pre-task `git status` showed that file clean; owner-supplied file; reconstruction = reverse-apply this session's diff of that file (`patch -R`). Record per file `source | confidence`. None → `BLOCKER: no pre-task version of <path>`.
- Build in each copy: repo has a prod Dockerfile stage → `docker build --target <prod stage> -t psi-<side>:local <scratch>/<side>` (image carries the matching server conf). Else the repo's own build command (package scripts, Makefile or equivalent the repo uses), run in `<scratch>/<side>` with telemetry env set.
- Never build in `<repo>`: its `dist/` is shared with the dev server and peer sessions.

## Temp serving
- Pick path: repo ships a Dockerfile / server image → Docker path; none → Process path. Same port + "never touch user processes" rules both paths.

Docker path:
```bash
docker network create psi-net
docker run -d --name psi-<side> --network psi-net -p 127.0.0.1:<port>:<container port> psi-<side>:local
```
- No prod image → mount the build + repo server conf into the server image the repo's Dockerfile uses: `-v <scratch>/<side>/dist:<docroot>:ro -v <scratch>/<side>/<conf>:<conf path in image>:ro`. Container port, docroot, conf path: read from the repo Dockerfile/conf, never assumed.
- Host ports: pick ones `ss -ltn` shows free and the repo compose file does not use. Port taken → choose another; never stop the process holding it.
- Cleanup (Docker path): `docker rm -f` only `psi-*` containers you created; `docker network rm psi-net`; `docker rmi psi-<side>:local`. Proof for the report: output of `docker ps -a --filter name=psi-` (header line only).

Process path (no Dockerfile):
- Serve `<scratch>/<side>/<build output dir>` with the repo's own preview/start command (package scripts), run in `<scratch>/<side>` with telemetry env set, or a local static server installed in `<scratch>/tools`; bind `127.0.0.1:<port>`. Background it, `echo $! > <scratch>/serve-<side>.pid`.
- Ready: `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:<port>/` = 200.
- Headers: `curl -sI` the served page vs the repo's header/server config; server cannot apply that config → list missing headers in the report (headers change scores), never silently compare.
- Cleanup (Process path): `kill $(cat <scratch>/serve-<side>.pid)`; proof = `ps -p <pid>` header only AND `ss -ltn` no longer lists `<port>`. Port still listening → `ss -ltnp` names the child of your recorded PID; kill only that. Never kill processes you did not start.

## Variants (A/B, regression checks)
- Location: ONLY `<scratch>/<variant>/`. Never patch or build in `<repo>`.
- Markup-only variant (preload links, attributes in `<head>`) → patch a copy of the built output; cheap, valid A/B:
```bash
mkdir -p <scratch>/<variant>/dist && cp -a <scratch>/<base side>/dist/. <scratch>/<variant>/dist/
# image-only build: docker create --name psi-extract-<side> psi-<side>:local; docker cp psi-extract-<side>:<docroot>/. <scratch>/<variant>/dist/; docker rm psi-extract-<side>
```
- Patch every `*.html` `<head>` with a script kept in `<scratch>` (sed/perl); preload `href` copied from the built output's file list, never typed from memory. Proof: `grep -c 'rel="preload"' <file>` per HTML file = expected count on every page.
- Serve via Temp serving: Docker path → "No prod image" mount (`<scratch>/<variant>/dist`), container `psi-<variant>`; Process path → serve `<scratch>/<variant>/dist`, PID file `serve-<variant>.pid`. Score with the median-of-3 loop, same pages/tool/form factor as the other variants.
- CSS/JS/font/config change → copy the source to `<scratch>/<variant>/`, edit there, build there (Same-source builds).
- Kept variant → Visual diff again (masks + crops read) before done.

Measured reference (a sample static site, Lighthouse 13.5.0 mobile, medians of 3, variants = patched copies of the built output; directions only):

| variant | preloads | result |
|---|---|---|
| A | latin subsets of the above-the-fold font files | baseline |
| B | A + latin-ext subset of the font carrying a non-ASCII glyph in an above-the-fold element on every page | lower FCP on pages with the glyph; perf no worse on the page measured; simulated LCP delta within Lantern step noise. Adopted |
| C, D | B + a style used above the fold only on some pages (C); B + a family used only below the fold (D) | longest content page worse: higher LCP, lower perf — extra preloads compete with the LCP resource |
| E | none | clearly worst: lower perf, highest FCP, nonzero CLS |

- Longest content page: simulated LCP stayed constant across every variant while observed (unthrottled) was far lower → Lantern modelling artifact; reported, not chased.
- LCP element on one page was a styled paragraph, first misidentified as the heading — read it from the JSON (Median-of-3 loop).

## Tunnel (only when the brief permits public exposure)
- Purpose: expose a LOCAL version (dev server, scratch build) at a public URL so PSI / outside Lighthouse can reach it. Production, on its own host, is measured at its public URL directly, no tunnel. Hosting the site on Cloudflare is not assumed.
- "speedtest" via tunnel = PSI (PSI API) or Lighthouse (Median-of-3 loop) run against the quick-tunnel URL `https://<random>.trycloudflare.com`; PSI cannot reach localhost.
- Quick tunnel facts (Cloudflare TryCloudflare docs; commands below checked against docs, not executed; `--no-autoupdate` not in docs, confirmed via `--help` per Host path): no Cloudflare account or domain needed; testing/development only; new hostname per tunnel; max 200 in-flight requests per tunnel, extra → 429 from the tunnel (not a PSI 429); no SSE; URL stops working when the cloudflared process stops.
- Exposure: anyone with the URL reaches the served site while cloudflared runs → tunnel only scratch builds, only while scoring; never a server exposing secrets, admin or unreleased content.
- Target: the side's temp server (Temp serving: `psi-<side>` container or Process path port). Phase 6 measures built output from those servers. Brief's local server port (Phase 1 baseline, source = quick tunnel) → Host path.

Docker path (Temp serving Docker path only, inside `psi-net`):
- Image + args: copy from the repo compose tunnel service if one exists; else `cloudflare/cloudflared:<tag>` (docs list no tags).
```bash
docker run -d --name psi-tunnel-<side> --network psi-net <cloudflared image> tunnel --no-autoupdate --url http://psi-<side>:<container port>
docker logs psi-tunnel-<side> 2>&1 | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | head -1
```
- Docker form not in the fetched docs (unverified); args mirror the host command.

Host path (no Docker, or a local port):
- `command -v cloudflared && cloudflared --version`. Missing → direct binary from the Cloudflare downloads page (developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) into `<scratch>/tools`, `chmod +x`; URL copied from that page, never typed from memory. System-wide install (package repo, .deb/.rpm) only on owner approval.
- Confirm `--url` and `--no-autoupdate` in `<cloudflared> tunnel --help` before use; absent flag → drop it, note in report.
```bash
<cloudflared> tunnel --no-autoupdate --url http://localhost:<port> > <scratch>/tunnel-<side>.log 2>&1 &
echo $! > <scratch>/tunnel-<side>.pid
grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' <scratch>/tunnel-<side>.log | head -1
```
- `<port>` = host port `psi-<side>` publishes (Temp serving Docker path), the Process path port, or the brief's local server port. Grep empty → re-run it later (still starting); `kill -0 $(cat <scratch>/tunnel-<side>.pid)` fails → read the log, `BLOCKER: tunnel did not start`.

Both paths:
- Ready: `curl -s -o /dev/null -w '%{http_code}\n' <tunnel url>` = 200 before scoring.
- Quick tunnel (`*.trycloudflare.com`) adds `x-robots-tag: none` (any hosting; SKILL.md Phase 2).
- Before scoring: `curl -sI <tunnel url>` → every header absent from the repo's header/server config = tunnel artifact, classified per SKILL.md Phase 2.
- Score: Median-of-3 loop and/or PSI API against the tunnel URL; results go in the separate tunnel / PSI tables (SKILL.md Report format).
- Teardown (after scoring, also on failure): Docker → `docker rm -f psi-tunnel-<side>`, proof = Temp serving `docker ps -a --filter name=psi-`. Host → `kill $(cat <scratch>/tunnel-<side>.pid)`; proof = `ps -p <pid>` prints header only AND `curl` on the tunnel URL no longer returns 200. Never kill cloudflared processes you did not start (`pgrep -a cloudflared` may list the user's own tunnels).

## PSI API
```bash
curl -s -o <out>.json -w '%{http_code}\n' 'https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=<urlencoded url>&strategy=mobile&category=performance&category=accessibility&category=best-practices&category=seo'
```
- Needs a public URL (prod or tunnel); localhost is unreachable for PSI.
- HTTP 429 → one retry max, then report `PSI not run (429)`. Never scrape or borrow a key; never report a PSI number without a 200 response file.

## Visual diff
- Node + Playwright (+ a PNG pixel comparer, e.g. `pixelmatch` + `pngjs`) installed in `<scratch>/tools`.
- Per side × page × width (320/360/375/402/440 + desktop width from brief): context `reducedMotion: 'reduce'`; `goto`; `await page.evaluate(() => document.fonts.ready)`; wait 300 ms; inject CSS hiding animations (`*{animation:none!important;transition:none!important}` + the repo's animated-element selectors); full-page screenshot.
- 2 shots per side → same-side diff must be 0 px; nonzero → fix stabilization, never raise a threshold.
- Mask intentionally changed elements (selector → bounding box); require 0 px differing outside masks. Page height differs between sides → report as a finding.
- Save crops of non-ASCII glyphs + changed elements; Read the PNGs (look at them) before claiming identity.
- Horizontal overflow per width: `document.documentElement.scrollWidth > innerWidth` → finding.
- Control (SKILL.md Phase 6): compare one screenshot against a copy shifted by 1 px → comparer must report nonzero; zero → comparer blind, no identity claim.

## Controls for "0 found" checks
- Each check reporting 0 (pixel diff, console/CSP errors, audit items, duplicate requests, mirror diff) runs once against a deliberately broken input in `<scratch>` that must make it nonzero: 1 px-shifted screenshot; page copy with an injected CSP violation → console counter fires; mirror copy with one header value altered → diff non-empty.
- Report per check: control input, control result, real result. Control stayed 0 → check is blind; real result reported `unverified (no control)`.

## Per-page checks
- Loop over EVERY page in the set (built HTML or served URL); never sample one. Output one line per page `page	pass|fail	detail`, then `<passed>/<total>`.
- Font request count: Playwright script in `<scratch>`; `page.on('request')` records URLs matching `\.woff2`; `goto` with `waitUntil: 'networkidle'`, then `await page.evaluate(() => document.fonts.ready)`; count occurrences per URL; report max count per page. Must be 1; >1 = preload/CSS URL mismatch (double fetch).
- Preload href == CSS `url()`: per page extract preload `href`s for fonts and the `url()`s of the loaded CSS for the same files; every preload href must appear verbatim among them.

## Header mirror check
- Applies when the repo keeps the same headers in >1 file (e.g. a server conf mirroring a platform header file): values must match byte for byte.
- Normalize each mirrored file to sorted `path<TAB>Name: value` lines (e.g. platform header file `_headers`: indented `Name: value` under a path line; server conf: e.g. one `add_header Name "value"` per `location`; other servers/middleware: their per-path header directives, same output shape), then `diff <(norm a) <(norm b)` (or `cmp` of the normalized files).
- Required: empty diff, shown as script output in the report. Never compare by reading the files; no script output → `mirror check not run`. Script kept in `<scratch>`, not the repo.

## Stack notes (apply only on a matching stack)
- Astro: `build.inlineStylesheets: 'always'` removes blocking site CSS. `vite.build.assetsInlineLimit: 0` keeps scripts external under strict script CSP. HTML comments passed through `<slot />` are dropped; comments in the layout's own markup survive (matters for a comment directive the platform reads). Telemetry opt-out `ASTRO_TELEMETRY_DISABLED=1`.
- Astro/Vite hashed self-hosted fonts (when the owner approves it at the cache-policy gate for `cache-insight` font items): (a) move woff2 from `public/` to `src/assets/fonts/`; (b) `@font-face` `url()` paths relative to the CSS file; (c) preload hrefs imported with Vite `?url` → preload href = SAME hashed URL as the CSS `url()`, no double fetch. Existing immutable hashed-asset path rule then covers the fonts; remove the separate cache rule for the old unhashed font path from EVERY mirrored header file; update any doc describing those headers. Verify: `cache-insight` font items 0 on every run; each font requested exactly once per page (count per page, Per-page checks); preload href == CSS `url()` on every page (k/k); old font path → 404 (`curl -sI`); Header mirror check script diff empty; Visual diff 0 px.
- Direction observed on a sample site with self-hosted fonts (Lighthouse 13.5.0 mobile): before, `cache-insight` listed the self-hosted woff2 for a short cache lifetime. After: font items → 0 on all runs; each font requested once; 0 px visual diff on every page × width; perf + LCP unchanged within Lantern step noise. Rejected: `immutable` on unhashed paths — file replaced under the same name stays stale up to a year.
- Cloudflare in front of the origin (only on evidence: `/cdn-cgi/` script in served HTML absent from build output, or a Cloudflare Pages deploy config in repo): zone Email Address Obfuscation injects `/cdn-cgi/scripts/<hash>/cloudflare-static/email-decode.min.js` into HTML containing an email address (owner setting, never changed by an agent). Cloudflare Pages: headers live in `_headers`.
