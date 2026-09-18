# claude-config

Personal Claude Code configuration: working discipline, model delegation rules, named subagents, workflow skills
and a minimal statusline. Files map 1:1 to `~/.claude/`.

## Layout

| Path                    | Purpose                                                                                                                                                                                          |
|-------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `CLAUDE.md`             | Global instructions entry point — imports the files below via `@` references                                                                                                                     |
| `fable-mode.md`         | Working discipline: evidence before acting, scope, verification, autonomy, communication                                                                                                         |
| `model-delegation.md`   | Model selection + delegation patterns (P1 advisor-executor, P2 orchestrator-worker, P3 loop)                                                                                                     |
| `rust.md`               | Rust conventions (API guidelines, errors, testing, cargo)                                                                                                                                        |
| `go.md`                 | Go conventions (Effective Go, error handling, concurrency, testing)                                                                                                                              |
| `docker.md`             | Docker conventions (multi-stage builds, base images, layers, compose)                                                                                                                            |
| `python.md`             | Python conventions (uv tooling, ruff, typing, pytest)                                                                                                                                            |
| `shell-scripting.md`    | Shell scripting conventions for committed scripts (bash baseline, structure)                                                                                                                     |
| `frontend.md`           | Frontend conventions (Astro + React + Tailwind for new projects, existing stack respected)                                                                                                       |
| `agents/`               | Named subagents: `architect` (Opus, plan), `developer` (Sonnet, implement), `reviewer` (Opus, adversarial verify), `grunt` (Haiku, mechanical), `prompt-writer` (Opus, LLM-facing prompts/rules) |
| `skills/`               | Workflow skills: `debug`, `decide`, `pr-mr`, `unstick`                                                                                                                                           |
| `statusline-command.sh` | Statusline: `ctx 30% \| session 23% \| weekly 1%` left, `Opus 5 \| high` right-aligned (context + rate-limit usage, model, effort; ctx bold, rest dim)                                           |

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

`~/.claude/settings.json` (also untracked, machine-specific) should additionally carry a `permissions.deny` block that
mechanically enforces the git rules in `CLAUDE.md`. The prose there bans `git push` and sweep-staging, but a low-effort
pass can skip prose; a deny rule cannot. Rules match a command prefix on word boundaries, so combined or relocated
flags (`git commit -am`, `git -C <dir> push`) still get through — the prose rules stay the backstop for those.

```json
"permissions": {
  "deny": [
    "Bash(git push:*)",
    "Bash(git add -A:*)",
    "Bash(git add --all:*)",
    "Bash(git add .:*)",
    "Bash(git commit -a:*)",
    "Bash(git commit --all:*)",
    "mcp__github__push_files",
    "mcp__github__create_or_update_file"
  ]
}
```

## Conventions

Instruction files are deliberately caveman-compressed (terse lines over prose) — keep new rules in the same style;
the compression applies to Claude-facing files only, never to user-facing output. Rule files are living artifacts,
partly evidence-tuned from real session transcripts and maintained by agent loops (plan → verify → implement →
review), so prefer targeted edits over rewrites and keep markdown table pipes aligned.
