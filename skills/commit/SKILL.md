---
name: commit
description: Create a git commit following the Liferay convention — TICKET-000 Imperative verb description.
disable-model-invocation: true
---

# Commit

Create a well-formatted git commit following the Liferay ticket convention.

## Step 1 — Gather context

Run in parallel:

```bash
git status
```

```bash
git diff --cached --stat
```

```bash
git diff --stat
```

```bash
git log --oneline -10
```

If there are no staged changes and no unstaged changes, stop and tell the user there is nothing to commit.

## Step 2 — Determine ticket and message

Parse `$ARGUMENTS` for a ticket ID (pattern: `UPPERCASE-DIGITS`, e.g. `LPD-12345`, `LPS-100`, `COMMERCE-456`).

- If a ticket ID is found in the arguments, use it.
- If no ticket ID is found, check the current branch name for a ticket pattern (e.g. `feature/LPD-12345-some-description`).
- If still no ticket ID, ask the user for one.

For the description:

- If provided in arguments, use it as-is (ensure it starts with an imperative verb).
- If not provided, analyze the staged/unstaged changes and generate a concise description starting with an imperative verb (e.g. "Add", "Fix", "Update", "Remove", "Refactor").

## Step 3 — Stage changes

If there are no staged changes but there are unstaged changes, show the list of changed files and ask: **"Stage all changes? (Y/n) or list specific files:"**

- If the user confirms, stage all relevant changes (exclude `.env`, credentials, secrets).
- If the user lists files, stage only those.

If there are already staged changes, use them as-is.

## Step 4 — Commit

Format the commit message as:

```
TICKET-000 Imperative verb description
```

Rules:
- Ticket ID in uppercase, followed by a single space
- Description starts with a capitalized imperative verb
- No period at the end
- Keep the first line under 72 characters
- If more context is needed, add a blank line followed by a body paragraph

Create the commit:

```bash
git commit -m "<TICKET-000 Message>"
```

## Step 5 — Confirm

Show the created commit:

```bash
git log --oneline -1
```

Report done.
