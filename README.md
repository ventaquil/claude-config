# claude-config

Personal Claude Code configuration: working discipline, model delegation rules, named subagents, workflow skills
and a minimal statusline. Files map 1:1 to `~/.claude/`.

## Layout

| Path                    | Purpose                                                                                                                                         |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| `CLAUDE.md`             | Global instructions entry point — imports the files below via `@` references                                                                    |
| `fable-mode.md`         | Working discipline: evidence before acting, scope, verification, autonomy, communication                                                        |
| `model-delegation.md`   | Model selection + delegation patterns (P1 advisor-executor, P2 orchestrator-worker, P3 loop)                                                    |
| `rust.md`               | Rust conventions (API guidelines, errors, testing, cargo)                                                                                       |
| `go.md`                 | Go conventions (Effective Go, error handling, concurrency, testing)                                                                             |
| `docker.md`             | Docker conventions (multi-stage builds, base images, layers, compose)                                                                           |
| `python.md`             | Python conventions (uv tooling, ruff, typing, pytest)                                                                                           |
| `shell-scripting.md`    | Shell scripting conventions for committed scripts (bash baseline, structure)                                                                    |
| `frontend.md`           | Frontend conventions (Astro + React + Tailwind for new projects, existing stack respected)                                                      |
| `agents/`               | Named subagents: `architect` (Opus, plan), `developer` (Sonnet, implement), `reviewer` (Fable, adversarial verify), `grunt` (Haiku, mechanical) |
| `skills/`               | Workflow skills: `debug`, `decide`, `pr-mr`, `unstick`                                                                                          |
| `statusline-command.sh` | Statusline: `ctx 30% \| session 23% \| weekly 1%` (context + rate-limit usage)                                                                  |

## External skills

- [threat-or-treat-review](https://github.com/ventaquil/threat-or-treat-review) — precision-first, adversarially
  verified code review; the default review vehicle referenced throughout `fable-mode.md` and `model-delegation.md`.
  Installed separately into `~/.claude/skills/threat-or-treat-review/`.

## Install

Copy (or symlink) the contents into `~/.claude/`:

```sh
cp -r CLAUDE.md fable-mode.md model-delegation.md go.md python.md rust.md docker.md shell-scripting.md frontend.md agents skills statusline-command.sh ~/.claude/
```

The statusline needs a `statusLine` block in `~/.claude/settings.json` (not tracked here — machine-specific):

```json
"statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }
```

## Conventions

Instruction files are deliberately caveman-compressed (terse lines over prose) — keep new rules in the same style;
the compression applies to Claude-facing files only, never to user-facing output. Rule files are living artifacts,
partly evidence-tuned from real session transcripts and maintained by agent loops (plan → verify → implement →
review), so prefer targeted edits over rewrites and keep markdown table pipes aligned.
