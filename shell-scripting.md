# Shell Scripting

Conventions for COMMITTED shell scripts (repo tooling, CI, hooks). Distinct from CLAUDE.md rule on suggesting Fish commands to the user — that stays interactive-only.

## Language choice

- Bash for portability: repo tooling, CI, hooks, anything run cross-machine or by others.
- Fish only for interactive helpers, user-local functions — never committed CI/tooling scripts.
- Beyond ~100 lines: reconsider — Python (`uv run`) instead. Script growing past that = complexity smell.

## Bash baseline

- Shebang: `#!/usr/bin/env bash` — not `/bin/bash` (portability), not `sh` (feature loss).
- `set -euo pipefail` — always, first line after shebang.
- Shellcheck-clean: no unquoted expansions (`"$var"` not `$var`), arrays for lists (`files=(a b c)`, `"${files[@]}"`), `local` for function-scoped vars.
- `trap 'cleanup' EXIT` for temp files/resources — never rely on falling off the end.
- `$(cmd)` over backticks — nestable, readable.
- `printf` over `echo -e` — portable escape handling, no `-e` flag ambiguity across shells.

## Structure

- Functions: `local` every var not meant to leak; return via exit status + stdout, not globals.
- Quote every expansion unless intentionally word-splitting (rare, comment why).
- Prefer `[[ ]]` over `[ ]` — no word-splitting/globbing surprises, supports `&&`/`||`/regex.
- Exit codes meaningful: 0 success, nonzero + stderr message on failure.

## Checklist

- [ ] `#!/usr/bin/env bash` + `set -euo pipefail`
- [ ] shellcheck clean
- [ ] all expansions quoted; lists are arrays
- [ ] functions use `local`
- [ ] cleanup via `trap`
- [ ] `$()` not backticks; `printf` not `echo -e`
- [ ] under ~100 lines, else consider Python (`uv run`)
