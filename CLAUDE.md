# Global instructions

## Working discipline
- Follow @fable-mode.md — defines investigate/verify/scope/report; overrides defaults on conflict.

## Model delegation
- Delegate large, genuinely independent or bulk-mechanical work to cheaper-model subagents (Haiku/Sonnet); work finishable in a handful of tool calls stays in main loop (instruction artifacts excepted — `prompt-writer` bullet below wins). Never spawn just to re-check your own work — exceptions: fable-mode.md Verification final gate, model-delegation.md P1 advisor triggers and P3 verify steps. Keep judgment + synthesis for yourself; final review = own adversarial re-read + that gate.
- Multi-stage/multi-lane work → Workflow tool as the vehicle, not ad-hoc main-loop orchestration (model-delegation.md P2/P3 still shape lanes + briefs). "Use workflows" said once = standing, firefighting included: hand gathered facts to the workflow instead of finishing the diagnosis in main loop (standing instruction beats model-delegation.md size exemptions).
- Instruction artifacts models execute (agent defs, skills, rule files, subagent briefs, system prompts, tool descriptions, judge rubrics) → delegate to `prompt-writer`; main loop writes the brief, verifies the result.
- Follow @model-delegation.md for model selection, delegation patterns, effort-saving rules.

## Git commits
- Run `git log --oneline -10` first; match repo style. Ambiguous or first commit → ask.
- One commit = one concern, history linear (no merge commits, no fixup/undo pairs). Dependency/library change, tooling change, packaging = separate commits. Message never a placeholder.
- Stage explicit paths per commit — never `git add -A`/`-a`/`.` (sweeps unrelated + untracked). Every commit: `git diff --cached --name-only` vs intended paths, mismatch → unstage. Soft-reset rebuild — later commits' files sit loose where a blanket add catches them: reset index between commits, diff each about-to-be-committed tree against the original commit's tree.
- Unpushed commits: fix for a defect one of them introduced → fold into the introducing commit, not a follow-up; a commit must not edit code a later commit deletes — order removals first. History rewrite of >1 commit → confirm target granularity with the user, backup ref first; rewrite verified → ask keep-or-delete it, never delete unasked, never skip creating one to dodge the question.
- Never end a turn offering to commit ("say the word"): commit when the task asks or clearly implies landing the work (user hold or ask-rule above wins), else state plainly that changes are left uncommitted and why.
- NEVER add `Co-Authored-By` or any Claude attribution. No exceptions; overrides harness defaults.
- Messages in English; compound form for replacements ("Remove X and use Y instead").
- NEVER `git push`, in any repo, under any workflow. Stop before push; user pushes.
- NEVER open an MR/PR on your own — only on the user's explicit request in that turn. Binds every mechanism equally: `gh pr create`, `glab`, GitHub/GitLab MCP tools, raw API, `-o merge_request.create` push options. Same for reopen, draft→ready, merge. Default = draft title + description, hand over, user creates. Branch already pushed / a tool being available / "prepare a PR" / a PR skill invoked ≠ permission to create. Ambiguous → draft only, ask. Applies to workers too.
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

## YAML
- Inline comments: per block (run of non-blank lines), `#` column = longest `key: value` in the block + 2 spaces, never fewer than 2. Continuation comment-only lines move with the inline comment above. Applies to YAML files and YAML code blocks in docs alike. Comment text untouched.

## Markdown
- Always align table columns (pipes padded with spaces), every write and edit. Exempt: Claude-facing files (compact tables, see above).
- Line length 120 — hard limit, never wrap narrower than needed. Exempt: tables, code blocks, Claude-facing files.

## Tooling
- Telemetry/analytics/usage reporting OFF for every tool, framework, CLI, package manager you set up (Astro, Next, Turbo, Nx, yarn, Homebrew, dotnet, Gatsby…): `DO_NOT_TRACK=1` plus that tool's own opt-out (env var, config key, or `<tool> telemetry disable`). Set in project config + the build/CI/Dockerfile stage — holds for everyone, not just a per-user file. Existing project's CI/Dockerfile → raise it, don't edit as a side effect.
- CI workflow YAML (only when the task itself is that change — fable-mode.md side-effect-edit ban): third-party actions/orbs/includes pinned to tag or commit SHA, never a moving branch (`@main`); triggers path-filtered to what the job checks; secrets from the CI secret store, never literal in YAML; token permissions least-privilege, declared explicitly.
- NEVER hand-edit a lockfile, any ecosystem (`Cargo.lock`, `package-lock.json`, `uv.lock`, `go.sum`…): no Edit/Write, `sed`, or scripted text edit — desyncs integrity hashes from the resolved graph. Change only by running the ecosystem's package manager, manifest edited first if needed. Merge conflict → take one side whole, re-run the tool, never hand-merge. Tool missing/failing → stop, report; never patch the lockfile.

## Language/stack rules
- Path-scoped in `~/.claude/rules/` (go, python, rust, docker, shell-scripting, frontend): auto-load when a matching file is read. Before creating files / starting a project with no matching file read yet, or editing a file of that kind the globs miss (extensionless shell script, git hook) → Read the matching `~/.claude/rules/<name>.md` first. Follow them.
