---
allowed-tools: Read Bash(curl *) Bash(git show *) Bash(git log *) Bash(git branch *) Bash(cat *) Bash(test *) Bash(python3 *)
argument-hint: "[summary or commit hash]"
description: File a Jira feature request in the LPD project through the REST API. Use when the user asks to file or create a feature request, propose a feature, open an LPD task for new work, or invokes /feature-request.
disable-model-invocation: true
name: feature-request
---

# File a Jira Feature Request in LPD

Create a feature-request ticket in the LPD Jira project through the REST API, authenticating with `${JIRA_API_USER}` and `${JIRA_API_TOKEN}`. Filed as issue type **Task** (LPD's default for new feature work that is not already covered by an Epic / Story).

## Step 1 — Verify credentials

```bash
[ -n "${JIRA_API_USER}" ] && [ -n "${JIRA_API_TOKEN}" ] && echo "OK" || echo "MISSING"
```

If `MISSING`, instruct the user to export both environment variables and stop.

## Step 2 — Gather context

Parse `${ARGUMENTS}`:

- If it is a commit hash, run `git show <hash>` to understand existing work the request builds on.
- If it is a free-form summary, use it directly.

Determine the target Liferay version. Check in order:

1. `.liferay-workspace.json` — `version` field.
2. `gradle.properties` — `liferay.workspace.product`.
3. Ask the user.

## Step 3 — Collect feature details

Request any missing pieces from the user:

- **Summary** — concise one-line title.
- **Component** — affected Liferay module or feature area (e.g. Journal, Commerce, Objects).
- **Motivation** — why this is needed: user pain point, business case, or constraint that drives the request.
- **Description** — 2–3 paragraphs explaining the feature, its purpose, and how it fits into the existing product. Include user stories when applicable.
- **Assumptions** — what the request takes as given about the current system, user behavior, or dependencies.
- **Acceptance Criteria** — testable bullets that define "done".
- **Out of Scope** — things the request explicitly does **not** cover.
- **Priority** — `Highest`, `High`, `Medium` (default), `Low`, or `Lowest`. Map any user input like "high" / "medium" / "low" onto the closest Jira priority.

## Step 4 — Resolve the component ID

Common LPD components:

- `Content Publishing > Resource Importer` → `15805`
- `Data Integration > Export/Import` → `16131`
- `Headless Batch Engine API` → `16022`

For others, search by keyword:

```bash
curl \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/project/LPD/components" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}" \
	| python3 -c "import json, sys; [print(f'{c[\"id\"]:>6} {c[\"name\"]}') for c in json.load(sys.stdin) if 'KEYWORD' in c['name'].lower()]"
```

## Step 5 — Build the payload

Required fields for LPD feature-request tasks:

- **Project**: `LPD`
- **Issue Type**: `Task` (ID `10002`)
- **Component**: from Step 4
- **Priority**: from Step 3 (omit the field to accept the project default)
- **Summary**: from Step 3
- **Description**: ADF with sections in order — Motivation, Description, Assumptions, Acceptance Criteria, Out of Scope, Reference (only when a commit was referenced)

Tasks do **not** require Affects Version or Cross Cutting Properties.

Show the assembled JSON payload to the user and ask: **"File this ticket? (y/N)"**.

## Step 6 — Create the ticket

```bash
JIRA_PAYLOAD=$(cat <<'EOF'
{
  "fields": {
    "project": {"key": "LPD"},
    "issuetype": {"id": "10002"},
    "summary": "<summary>",
    "components": [{"id": "<component-id>"}],
    "priority": {"name": "<priority>"},
    "description": <ADF object>
  }
}
EOF
)

curl \
	--data "${JIRA_PAYLOAD}" \
	--header "Content-Type: application/json" \
	--request POST \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/issue" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}"
```

## Step 7 — Output

Parse the response for the issue `key` and report:

```
Ticket Created
==============

Key:    <KEY>
Type:   Feature Request (Task)
URL:    https://liferay.atlassian.net/browse/<KEY>
```
