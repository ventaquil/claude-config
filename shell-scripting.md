# Shell Scripting

Conventions for COMMITTED shell scripts (repo tooling, CI, hooks). Distinct from CLAUDE.md rule on suggesting Fish commands to the user — that stays interactive-only.

## Language choice

- Bash for portability: repo tooling, CI, hooks, anything run cross-machine or by others.
- Fish only for interactive helpers, user-local functions — never committed CI/tooling scripts.
- Beyond ~100 lines: reconsider — Python (`uv run`) instead. Script growing past that = complexity smell.

## Bash baseline

- Standard header, three lines: `#!/usr/bin/env bash`, `set -Eeuo pipefail`, one-line purpose comment (what + for whom).
- Shebang: not `/bin/bash` (path varies across systems/containers), not `sh` (loses arrays, `[[ ]]`, `local`, process substitution).
- `-E` (errtrace) = ERR trap inherited by functions/subshells. Always on; harmless without a trap.
- Shellcheck-clean: no unquoted expansions (`"$var"` not `$var`), arrays for lists (`files=(a b c)`, `"${files[@]}"`), `local` for function-scoped vars.
- `trap` for temp files/resources — never rely on falling off the end.
- `$(cmd)` over backticks — nestable, readable.
- `printf` over `echo -e` — portable escape handling, no `-e` flag ambiguity across shells.

## Structure

- Logic in `main()`, called `if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi` — guard lets bats source the script without side effects. Vars in `main` still need `local`.
- Validate args + `usage()` before any real work. `--help` → stdout, exit 0; bad/missing args → stderr, nonzero.
- Constants `UPPER_SNAKE_CASE` + `readonly`. Value from command substitution → assign first, `readonly NAME` on next line (mandatory, SC2155 — see `set -e` gotchas).
- Functions: `local` every var not a deliberate return channel (bash vars are global by default); return via exit status + stdout, not globals. Scoping is dynamic — `local` stops clobbering callers, not leaking to callees.
- Quote every expansion unless intentionally word-splitting (rare, comment why).
- Prefer `[[ ]]` over `[ ]` — keyword, operands not word-split/glob-expanded, supports `&&`/`||`/`=~`.
- Exit codes meaningful: 0 success, nonzero + stderr message on failure.

## Error handling

`set -Eeuo pipefail` is a net with documented holes; explicit checks on steps that must not fail silently.

| Situation | `set -e` behavior | Fix |
| --- | --- | --- |
| condition of `if`/`while`/`until` | suppressed, by design | don't assume a failure inside halts |
| non-final element of `&&`/`\|\|` list | suppressed and unreported | explicit status check, or make it last |
| negated with `!` | suppressed | explicit status check |
| `local v=$(cmd)`, also `export`/`readonly`/`declare` | status checked is the builtin's, always 0 | split: `local v; v=$(cmd)` |
| substitution inside larger command (`echo "$(cmd)"`) | outer command's status wins | plain assignment `v=$(cmd)` |
| process substitution `<(cmd)` | status unavailable to parent | capture + check separately |
| function called as `if`/`while` condition | errexit off for EVERY command in its body | check inside, or call unconditionally |
| pipeline truncated by `head`/`less` | writer dies SIGPIPE 141, pipefail fails pipeline | tolerate 141 at that call site only |

- ERR trap = standard reporting: `trap 'error_handler "$?" "${LINENO}" "${BASH_COMMAND}"' ERR`; handler prints failed command, exit code, line to stderr. Reporting aid, not a second safety net — every exemption above applies to it.
- SIGPIPE, per call site: `cmd | head -n 10 || { s=$?; [[ $s -eq 141 ]] || exit "$s"; }`. Never drop `pipefail` globally.

## Quoting & expansion

- `"${arr[@]}"` expands lists element-per-word. `"${arr[*]}"` joins on first char of `IFS` — only when that string is wanted; unquoted `${arr[*]}`/`${arr[@]}` never.
- `read -r` always (bare `read` eats backslashes, splices trailing-backslash lines); `IFS= read -r line` when the exact line matters (default `IFS` trims leading/trailing whitespace).
- `mapfile -t lines < file` (bash 4.0+) for whole-file→array, no subshell — but loads all into memory; stream large inputs.
- Filenames may contain newlines → NUL-delimited channels: `while IFS= read -r -d '' f; do …; done < <(find . -type f -print0)`.
- Glob may match nothing → `shopt -s nullglob` (or `failglob`), and RESTORE prior state (`prev=$(shopt -p nullglob)` … `eval "$prev"`); `shopt` is shell-global, blind `shopt -u` breaks the caller.
- `${var:?msg}` for required values (`rm -rf "${dir:?}"/*.tmp`). `${var:-default}` for optional, applied once at top. `${var:-x}` = unset or empty, `${var-x}` = unset only — pick deliberately.
- `--` before filename operands; where a tool ignores `--`, prefix `./` (`for f in ./*`). A file named `-rf` otherwise parses as flags.
- Log values with `printf '%q'` / `${var@Q}` (4.4+) — hand-built quotes don't survive embedded quotes/backslashes/control chars.

## Resources & cleanup

- Temp space: `mktemp` / `mktemp -d`, never hardcoded `/tmp/foo` (collisions, symlink races). Register cleanup trap immediately after creation, before first use.
- `trap` on a signal REPLACES the previous handler, never stacks. One composed EXIT trap: register paths into an array, clean in a single handler. Handler idempotent (`rm -f`) and `return 0` — nonzero handler is a hazard under `set -e`; guard empty array before expanding.
- Locking: `exec {fd}>"$lockfile"` + `flock -n "$fd"` — kernel-atomic, released on exit, no trap. Never `rm` the lock file in a trap (another holder's fd → a third process takes a second "exclusive" lock). Needs bash 4.1+ and util-linux (absent on macOS/BSD).
- Fallback where `flock` absent: `mkdir "$lockdir"` (atomic EEXIST) + `trap 'rmdir "$lockdir"' EXIT`. Costs: SIGKILL/power-cut leaves a stale lock blocking all future runs; lock path must not be world-writable (pre-creation = DoS).
- Atomic write: `mktemp` in the TARGET's own directory (cross-mount `mv` degrades to copy+unlink, reopening the window) → write → `chmod` explicitly (`mktemp` creates 0600, rename would silently strip needed access) → `mv -f`. Protects concurrent readers only; durability needs fsync, out of scope in bash.

## Security

- Never `eval` on external data — re-parses as shell code; quoting does not make it safe. Build argument arrays: `cmd=(git log --max-count="$n"); "${cmd[@]}"`, and validate anything spliced into option syntax.
- `find … -exec cmd -- {} +` or `find … -print0 | xargs -0 cmd --`. Never plain `find | xargs` (splits on blanks/newlines, interprets quotes; leading `-` read as an option).
- PATH hygiene: set an explicit `PATH` as the script's first action, absolute paths for security-sensitive binaries, never `.` or an empty element. `command -v` proves existence, not integrity.
- Never `source` a path influenced by user input, an untrusted checkout, or a writable shared dir — runs in-process with full privileges, mutates caller vars/functions. Unavoidable → verify checksum first (same-source checksum proves nothing; TOCTOU window remains).
- Secrets never in argv (`ps` / `/proc/PID/cmdline` world-readable); env vars acceptable (`/proc/PID/environ` = same user + root), config-on-stdin better. Suppress tracing around them: `{ set +x; } 2>/dev/null`.
- No `curl | bash` — download to file, verify, then run. Shell executes the prefix before transfer completes; truncated download runs a partial script.
- `printf` format string always a literal — `printf "$user_input"` reintroduces `%` directives.

## CI & tests

- CI lints every bash script: `shellcheck` + `shfmt -d`, fail on any finding. Identify scripts by first-line shebang, not `*.sh` (extension misses extensionless tools, git hooks); walk tracked files (`git ls-files -z`), never raw `grep -rl` (descends `.git`/vendored dirs).
- Style checks in CI are read-only (diff/report, nonzero on violation); auto-fix (`shfmt -w`) only locally.
- Nontrivial script → bats-core tests: function-level by sourcing (safe via the `BASH_SOURCE` guard) plus ≥1 full invocation via `run`. Sourcing applies the script's `set -Eeuo pipefail` to the test shell — keep top level side-effect free.

## Checklist

Header and structure

- [ ] `#!/usr/bin/env bash`, `set -Eeuo pipefail`, one-line purpose comment
- [ ] constants `readonly` + `UPPER_SNAKE_CASE`; command-substitution values assigned on a separate line (SC2155)
- [ ] functions use `local`
- [ ] logic in `main()`, called via `main "$@"` behind a `BASH_SOURCE` guard
- [ ] arg validation + `usage()` before real work; `--help` → stdout/0, errors → stderr/nonzero
- [ ] under ~100 lines, else consider Python (`uv run`)

Error handling

- [ ] no `set -e` reliance in `if`/`while` conditions, `&&`/`||` non-final elements, `!`, declaration builtins, or functions called as conditions
- [ ] ERR trap installed for diagnostics
- [ ] SIGPIPE 141 tolerated per call site, `pipefail` never disabled globally
- [ ] meaningful exit codes; diagnostics to stderr via `printf`

Quoting and expansion

- [ ] every expansion quoted; lists are arrays expanded as `"${arr[@]}"`
- [ ] `read -r` always; `IFS= read -r` when the exact line matters
- [ ] NUL-delimited where filenames may contain newlines
- [ ] `nullglob`/`failglob` enabled AND restored where a glob may match nothing
- [ ] `[[ ]]` not `[ ]`
- [ ] `${var:?}` required, `${var:-default}` optional
- [ ] `--` (or `./` prefix) before filename operands; `printf %q` for logged values
- [ ] `$()` not backticks; `printf` not `echo -e`

Resources and cleanup

- [ ] temp space via `mktemp`/`mktemp -d`, trap registered immediately
- [ ] exactly one EXIT trap, composing all cleanups; handler idempotent, returns 0
- [ ] concurrency guarded by `flock` (or `mkdir` fallback); lock file not removed in a trap
- [ ] writes atomic: temp in the target's own directory, mode set explicitly, then `mv`

Security

- [ ] no `eval` on external data; commands built as argument arrays
- [ ] `find -exec … {} +` or `-print0 | xargs -0`, never plain `find | xargs`
- [ ] explicit `PATH` set first; absolute paths for sensitive binaries
- [ ] nothing sourced from an untrusted or writable path without a verified checksum
- [ ] secrets never in argv; xtrace suppressed around secret handling
- [ ] no `curl | bash` — download, verify, run
- [ ] `printf` format string literal
