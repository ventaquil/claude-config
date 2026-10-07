# claude-config

Personal Claude Code configuration: working discipline, model delegation rules, named subagents, workflow skills
and a minimal statusline. Files map 1:1 to `~/.claude/`.

## Layout

| Path                    | Purpose                                                                                                                                                                                          |
|-------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `CLAUDE.md`             | Global instructions entry point — imports `fable-mode.md` and `model-delegation.md` via `@`; points at `rules/`                                                                                  |
| `fable-mode.md`         | Working discipline: evidence before acting, scope, verification, autonomy, communication                                                                                                         |
| `model-delegation.md`   | Model selection + delegation patterns (P1 advisor-executor, P2 orchestrator-worker, P3 loop)                                                                                                     |
| `rules/`                | Path-scoped rules, loaded only when a matching file is read: language/stack (go, python, rust, docker, shell-scripting, frontend) and `adr` (ADR invariants)                                     |
| `agents/`               | Named subagents: `architect` (Opus, plan), `developer` (Sonnet, implement), `reviewer` (Opus, adversarial verify), `grunt` (Haiku, mechanical), `prompt-writer` (Opus, LLM-facing prompts/rules) |
| `skills/`               | Workflow skills: `adr` (record/supersede ADRs), `debug`, `decide`, `pr-mr`, `unstick`                                                                                                            |
| `statusline-command.sh` | Statusline: `ctx 30% \| session 23% \| weekly 1%` left, `Opus 5.5 \| high` right-aligned (context + rate-limit usage, model, effort; ctx bold, rest dim)                                         |

## External skills

- [threat-or-treat-review](https://github.com/ventaquil/threat-or-treat-review) — precision-first, adversarially
  verified code review; the default review vehicle referenced throughout `fable-mode.md` and `model-delegation.md`.
  Installed separately into `~/.claude/skills/threat-or-treat-review/`.

## Install

Preferred: let Claude Code install it and merge it with what you already have. Start a session and prompt:

```text
Check https://github.com/ventaquil/claude-config and install it in my config; adapt it to my working routine.
```

Manual: copy (or symlink) the contents into `~/.claude/`:

```sh
cp -r CLAUDE.md fable-mode.md model-delegation.md rules agents skills statusline-command.sh ~/.claude/
```

Upgrading from the flat layout: delete the old top-level `~/.claude/{go,python,rust,docker,shell-scripting,frontend}.md`
copies after copying `rules/` — nothing imports them any more.

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
review), so prefer targeted edits over rewrites. Tables in instruction files stay compact (no alignment padding);
only this README aligns table pipes. Re-run `/doctor prompt-audit` after each model release.
