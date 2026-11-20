# Claude Code Instructions

Global instructions for Claude Code. They apply to all projects.

Source of truth: `dotfiles/.claude/CLAUDE.md` in the `dot-files` repo.
This is a copy. `install.sh` copies it to `~/.claude/CLAUDE.md`.

## Git and GitHub

- Always open PRs in draft mode.

## Guidelines

- **Be very clear and concise** - Prefer bullet points and lists over long paragraphs.
- **Use technical language** - Use precise technical terms relevant to the context. Avoid vague or general terms.
- **Write short explanations** - See the "Explanations" section below. It applies to every response.
- **Ask clarifying questions** - If the prompt is ambiguous or lacks necessary details, ask specific questions to gather more information before providing an answer.
- **Run code analysis tools** - If applicable, use linters, formatters, tests or other code analysis tools to ensure code quality before considering a response complete.

## Explanations

**I read short, clear statements. I skip long paragraphs. Write for a reader who skims.**

Length and shape:

1. Give the answer in the first sentence. Add detail after it.
2. Put one idea in each sentence.
3. Never write a paragraph longer than 3 sentences.
4. Prefer a list of short lines over a paragraph.
5. Delete preamble. Do not repeat my question. Do not tell me what you will say next.
6. Do not add a summary that repeats the text above it.

Words:
7. Use the exact technical term: `useEffect`, "race condition", "N+1 query", "SIGTERM". Do not replace a precise term with a vague word.
8. Name files, functions, flags, and commands exactly. Use `code` format for them.
9. Explain a technical term only when I am unlikely to know it. Use one short sentence.
10. Do not use jargon, buzzwords, or business filler. Banned words include: leverage, robust, seamless, streamline, holistic, synergy, unlock, elevate, deep dive, under the hood, at the end of the day.
11. Do not use metaphors or analogies unless I ask for one.
12. Do not use hype adjectives: powerful, elegant, blazing, comprehensive.

Test each answer: if you can cut a word and keep the meaning, cut it.

## Text output

Write every response in ASD-STE100 Simplified Technical English:

> Max 20 words per sentence in instructions, 25 in descriptions. Imperative for
> steps, one instruction per sentence, condition before command. Simple tenses
> only — no present perfect, no -ing verbs, no should/would/may/might. Active
> voice. One word per meaning — no synonym rotation. No contractions, keep
> articles and "that". Delete filler: simply, robust, seamlessly, leverage. Code
> and identifiers stay exact.

Exception: always use the exact technical term, even when the STE dictionary
excludes it. See rule 7 in "Explanations".

For long-form technical writing — docs, READMEs, runbooks, PR bodies, error
messages, release notes — use the `simple-english` skill. It holds the full 53
rules of the standard.

# Code

When writing or updating code, keep these rules in mind:

- *Only essential comments* - Code should be self-documenting as much as possible. Comments should only provide information that isn't available from the code itself or the git history. Do not add comments that explain what the code does or when it was written
- *Use newspaper style* - Write code as if it is a newspaper article with the entry point at the top.
- *Prefer narrow and branded types* - Use narrower types instead of general ones when possible. For example, an integer id should be represented as a branded type instead of a plain `number`. This prevents accidental misuse of the value in other contexts.
- *Simplicity and readability over cleverness* - Write code that is easy to read and understand. Avoid clever tricks or optimizations that make the code harder to follow.
