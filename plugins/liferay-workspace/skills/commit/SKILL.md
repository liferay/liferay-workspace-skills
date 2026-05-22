---
allowed-tools: Bash(git *) Glob Grep Read
argument-hint: [TICKET-000] [description]
description: Create a Git commit following the Liferay convention — TICKET-000 Imperative verb description. Use when the user asks to commit, wants to commit changes, or invokes /commit.
disable-model-invocation: true
name: commit
---

# Commit

Create a well-formatted git commit. Follow the message format and ticket-extraction order in [`../../rules/commit.md`](../../rules/commit.md).

## Step 1 — Gather Context

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

When there are no staged changes and no unstaged changes, stop and tell the user there is nothing to commit.

## Step 2 — Determine Ticket and Message

Follow the ticket-extraction order in [`../../rules/commit.md`](../../rules/commit.md): explicit `${ARGUMENTS}` first, then current branch name, then most recent commits, then ask the user.

For the description:

- When provided in arguments, use it as-is (ensure it starts with an imperative verb).
- When not provided, analyze the staged and unstaged changes and generate a concise description starting with an imperative verb (`Add`, `Fix`, `Update`, `Remove`, `Refactor`).

## Step 3 — Stage Changes

When there are no staged changes but there are unstaged changes, show the list of changed files and ask: **"Stage all changes? (Y/n) or list specific files:"**

- When the user confirms, stage all relevant changes — exclude secret files per the guard in [`../../rules/commit.md`](../../rules/commit.md).
- When the user lists files, stage only those.

When there are already staged changes, use them as-is.

## Step 4 — Commit

Build the message following [`../../rules/commit.md`](../../rules/commit.md):

```
TICKET-000 Imperative verb description
```

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