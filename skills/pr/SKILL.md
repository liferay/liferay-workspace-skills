---
name: pr
description: Create a GitHub pull request with a structured description including Jira ticket link.
disable-model-invocation: true
---

# Pull Request

Create a GitHub pull request with a structured description linked to a Jira ticket.

## Step 1 — Gather context

Run in parallel:

```bash
git status
```

```bash
git branch --show-current
```

```bash
git log --oneline -20
```

```bash
cat .liferay-workspace.json 2>/dev/null
```

Also determine the base branch:

```bash
git remote show origin 2>/dev/null | grep "HEAD branch" | sed 's/.*: //'
```

If the current branch is the base branch, stop and tell the user to create a feature branch first.

## Step 2 — Determine ticket

Parse `$ARGUMENTS` for a ticket ID (pattern: `UPPERCASE-DIGITS`).

If not found, check the branch name for a ticket pattern (e.g. `feature/LPD-12345-description`).

If still not found, ask the user for the Jira ticket ID.

Construct the Jira URL: `https://liferay.atlassian.net/browse/TICKET-000`

## Step 3 — Analyze changes

Get the full diff against the base branch:

```bash
git log --oneline <base-branch>..HEAD
```

```bash
git diff <base-branch>...HEAD --stat
```

Read the changed files to understand what was done. Categorize the changes:
- New features, bug fixes, refactors, config changes, etc.

## Step 4 — Ensure remote is up to date

Check if the branch has been pushed:

```bash
git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null
```

If not tracking a remote branch, or if there are unpushed commits:

```bash
git push -u origin HEAD
```

## Step 5 — Create the PR

Generate the PR using `gh`:

```bash
gh pr create --title "<TICKET-000 Imperative verb description>" --body "$(cat <<'EOF'
## Jira

<Jira ticket URL>

## Summary

<2-4 bullet points describing the changes>

## Changes

- <file or module> — <what changed>
- <file or module> — <what changed>

## Test Plan

- [ ] <manual or automated test step>
- [ ] <manual or automated test step>
- [ ] <manual or automated test step>
EOF
)"
```

PR title follows the same convention as commits: `TICKET-000 Imperative verb description`.

## Step 6 — Report

Show the PR URL and a summary:

```
Pull Request Created
====================

PR:       <URL>
Ticket:   <Jira URL>
Title:    <PR title>
Base:     <base branch>
Branch:   <feature branch>
Commits:  <number of commits>
```
