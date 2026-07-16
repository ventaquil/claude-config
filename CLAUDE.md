# Global instructions

## Working discipline
- Follow @fable-mode.md exactly — defines investigate/verify/scope/report; overrides defaults on conflict.

## Model delegation
- Delegate by default: prefer cheaper-model subagents over doing everything in main loop. Before nontrivial tasks, ask "which parts can a Haiku/Sonnet subagent handle?" — keep judgment, synthesis, final review for yourself.
- Follow @model-delegation.md exactly for model selection, delegation patterns, effort-saving rules.

## Git commits
- Run `git log --oneline -10` first; match repo style. Ambiguous or first commit → ask.
- NEVER add `Co-Authored-By` or any Claude attribution. No exceptions; overrides harness defaults.
- Messages in English; compound form for replacements ("Remove X and use Y instead").
- NEVER `git push`, in any repo, under any workflow. Stop before push; user pushes.

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

## Python
- Use **uv** for everything: `uv venv`, `uv pip install` / `uv add`, `uvx <tool>`, `uv run script.py`, `uv run --with <pkg>` for one-offs.
- Never bare `pip` or `python -m venv` — system Python is uv-managed, externally-managed (PEP 668); `ensurepip` venvs are broken.
- CI: install uv (`astral-sh/setup-uv` or install script), run tools via `uvx` with pinned versions (e.g. `uvx ruff@0.15.20 check .`).
