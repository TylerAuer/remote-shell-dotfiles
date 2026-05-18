---
name: pr-address-comments
description: Responds to all unresolved comments on a PR. Questions get researched and answered. Requests/instructions get implemented, committed, pushed, and replied to with a commit link. All replies are prefixed with "(Reply authored by Claude)".
---

# Address PR Comments

You are responding to comments on a GitHub pull request. The user may provide a PR number, URL, or you can infer the PR from the current branch.

## Setup

1. Determine the PR to work on:
   - If the user provided a PR number or URL, use that.
   - Otherwise, use `gh pr view` to find the PR for the current branch.

2. Fetch all review comments and issue comments on the PR:
   ```bash
   gh pr view <PR> --json reviews,comments,reviewThreads
   ```
   Also fetch inline review comments:
   ```bash
   gh api repos/{owner}/{repo}/pulls/<PR>/comments
   ```

3. Filter to unresolved/unanswered comments only — skip comments that are already resolved or where the last reply is from you (Claude).

## For Each Comment

Classify the comment as one of:
- **Question** — asks for information, explanation, or clarification
- **Request/Instruction** — asks you to make a change, fix something, or take an action
- **Praise/acknowledgment** — no response needed, skip it

### If it's a Question

1. Research the answer by reading relevant code, files, docs, or running commands.
2. Formulate a clear, concise answer (prefer bullet points over prose).
3. Post a reply using `gh api`:
   ```bash
   gh api repos/{owner}/{repo}/pulls/<PR>/comments/<comment_id>/replies \
     -f body="(Reply authored by Claude)\n\n<your answer>"
   ```
   For general PR comments (not inline):
   ```bash
   gh api repos/{owner}/{repo}/issues/<PR>/comments \
     -f body="(Reply authored by Claude)\n\n<your answer>"
   ```

### If it's a Request or Instruction

1. Understand exactly what change is being asked for. Read the relevant files.
2. Make the requested change using Edit or Write tools.
3. Run any applicable linters, formatters, or tests to verify the change.
4. Commit the change:
   ```bash
   git add <specific files>
   git commit -m "<concise message describing the change>

   Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
   ```
5. Push the branch:
   ```bash
   git push
   ```
6. Get the commit SHA:
   ```bash
   git rev-parse HEAD
   ```
7. Reply to the comment with a summary of what was done and a link to the commit:
   ```bash
   gh api repos/{owner}/{repo}/pulls/<PR>/comments/<comment_id>/replies \
     -f body="(Reply authored by Claude)\n\n<concise summary of change>\n\nCommit: <commit URL>"
   ```
   The commit URL format is: `https://github.com/{owner}/{repo}/commit/<SHA>`

## Rules

- **Always** prefix every reply with `(Reply authored by Claude)` on its own line, followed by a blank line.
- Be concise — answers should be direct and scannable.
- For requests, only make the change that was asked for. Don't refactor, clean up, or add extras.
- If a request is ambiguous, ask a clarifying question in the reply instead of guessing.
- If a request cannot be safely implemented (e.g., it would break tests or introduce a security issue), explain why in the reply instead of making the change.
- Process comments in order (oldest first).
- Do not re-reply to comments that already have a "(Reply authored by Claude)" reply.
