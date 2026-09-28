---
name: summarize-changes
description: Summarize the changes on the current branch, a PR, or a commit range in 1-2 sentences plus 2-5 bullets. Use when the user types `/summarize-changes`, or asks what a branch/PR/diff does — e.g. "summarize this PR", "what changed on this branch?", "tl;dr of #42", "explain these changes", "recap my diff". Use it even when the user does not say "summarize" but wants a short explanation of a set of code changes. Do not use it to write a PR body (use `pr-description`) or to review code for bugs.
---

# summarize-changes

Summarize the changes being made as clearly and succinctly as possible. Use technical language without jargon. Keep the explanation as short as possible without losing the point.

The reader wants to understand the change in about ten seconds. They can read the diff for everything else.

## 1. Find the changes

Pick the first source that matches the request:

1. PR number or URL: `gh pr view <pr> --json title,body,baseRefName,commits` and `gh pr diff <pr>`.
2. Commit range or ref (for example `HEAD~3..HEAD`, `abc123`): `git log` and `git diff` for that range.
3. Current branch (default):
   - Find the base: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`. If that fails, use `git symbolic-ref refs/remotes/origin/HEAD`.
   - `git log --oneline origin/<base>..HEAD` for the commit messages.
   - `git diff origin/<base>...HEAD` for committed changes, and `git diff HEAD` for uncommitted changes.

Get per-file line counts for the files footer from the same source: `git diff --numstat <range>`, or `gh pr view <pr> --json files` for a PR.

If the diff is empty, say so in one line and stop.

Read the actual diff, not only the commit messages. Commit messages and PR bodies tell you the motivation, but they can be stale or incomplete. For large diffs, read `git diff --stat` first, then read the hunks that carry the behavior change. Skip lockfiles, generated files, and formatting-only hunks.

## 2. Write the summary

Use exactly this shape. Add no headings, no preamble, and no closing line after the files footer:

```
<1-2 sentences: what the change does as a whole. Include the motivation if it is not obvious from the what.>

- <important detail>
- <important detail>

**Files**
- `path/to/file` +12 -3
- generated: 4 files +310 -295
- and 7 more +123 -234
```

The first sentences name the change as a whole, not a list of parts. If you need "and" three times, you are listing parts. Find the one purpose that connects them. Prefer one sentence.

Less is more. Every extra line costs the reader time and hides the lines that matter. Use 2 to 5 bullets, but treat 5 as a ceiling, not a target. Most changes need 2 or 3. After you draft the bullets, delete each one that the reader can do without.

Keep each bullet under 12 words. A short bullet forces you to state the point, not the context around it. If a bullet needs more words, it is probably two ideas, or it holds detail the reader can get from the diff.

Start each bullet with **bold text** of 1 to 3 words that names its point, for example **Breaking:**, **Risk:**, **Gap:**, or the key identifier. A reader who scans only the bold text still gets the shape of the change. Use bold only at the start of a bullet. Do not bold text in the lead sentence.

A bullet is worth including only if the reader would be surprised, or would act differently, after they know it:
- behavior changes and new defaults
- breaking changes, migrations, config or env var changes
- risks, known gaps, or follow-up work
- non-obvious design decisions and the reason for them

Routine work is rarely worth a bullet, because the reader assumes it happened. Leave it out unless the whole change is about it:
- tests, linters, type checks, or other static analysis pass
- fixes to references or links in docs
- regenerated code (codegen, lockfiles, snapshots)

Do not recap the diff file by file in the bullets. The files footer holds that list. Name an identifier in `code` only when the reader needs it to understand a detail.

Use the precise technical term (`SIGTERM`, "race condition", "N+1 query"). Do not use filler: leverage, robust, seamless, streamline, enhance, comprehensive.

## 3. Add the files footer

End with a `**Files**` list. It shows the reader where the change lives and how big each part is.

- One line per file: the path in `code`, then `+<added> -<removed>`. Use the numbers from `--numstat`. For a binary file, write `binary`.
- Put all generated files on one line: `generated: <N> files +<added> -<removed>`. Generated files include codegen output, lockfiles, snapshots, and vendored code. The reader never reviews them one by one.
- Show at most 6 lines, and count the generated line as one of them. Order the lines from most to least important, not by size or name.
- If more lines remain, end with `and <N> more +<added> -<removed>`, with the sums of the files you left out.
- For a renamed file, write `old/path → new/path`.

## Example

Diff: adds a `--dry-run` flag to `install.sh`, adds `uninstall.sh`, runs CI on macOS and Linux, and fixes a bug that overwrote backups.

```
Makes the dotfile linker safe to try and to undo, with a dry-run mode and an uninstaller.

- **Bug fix:** a second install no longer overwrites the original `.bak`.
- **`uninstall.sh`** removes only this repo's symlinks, then restores backups.

**Files**
- `install.sh` +48 -11
- `uninstall.sh` +62 -0
- `lib/backup.sh` +9 -4
- `.github/workflows/ci.yml` +6 -2
```

The CI change and the details of `--dry-run` are left out. The reader does not need them to understand the change.
