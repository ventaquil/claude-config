---
name: pr-mr
description: >-
  Prepare a pull/merge request for the current branch: derive an English title and a structured English markdown
  description from the branch's commits and diff, then hand the user a ready push command. Use when the user wants
  to open/create/prep/draft a PR or MR ("open a PR", "create a merge request", "prep an MR", "zrób/wrzuć MR",
  "push and open an MR") or invokes /pr-mr. Never pushes for the user.
---

# PR/MR — draft an English title + description, hand off the push

Produces a review-ready request for the current branch. Claude drafts; the user pushes. The **title and description are always English**, even when the user writes in Polish — the chat reply may follow the user's language, but the artifact does not.

Hard rule (from global CLAUDE.md, no exceptions, not even a dry run): **Claude never runs `git push`.** Claude also never creates the request itself. This skill ends by handing over a command; the user runs it and opens the request. Claude has no way to query the remote's request list — never claim a request was created.

## 1. Preconditions

- `git remote -v` — detect the real remote name (do not hardcode `origin`); several remotes → ask which one. Nothing about the hosting service is assumed: every fact used below comes from the repo at runtime.
- `git branch --show-current` — empty means detached HEAD: stop, a request needs a named source branch.
- Resolve the base branch without guessing: `git symbolic-ref refs/remotes/<remote>/HEAD` → strip to a name; fall back to the HEAD line of `git remote show <remote>`; then to a conventional default name that actually exists in `git branch -r` (`main`, `master`, `develop`, `dev`). Zero or several candidates → ask. If the current branch resolves to the base, stop.
- `git status --porcelain` — if the tree is dirty, surface it and ask commit / stash / proceed. Never auto-commit or auto-stash; the request reflects committed history only.

## 2. Gather the change

- `git fetch <remote> <base>` first so the comparison is fresh.
- Upstream: `git rev-parse --abbrev-ref --symbolic-full-name @{u}`. If none, the push must use `-u <remote> <branch>` and diffs are taken against `<base>`, not `@{u}`. If it exists, `git rev-list --left-right --count <remote>/<branch>...<branch>` — surface diverged/behind state before drafting (a pull/rebase is the user's decision).
- Size, then read: `git diff <remote>/<base>...<branch> --stat`, then the full three-dot diff `git diff <remote>/<base>...<branch>` (three-dot = merge-base diff, matches what a review UI shows). Commits: `git log --no-merges <remote>/<base>..<branch>` (titles + full bodies). Zero commits → stop.
- Read the actual messages and diff content, not just titles. An issue/ticket reference is included **only if genuinely present**: from a trailer or inline reference in the branch's own commit messages, or from the repo's existing commit-message convention (`git log <base>` — reuse its exact key and format verbatim, never invent a tracker name or a key it doesn't use). List all if several. If only the branch name encodes a reference, confirm with the user first. Never fabricate one.

## 3. Draft (always English)

Title: concise, imperative, ~70 chars, in the repo's commit style. Shape the description by size — a single-commit request mirrors that commit's title/body; a multi-commit request synthesizes a narrative grouped by logical concern, not a flat commit dump. Collapse fixups/rebases into their logical parent.

### Description template

Heading discipline: `#` is the general top layer (one restated-title sentence, not a token-for-token repeat). `##` sections are peer concerns in fixed general-to-specific order — Changes (what) → Details (why) → Testing (proof) → Notes (extras). `###` under Details is the only per-area layer and is optional. Omit any section that would be empty; do not pad.

```markdown
# <Title restated as a full sentence — readable on its own>

<One short plain-prose paragraph: what this request does and why. Synthesized across commits, not a list.>

## Changes

- <Logical change, imperative, most impactful first — grouped by concern, not one bullet per raw commit>
- <...>

## Details

### <Non-trivial area touched — only when large enough to warrant it>

<The "why": root cause fixed, trade-off chosen, design rationale. Omit the whole Details section for small,
self-explanatory changes.>

## Testing

- <What was actually run/verified: `make lint`, `make test`, manual repro — state PASS/FAIL or "not yet
  verified", never "should work">

## Notes

<Optional: breaking changes, deliberately-out-of-scope follow-ups, known limitations, reviewer guidance.>

<Issue reference line, in the repo's own existing form — only when one was actually found>
```

Append the trailing reference line only when a reference was actually found in the branch's commits (or a user-confirmed branch-name key), copying the key and format the repo's history already uses; otherwise drop the whole line. List multiple references if several appear across commits.

Present the drafted title and full description to the user for confirmation and edits **before** handing over any command — the wording is theirs to own.

## 4. Hand off — the user pushes

Claude does not create the request. It hands over a push command; the user runs it and opens the request at the URL the push prints (or the remote's compare/new-request page). Substitute the runtime-discovered `<remote>`/`<base>`/`<branch>`; never hardcode `origin`/`main`.

First push (no upstream):

```bash
git push -u <remote> <branch>
```

Already tracked (drop `-u <remote> <branch>`, use bare `git push`):

```bash
git push
```

Rules:

- **Never** route the description through a command-line option — multi-line markdown with fences and quotes is too fragile across shell quoting. Hand it over as its own fenced "paste into the description field" block, pasted at the printed URL.
- If the repo itself documents request-creating push options (its own contributing docs, hooks, or scripts — discovered, never assumed), they may be appended to the command as extra `-o` arguments, with the title only: escape embedded `"` as `\"`, and strip/escape backticks and `$` so the user's shell doesn't mangle it. If escaping would mangle it, omit the title and tell the user to type it in the web form.
- Pushing the same source branch again updates an existing request rather than duplicating it. Claude can't query the remote — say so and tell the user to verify in the UI.
- Keep the command minimal to what was asked — no assignee/reviewer options unless requested. Never suggest a hosting-service CLI or raw token API calls as an "easier" path, and never run one.

Final output is exactly three parts: (a) the fenced description block, (b) the fenced push command, (c) one sentence stating Claude will not run it — the user runs it, opens the request, and pastes the description.

## Edge cases

- Zero commits vs base (already merged / freshly cut) → stop, nothing to open.
- Current branch == base → ask which base to target.
- Detached HEAD → stop, need a named source branch.
- Base undetectable (fresh/shallow clone, no symref, no conventional default branch present) → ask; don't guess from reflog.
- Branch behind/diverged from its own upstream → surface before drafting; pull/rebase is the user's call.
- Merge commits in history → `--no-merges` for logs and summaries.
- No issue reference anywhere → omit the line. Branch-name key only → confirm first. Several references → list all.
- Shell-unsafe / over-long title → escape, cap, or fall back to the web form.
- Large diff / many files → `--stat` first, summarize by area, don't enumerate every file.
- Branch may already have an open request → can't verify; the push updates rather than duplicates — user confirms in the UI.
