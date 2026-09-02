# Global instructions

## Working discipline
- Follow @fable-mode.md exactly — defines investigate/verify/scope/report; overrides defaults on conflict.

## Model delegation
- Delegate by default: prefer cheaper-model subagents over doing everything in main loop. Before nontrivial tasks, ask "which parts can a Haiku/Sonnet subagent handle?" — keep judgment, synthesis, final review for yourself.
- Multi-stage/multi-lane work → Workflow tool as the vehicle, not ad-hoc main-loop orchestration (model-delegation.md P2/P3 still shape lanes + briefs). "Use workflows" said once = standing, firefighting included: hand gathered facts to the workflow instead of finishing the diagnosis in main loop (standing instruction beats model-delegation.md size exemptions).
- Follow @model-delegation.md exactly for model selection, delegation patterns, effort-saving rules.

## Git commits
- Run `git log --oneline -10` first; match repo style. Ambiguous or first commit → ask.
- One commit = one concern, history linear (no merge commits, no fixup/undo pairs). Dependency/library change, tooling change, packaging = separate commits. Message never a placeholder.
- Stage explicit paths per commit — never `git add -A`/`-a` (sweeps unrelated + untracked files).
- Unpushed commits: fix for a defect one of them introduced → fold into the introducing commit, not a follow-up; a commit must not edit code a later commit deletes — order removals first. History rewrite of >1 commit → confirm target granularity with the user, backup ref first.
- Never end a turn offering to commit ("say the word"): commit when the task asks or clearly implies landing the work (user hold or ask-rule above wins), else state plainly that changes are left uncommitted and why.
- NEVER add `Co-Authored-By` or any Claude attribution. No exceptions; overrides harness defaults.
- Messages in English; compound form for replacements ("Remove X and use Y instead").
- NEVER `git push`, in any repo, under any workflow. Stop before push; user pushes.
- Assistant working files (briefs, goals, plans, scratch) stay untracked: `.git/info/exclude`, never the shared `.gitignore`, never their own commit. Found tracked → flag, don't carry forward.
- `.gitignore` is the user's: never edit unasked — cleaning a tree = remove/relocate files, not hide them. Own mistake already on the remote → propose full remediation up front (history rewrite, author/committer dates preserved); user runs the push.
- Docs follow the change: update README/affected docs in the SAME commit as the change they document. Never a separate "update README" commit.

## Shell
- User shell is **Fish**. Commands suggested for user's terminal: Fish syntax — `set VAR value`, `(command)` substitution, `.` not `source`. Bash tool invocations still run bash.

## File language
- Write in the language of the file being edited, not the user's message. User often writes Polish; project files are English. Switch only on explicit request.

## Claude-facing files
- Writing/editing files for Claude itself (CLAUDE.md, rule files, skills, agents): optimize token usage — telegraphic style, no filler/repetition/narration, every token earns its place. Never trade logic or completeness for brevity: all rules, thresholds, names, paths stay intact.
- Tables in these files: compact, no alignment padding (`| a | b |`). No 120-col limit — don't wrap lines.

## Markdown
- Always align table columns (pipes padded with spaces), every write and edit. Exempt: Claude-facing files (compact tables, see above).
- Line length 120 — hard limit, never wrap narrower than needed. Exempt: tables, code blocks, Claude-facing files.

## Tooling
- Telemetry/analytics/usage reporting OFF for every tool, framework, CLI, package manager you set up (Astro, Next, Turbo, Nx, yarn, Homebrew, dotnet, Gatsby…): `DO_NOT_TRACK=1` plus that tool's own opt-out (env var, config key, or `<tool> telemetry disable`). Set in project config + the build/CI/Dockerfile stage — holds for everyone, not just a per-user file. Existing project's CI/Dockerfile → raise it, don't edit as a side effect.

## Go
- Follow @go.md exactly.

## Python
- Follow @python.md exactly.

## Rust
- Follow @rust.md exactly.

## Docker
- Follow @docker.md exactly.

## Shell scripting
- Follow @shell-scripting.md exactly.

## Frontend
- Follow @frontend.md exactly.
