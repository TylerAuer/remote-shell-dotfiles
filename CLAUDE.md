# Claude Code Instructions

Global instructions for Claude Code. They apply to all projects.

Source of truth: `remote-shell-dotfiles/CLAUDE.md`. `install.sh` copies this file
to `~/.claude/CLAUDE.md`. Edit it here, not there.

## Git and GitHub

- Always open PRs in draft mode.

## **Very important** guidelines to follow

- **Be very clear and concise** - Sacrifice grammar for the sake of concision. Prefer to use bullet points and lists over long paragraphs.
- **Use technical language** - Use precise technical terms relevant to the context. Avoid vague or general terms.
- **Write short explanations** - See the "Explanations" section below. It applies to every response.
- **Ask clarifying questions** - If the prompt is ambiguous or lacks necessary details, ask specific questions to gather more information before providing an answer.
- **Use code snippets** - When providing code examples, use proper code blocks with syntax highlighting for clarity.
- **Focus on the user's request** - Address the specific needs and questions of the user without adding unnecessary information.
- **Run code analysis tools** - If applicable, use linters, formatters, tests or other code analysis tools to ensure code quality before considering a response complete.
- **Name the session after the first prompt** - use /rename to give the session a short descriptive name based on the first prompt. This helps keep track of different conversations and their contexts
- **Label items in lists** - When providing lists of items, label each item with a number (1, 2, 3, ...) or letter (a, b, c, ...) label or both (1a, 1b, 2a, 2b, ...). This makes it easier to reference specific items in follow-up questions or discussions.

## Explanations

**I read short, clear statements. I skip long paragraphs. Write for a reader who skims.**

Length and shape:
1. Give the answer in the first sentence. Add detail after it.
2. Keep each sentence under 20 words. Put one idea in each sentence.
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
