---
allowed-tools: Read Glob Grep Bash(git *) Bash(gh *) Bash(curl *) Bash(test *) Bash(python3 *)
argument-hint: [TICKET-000]
description: Create a GitHub pull request with a structured description including Jira ticket link. Use when the user asks to send/open a PR, create a pull request, or invokes /pr.
disable-model-invocation: true
name: pr
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

## Step 6 — Update Jira

When `${JIRA_API_USER}` and `${JIRA_API_TOKEN}` are set, transition the linked ticket to review and record the PR URL on the ticket. When the credentials are missing, skip this step and report it in Step 7.

```bash
[ -n "${JIRA_API_USER}" ] && [ -n "${JIRA_API_TOKEN}" ] && echo "OK" || echo "MISSING"
```

### 6a. Resolve the target ticket

Different Liferay issue types have different workflows. Fetch the ticket type and subtasks first:

```bash
curl \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/issue/<TICKET>?fields=issuetype,subtasks,status" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}"
```

Resolve the **target** — the ticket that owns the PR field and review state:

- **Bug** (issuetype ID `10004`) → the bug itself is the target.
- **Task** (issuetype ID `10002`) or **Story** (issuetype ID `10001`) → locate the **Technical Task** subtask (issuetype ID `10153`) and use its key as the target.
- **Technical Task** (issuetype ID `10153`) → use it directly.

If the parent is a Task or Story and no Technical Task subtask exists, ask the user whether to fall back to updating the parent directly.

### 6b. Ensure the target is In Progress

Read `status.name` from the response in Step 6a. When it is not already an in-progress state, transition first. Transition IDs depend on issue type:

- **Bug**: `61` (To Do → In Progress).
- **Technical Task**: `41` (Open → In Progress).

```bash
curl \
	--data '{"transition": {"id": "<61-for-bug|41-for-tech-task>"}}' \
	--header "Content-Type: application/json" \
	--request POST \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/issue/<TARGET>/transitions" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}"
```

### 6c. Transition to review

Transition IDs depend on issue type:

- **Bug** → **In Review**, transition ID `71`.
- **Technical Task** (or one resolved from a Task/Story) → **In Peer Review**, transition ID `31`.

```bash
curl \
	--data '{"transition": {"id": "<71-for-bug|31-for-tech-task>"}}' \
	--header "Content-Type: application/json" \
	--request POST \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/issue/<TARGET>/transitions" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}"
```

When the transition fails because the ticket is already in a later status (HTTP 400 with `Transition is not valid`), continue to Step 6d anyway.

### 6d. Set the Git Pull Request field

`customfield_10201` is the **Git Pull Request** text field on LPD tickets:

```bash
curl \
	--data '{"fields": {"customfield_10201": "<PR-URL>"}}' \
	--header "Content-Type: application/json" \
	--request PUT \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/issue/<TARGET>" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}"
```

### 6e. Verify

Refetch the ticket to confirm the new status and PR URL:

```bash
curl \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/issue/<TARGET>?fields=status,customfield_10201" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}"
```

## Step 7 — Report

Show the PR URL and a summary:

```
Pull Request Created
====================

PR:        <URL>
Ticket:    <Jira URL>
Target:    <target ticket key — same as ticket for Bug, Technical Task subtask for Task/Story>
Title:     <PR title>
Base:      <base branch>
Branch:    <feature branch>
Commits:   <number of commits>
Jira:      transitioned to <status> | skipped (missing credentials) | already in <status>
PR Field:  set | failed
```
