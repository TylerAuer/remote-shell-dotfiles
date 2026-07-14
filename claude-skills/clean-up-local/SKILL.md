---
name: clean-up-local
description: Safely clean up a repo's local state — prune local branches and git worktrees after verifying no work is lost (every branch must be merged into the default branch or pushed to an open PR before deletion). Use when the user wants to clean up, prune, tidy, or delete stale branches and/or worktrees.
disable-model-invocation: true
---

# Clean Up Local

Delete local branches and worktrees aggressively — including branches whose commits are fully pushed to a PR (open or merged); a local copy of pushed work is redundant. Only proof of safety is required: every commit is either merged into the default branch (incl. squash) or pushed to a remote. Never delete unmerged, unpushed work.

## Workflow

1. **Preflight**
   - Confirm a git repo. Detect default branch: `git symbolic-ref refs/remotes/origin/HEAD --short` (strip `origin/`); fallback `main`.
   - `git fetch --all --prune` to refresh remote state and drop deleted remote-tracking refs.

2. **Classify each local branch** (skip the default branch and the current branch)
   - **Be squash-aware.** Squash merges land one *new* commit on the default branch, so the hashes never match. `git branch --merged` and `git cherry` report squash-merged branches as unmerged — do NOT trust them to prove "at risk".
   - **Merged via PR (covers squash)**: `gh pr list --head <branch> --state all --json number,state,title` → a MERGED/CLOSED PR ⇒ safe.
   - **Squash-merged without a matching PR head** (branch renamed/deleted on remote): match the branch's commit subjects against the default branch log:
     ```
     for s in "$(git log --format=%s origin/<default>..<branch>)"; do git log origin/<default> --oneline --grep="^${s}\$"; done
     ```
     Every subject found (typically as `… (#NNN)`) ⇒ squash-merged, safe.
   - **Fully pushed with a PR (open OR merged)** — *delete it*: the work lives on the remote, so a local copy is redundant even while the PR is open. Both must hold:
     - every commit is on a remote: `git log --oneline <branch> --not --remotes` is empty.
     - a PR exists: `gh pr list --head <branch> --state all` returns one.
     Do not keep "active" PR branches — deleting the local branch never affects the open PR.
   - **At risk**: `git log --oneline <branch> --not --remotes` is non-empty AND no subject match in the default branch ⇒ commits that exist on no remote and are not squash-merged. Do NOT delete.

3. **Report before deleting** — table: `branch | status (merged / PR #N open / PR #N merged / AT RISK) | action`. List AT RISK branches explicitly and stop to ask before touching them.

4. **Delete safe branches** — every branch classified safe in step 2 (merged, squash-merged, or fully pushed with a PR), including open-PR branches.
   - Merged (non-squash): `git branch -d <branch>`. Squash-merged or fully-pushed-open-PR branches need `git branch -D` (git can't see them as merged — that's expected; safety was already confirmed in step 2).
   - Branch checked out in a worktree must have its worktree removed first (step 5).

5. **Clean worktrees**
   - `git worktree list` → for each non-main worktree that is clean (`git -C <path> status --porcelain` empty) and whose branch is safe: `git worktree remove <path>`.
   - Dirty worktrees (uncommitted changes): report, do NOT remove.
   - `git worktree prune` to clear stale admin files.

## Rules

- A branch is safe to delete if every commit is merged into the default branch (incl. squash-merged — verify via PR state or commit-subject match, never `git branch --merged`/`git cherry` alone) OR fully pushed to a remote with a PR (open or merged). An open PR is NOT a reason to keep a fully-pushed branch — delete it. Anything with commits on no remote and not merged is AT RISK — report and ask, never auto-delete.
- Never delete the default branch or the current branch.
- Never `git worktree remove` a worktree with uncommitted/untracked changes.
- Prefer `git branch -d` (safe) over `-D` (force); use `-D` only when status is independently confirmed safe.
