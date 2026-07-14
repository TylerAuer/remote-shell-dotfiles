---
name: pr-description
description: Generate terse, skim-friendly PR descriptions in a Summary/Details/Links format. Use when about to run `gh pr create`, when editing a PR body via `gh pr edit`, when the user types `/pr-description`, or when the user asks in natural language to write/draft/improve a PR description or PR body. Replaces the default verbose template — strips test plans, Claude Code footers, and diff recaps.
---

# pr-description

Write PR bodies optimized for skimming. The reviewer should know the *what* and *why* in under ten seconds.

## Output format

Exactly this shape — no other sections:

```
## Summary
<1–3 sentences: what changed + motivation. Skip motivation only if obvious.>

## Details
<Optional. Omit entirely unless there is genuine non-obvious "why".
Max 4 sentences OR 8 bullets. Color/rationale only — never a diff recap.>

Closes: #123
Related: #456
```

## Hard rules

1. **No `## Test plan` section.** Strip it from the default flow.
2. **No "🤖 Generated with Claude Code" footer.** Strip it.
3. **No file or function name lists.** Do not enumerate touched files or symbols (`Updated X in src/foo.ts`, `Modified bar()`, etc.) anywhere.
4. **Details is rationale, not recap.** Forbid `This PR adds X, modifies Y, updates Z`-style sentences. If a line describes the diff, delete it.
5. **Details is optional.** Omit the entire section if the Summary already conveys the motivation and there is no non-obvious context.
6. **Links section: GitHub `#123` only.** Same-repo issues/PRs.
7. **Verb chosen per link:**
   - `Closes:` — issue/PR this fully resolves
   - `Related:` — context-only references
   - `Reverts:` — PR being reverted
8. **No links found → omit the section.** No placeholders. Do not prompt the user.
9. **This skill does not generate the title.** The surrounding `gh pr create` flow handles titles.

## Mode selection

- **End-to-end mode** — invoked inside a `gh pr create` flow: produce the body AND run `gh pr create --title "<title from caller>" --body "<body>"`. Pass the body via a HEREDOC to preserve formatting.
- **Body-only mode** — invoked standalone (e.g. `/pr-description`, "draft a PR body for this branch"): print the body. Do not run `gh`.

If unclear which mode applies, default to body-only.

## Link auto-detection

Scan, in this order, for `#N` references:

1. Commit messages on the branch (`git log <base>..HEAD`)
2. Branch name (`fix/123-foo`, `eng-456-bar` → `#123`, `#456`)
3. Claude Code conversation context (issues/PRs the user mentioned this session)

Classify each:
- `closes #N`, `fixes #N`, `resolves #N` in a commit → `Closes:`
- A revert commit referencing `#N` → `Reverts:`
- Everything else → `Related:`

Dedupe. Preserve order of first appearance.

## Good vs bad

**Good** — what to produce:

```
## Summary
Refactors retry logic to exponential backoff instead of fixed intervals, reducing thundering-herd load on the upstream API during outages.

## Details
Jitter is capped at 5s to keep p99 latency bounded — without the cap, the worst-case retry chain ballooned past our SLO.

Closes: #482
```

Why it works: Summary states change + motivation in one sentence. Details adds a non-obvious constraint (the cap and why). No file names, no test plan, no footer.

**Bad** — what to avoid (the Claude default):

```
## Summary
- Updated `RetryClient` in `src/clients/retry.ts` to use exponential backoff
- Modified `computeDelay()` to return `min(base * 2^n, maxDelay)`
- Added `jitterMs` parameter to `RetryConfig`
- Updated tests in `retry.test.ts` to cover new behavior
- Bumped version in `package.json`

## Test plan
- [ ] Run `npm test`
- [ ] Manually verify retry behavior in staging

🤖 Generated with Claude Code
```

Why it's bad: bullets are a diff recap (file names, function names, version bumps). No motivation anywhere. Test plan and footer are forbidden boilerplate.

## Self-check before emitting

- [ ] Summary is 1–3 sentences and conveys *why*, not just *what*
- [ ] Details omitted, OR ≤4 sentences / ≤8 bullets of rationale only
- [ ] Zero file paths, function names, or version bumps in either section
- [ ] No `## Test plan`, no Claude Code footer
- [ ] Links section omitted if empty, otherwise correct verb per link
