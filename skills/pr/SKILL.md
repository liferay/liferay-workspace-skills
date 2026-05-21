---
allowed-tools: Bash(basename *) Bash(cat *) Bash(gh *) Bash(git *) Bash(grep *) Bash(test *) Glob Grep Read
argument-hint: [TICKET-000]
description: Create a GitHub pull request with a structured description, then print the Jira `curl` commands for the user to run manually. Use when the user asks to send/open a PR, create a pull request, or invokes /pr.
disable-model-invocation: true
name: pr
---

# Pull Request

Create a GitHub pull request, then **print** the Jira `curl` commands that transition the linked ticket to review and record the PR URL. The skill runs `gh pr create` directly; all Jira REST calls are printed for the user to run manually. Follow the conventions in [`../../rules/jira.md`](../../rules/jira.md) for the Jira side and [`../../rules/commit.md`](../../rules/commit.md) for the PR title format.

When the repository carries a `.github/CODEOWNERS` file with `@liferay-*` handles (the convention used by `liferay-portal` and `liferay-portal-ee`), the PR is routed to the owning team's fork rather than to upstream `liferay/<repo>`. Follow [`../../rules/codeowners.md`](../../rules/codeowners.md) for owner resolution, fork detection, and the cross-repository `gh pr create` invocation. The steps below mark every place where the routing branch applies.

## Step 1 — Gather Context

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

When the current branch is the base branch, stop and tell the user to create a feature branch first.

Detect whether fork routing applies (see [`../../rules/codeowners.md`](../../rules/codeowners.md)):

```bash
test -f .github/CODEOWNERS && grep --quiet '@liferay-' .github/CODEOWNERS && echo "ROUTING" || echo "DEFAULT"
```

When the result is `ROUTING`, treat the rest of this skill as the routed variant: resolve the owning team in Step 3, push to the user's fork remote in Step 4, and use the cross-repository `gh pr create` form in Step 5. When the result is `DEFAULT`, keep the original behavior in every later step.

## Step 2 — Determine Ticket

Follow the ticket-extraction order in [`../../rules/commit.md`](../../rules/commit.md): explicit `${ARGUMENTS}` first, then branch name (`feature/LPD-12345-description` → `LPD-12345`), then ask the user.

Construct the Jira URL: `https://liferay.atlassian.net/browse/<TICKET>`.

## Step 3 — Analyze Changes

Get the full diff against the base branch:

```bash
git log --oneline <base-branch>..HEAD
```

```bash
git diff <base-branch>...HEAD --stat
```

Read the changed files to understand what was done and categorize the changes (new features, bug fixes, refactors, config changes, etc.).

### Routed Variant — Resolve the Owning Team

When Step 1 reported `ROUTING`, also list the changed file paths and resolve them against `.github/CODEOWNERS` following the algorithm in [`../../rules/codeowners.md`](../../rules/codeowners.md):

```bash
git diff \
	--name-only \
	"<base-branch>...HEAD"
```

Walk every non-comment, non-blank line of `.github/CODEOWNERS` and keep the **last** matching prefix per file (last-match-wins). Aggregate the per-team file counts and present the breakdown to the user, for example:

```
@liferay-bpm: 4 files
@liferay-content-management: 1 file
(no owner): 2 files — modules/apps/archived/foo.java, modules/apps/counter/bar.java
```

1. **Single owner across all owned files** — use it without prompting.

1. **Multiple owners** — present the breakdown and use `AskUserQuestion` to let the user pick a single target team. Do not auto-pick the team with the most files.

1. **All files lack an owner** — use `AskUserQuestion` to let the user pick a target team from the table in [`../../rules/codeowners.md`](../../rules/codeowners.md), or fall back to upstream `liferay/<repo>`.

Record the resolved `<team-organization>` (for example, `liferay-bpm`) for Step 4 and Step 5. Derive the repository name from the upstream remote:

```bash
basename "$(git config --get remote.origin.url)" .git
```

## Step 4 — Ensure Remote Is Up to Date

Check whether the branch is pushed:

```bash
git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null
```

### Default Variant

When the branch is not tracking a remote or has unpushed commits, push to `origin`:

```bash
git push \
	--set-upstream origin HEAD
```

### Routed Variant

When Step 1 reported `ROUTING`, the branch must live on the user's personal fork — never on `origin` (which is upstream `liferay/<repo>`) and never on a team remote. Resolve the fork remote following [`../../rules/codeowners.md`](../../rules/codeowners.md):

```bash
git remote --verbose
```

Scan for a remote whose URL points to `<organization>/<repo-name>` where the organization is neither `liferay` nor any `liferay-*` handle from the team table in [`../../rules/codeowners.md`](../../rules/codeowners.md). When exactly one matches, push to it. When several match, use `AskUserQuestion` to let the user pick. When none match, stop and tell the user to add a personal fork remote (for example, `git remote add myfork git@github.com:<user>/<repo>.git`).

```bash
git push \
	--set-upstream <fork-remote> HEAD
```

Record `<user-organization>` (derived from the fork remote URL) for Step 5.

## Step 5 — Create the PR

The PR title follows the commit convention from [`../../rules/commit.md`](../../rules/commit.md): `TICKET-000 Imperative verb description`.

Build the body once, then run the variant that matches Step 1's detection result:

```bash
PR_BODY=$(cat <<'EOF'
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
)
```

### Default Variant

```bash
gh pr create \
	--body "${PR_BODY}" \
	--title "<TICKET-000 Imperative verb description>"
```

### Routed Variant

Use the team organization resolved in Step 3, the user fork organization resolved in Step 4, and the repository name from `basename`. The base branch is always `master` for `liferay-portal` and `liferay-portal-ee`.

```bash
gh pr create \
	--base master \
	--body "${PR_BODY}" \
	--head "<user-organization>:<branch>" \
	--repo "<team-organization>/<repo-name>" \
	--title "<TICKET-000 Imperative verb description>"
```

Capture the resulting PR URL from `gh`'s output. It is needed for Step 6c.

## Step 6 — Print Jira Updates

Follow the print-do-not-run model from [`../../rules/jira.md`](../../rules/jira.md). When `${JIRA_API_USER}` and `${JIRA_API_TOKEN}` are not set, skip this step entirely and note "Jira: skipped (missing credentials)" in Step 7. When set, print the commands below for the user to run.

### 6a. Resolve the Target Ticket

Print the issue-fetch command from [`../../rules/jira.md`](../../rules/jira.md):

```bash
curl \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/issue/<TICKET>?fields=issuetype,subtasks,status" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}"
```

Tell the user: the **target** is the ticket that owns the PR field and review state. For a **Bug**, the bug is the target. For a **Task** or **Story**, the **Technical Task** subtask is the target — use its key in the commands below. Reference the target-resolution rule and transition table in [`../../rules/jira.md`](../../rules/jira.md).

### 6b. Transition to Review

Pick the transition ID from the table in [`../../rules/jira.md`](../../rules/jira.md): Bug → In Review uses `71`; Technical Task → In Peer Review uses `31`. Print the transition command for the user:

```bash
curl \
	--data '{"transition": {"id": "<71 for Bug | 31 for Technical Task>"}}' \
	--header "Content-Type: application/json" \
	--request POST \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/issue/<TARGET>/transitions" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}"
```

When the target is not already In Progress, the user must first run the In-Progress transition (`61` for Bug, `41` for Technical Task) — also documented in [`../../rules/jira.md`](../../rules/jira.md). Note this in the printed instructions when the fetched status is not in an in-progress state.

### 6c. Set the Git Pull Request Field

`customfield_10201` holds the PR URL. Substitute the PR URL captured in Step 5:

```bash
curl \
	--data '{"fields": {"customfield_10201": "<PR-URL>"}}' \
	--header "Content-Type: application/json" \
	--request PUT \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/issue/<TARGET>" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}"
```

## Step 7 — Report

Show the PR URL and a summary:

```
Pull Request Created
====================

PR:           <URL>
Ticket:       <Jira URL>
Target:       <target ticket key — same as ticket for Bug, Technical Task subtask for Task/Story>
Title:        <PR title>
Base:         <base branch>
Branch:       <feature branch>
Commits:      <number of commits>
Routing:      default | routed
Target Repo:  <team-organization/repo-name>     (routed only)
Owner Team:   @liferay-<team>                   (routed only)
Jira:         curl commands printed above | skipped (missing credentials)
```