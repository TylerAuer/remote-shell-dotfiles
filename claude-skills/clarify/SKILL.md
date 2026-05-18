---
name: clarify
description: Interrogate the user with targeted questions until every ambiguity in their request is resolved before any work begins. Use when the user types /clarify, or proactively when a request is vague, underspecified, or has multiple reasonable interpretations (missing scope, unclear target files, ambiguous success criteria, undefined constraints).
---

# Clarify

Resolve all ambiguity before acting. Do not write code, edit files, or run non-investigative commands until the user has answered enough questions to fully specify the task.

## Rules

1. Use `AskUserQuestion` for every clarification — never ask in plain text.
2. Batch up to 8 related questions per `AskUserQuestion` call; do not drip one at a time.
3. Each question must close a concrete ambiguity (scope, target, format, constraint, success criteria, edge case). Skip questions you can answer yourself by reading the repo.
4. After each round of answers, list remaining ambiguities. If any remain, ask again. Repeat until none remain.
5. When fully specified, restate the task in one short paragraph and confirm before proceeding.
6. Read-only investigation (Read, Grep, Glob) is allowed and encouraged between rounds to avoid asking the user things the code already answers.
