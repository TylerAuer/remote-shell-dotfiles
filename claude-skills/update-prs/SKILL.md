---
name: update-prs
description: Updates all of the current user's open PRs in a repo by rebasing each branch onto the latest default branch (main/master), resolving conflicts where safe, and force-pushing — one parallel subagent per PR using isolated git worktrees. Use when the user wants to update, refresh, or rebase all of their open PRs against main.
disable-model-invocation: true
---

# Update PRs

Rebase every open PR you authored onto the latest main, resolve safe conflicts, and force-push. One subagent per PR runs in its own git worktree so rebases never clobber each other.

## Quick start

The orchestrator (you) enumerates the user's PRs, dispatches one worktree-isolated subagent per PR in a single message, then prints a summary table. Subagents do the rebase; you never rebase in the main working tree.

## Workflow (orchestrator)

1. **Preflight**
   - Confirm a git repo and `gh auth status` succeeds.
   - Detect default branch: `git symbolic-ref refs/remotes/origin/HEAD --short` (strip `origin/`). Fallback to `main`.
   - `git fetch origin <default-branch>` so everyone rebases onto fresh state.
2. **Enumerate PRs**
   - `gh pr list --author @me --state open --json number,title,headRefName,headRepositoryOwner,isCrossRepository`
   - **Skip cross-fork PRs** (`isCrossRepository: true`) — report them as `SKIPPED (fork)`; we can't safely force-push fork branches.
   - If zero PRs, tell the user and stop.
3. **Dispatch subagents** — one `Agent` call per PR, all in ONE message, each with `isolation: "worktree"`. Fill the template below. Cap at ~5 concurrent; batch the rest.
4. **Collect & report** — build a table: `PR # | title | branch | status`. Statuses: `rebased & pushed`, `already up to date`, `SKIPPED (conflicts)`, `SKIPPED (fork)`, `error`. For skipped-conflict PRs, list the conflicting files so the user can resolve manually.

## Subagent prompt template

```
You are updating ONE pull request. You are in an isolated git worktree — work only here.

PR #<NUMBER>: "<TITLE>"
Branch: <HEAD_REF>
Rebase onto: origin/<DEFAULT_BRANCH>

Steps:
1. git fetch origin <DEFAULT_BRANCH> <HEAD_REF>
2. git checkout <HEAD_REF> && git reset --hard origin/<HEAD_REF>
3. Record before SHA: git rev-parse HEAD
4. git rebase origin/<DEFAULT_BRANCH>
5. On conflict: resolve ONLY when the correct resolution is unambiguous — e.g.
   regenerated lockfiles, non-overlapping additions, import ordering. If resolution
   needs judgment about intent or business logic, run `git rebase --abort` and report
   SKIPPED with the conflicting file paths. After resolving each conflict:
   `git add <files> && git rebase --continue`.
6. If rebase succeeded and HEAD SHA changed: git push --force-with-lease origin <HEAD_REF>
   If HEAD SHA unchanged: report "already up to date", do NOT push.

Report back exactly one status line:
  PR #<NUMBER>: <rebased & pushed | already up to date | SKIPPED (conflicts: file1, file2) | error: <reason>>
```

## Rules

- Never use plain `--force`; always `--force-with-lease`.
- Never auto-resolve a conflict that requires understanding intent — abort and skip.
- Never touch PRs the user did not author, or cross-fork PRs.
- Push only when the branch SHA actually changed.
