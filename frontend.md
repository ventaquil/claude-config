# Frontend

Existing project's stack wins; the default below applies only to a project started from nothing. Correctness > any rule here; comment deviations.

## Stack

- NEW frontend project, no existing app: Astro + React + Tailwind. Current stable versions, resolved at setup from the registry — never a version from memory.
- Existing frontend: use its stack, its idioms, its build. No migration, no second framework, no drive-by major upgrade — migration is its own task, the user's call.
- Unclear which case → read `package.json` + config files (`astro.config.*`, `next.config.*`, `vite.config.*`) before writing a line.

## Astro + React split

- Astro renders by default: pages, layouts, static content, build-time data — zero client JS.
- React only where interactivity actually needs it, as an island with a deliberate `client:load`/`client:visible`/`client:idle`, scoped to the smallest component. Whole page as one island = the default lost.
- No client-side router or global state library for what file routing + props already do.

## Tailwind

- Utility-first in markup. Design tokens in the Tailwind config, not scattered arbitrary values.
- One styling system: no parallel CSS modules / styled-components / global stylesheet beyond the Tailwind entry and genuine resets.
- Repeated utility run → extract a component, not copy-paste and not `@apply` sprawl.

## Dependencies & assets

- Every dep justified: platform/framework primitive first (content collections, `fetch`, `Intl`, modern CSS), library only where it genuinely lacks it. A UI kit is a stack decision, not a drive-by install.
- Images through the framework's own image pipeline, modern format, explicit dimensions (no layout shift). No unoptimized multi-MB source assets in the bundle.
- Lockfile committed; one package manager per repo.

## Telemetry

- Disabled per the global Tooling rule in CLAUDE.md: env var in project config AND the CI/Docker build stage, where the build actually runs (Astro: `ASTRO_TELEMETRY_DISABLED=1`).
- A CLI opt-out (`astro telemetry disable`) writes a per-user file outside the repo — covers local dev only, never a clone or a container build. Not a substitute for the env var.

## Verification

- Rendered-page verification per fable-mode.md: real browser, screenshot, console, plus empty/loading/error states. Green build proves nothing here.
- Check the built output, not only the dev server: production build + preview on the host/port a human uses.

## Checklist

- [ ] Existing project: its stack untouched. New project: Astro + React + Tailwind, versions resolved at setup
- [ ] React only inside islands, smallest scope, deliberate `client:*` directive
- [ ] Tailwind the only styling system; tokens in config, no `@apply` sprawl
- [ ] Deps justified, lockfile committed, one package manager
- [ ] Images via the framework pipeline, dimensions set
- [ ] Telemetry env var set in project config + build stage (CLI opt-out is not enough)
- [ ] Built output rendered and looked at in a real browser (fable-mode.md)
