---
allowed-tools: Read Bash(curl *) Bash(git show *) Bash(git log *) Bash(git branch *) Bash(cat *) Bash(test *) Bash(python3 *)
argument-hint: "[commit hash or description]"
description: File a Jira bug ticket in the LPD project through the REST API. Use when the user asks to file or create a bug, report an issue, open an LPD bug, or invokes /bug.
disable-model-invocation: true
name: bug
---

# File a Jira Bug in LPD

Create a bug ticket in the LPD Jira project through the REST API, authenticating with `${JIRA_API_USER}` and `${JIRA_API_TOKEN}`.

## Step 1 — Verify credentials

```bash
[ -n "${JIRA_API_USER}" ] && [ -n "${JIRA_API_TOKEN}" ] && echo "OK" || echo "MISSING"
```

If `MISSING`, instruct the user to export both environment variables and stop.

## Step 2 — Gather context

Parse `${ARGUMENTS}`:

- If it is a commit hash, run `git show <hash>` to understand the fix and infer the bug.
- If it is a free-form description, use it directly.

Determine the Liferay version (used for the **Affects Version** field). Check in order:

1. `.liferay-workspace.json` — `version` field.
2. `gradle.properties` — `liferay.workspace.product`.
3. Ask the user.

When running inside a workspace git repository, also capture the current branch — useful as supplementary detail in the description:

```bash
git branch --show-current 2>/dev/null
```

## Step 3 — Collect bug details

Request any missing pieces from the user:

- **Summary** — concise title.
- **Steps to Reproduce** — clear, minimal steps.
- **Expected Behavior** — what should have happened.
- **Actual Behavior** — what happened instead.
- **Component** — affected Liferay module or feature area (e.g. Journal, Commerce, Objects).
- **Priority** — `Highest`, `High`, `Medium` (default), `Low`, or `Lowest`. Map any user input like "critical" / "major" / "minor" / "trivial" onto the closest Jira priority.

When the user supplies a stack trace or error message, include it verbatim in the **Actual Behavior** section.

## Step 4 — Resolve the component ID

Common LPD components (use the listed ID when one matches):

- `Content Publishing > Resource Importer` → `15805`
- `Data Integration > Export/Import` → `16131`
- `Headless Batch Engine API` → `16022`
- `Journal` → search dynamically (changes over time)
- `Object Definitions` → search dynamically

For anything not listed, search by keyword:

```bash
curl \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/project/LPD/components" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}" \
	| python3 -c "import json, sys; [print(f'{c[\"id\"]:>6} {c[\"name\"]}') for c in json.load(sys.stdin) if 'KEYWORD' in c['name'].lower()]"
```

Replace `KEYWORD` with a lowercase substring from the user's component answer.

## Step 5 — Resolve the affects version ID

For changes targeting the latest development branch, use `Master` (ID `16660`).

For a specific DXP release, search:

```bash
curl \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/project/LPD/versions" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}" \
	| python3 -c "import json, sys; [print(f'{v[\"id\"]:>6} {v[\"name\"]}') for v in json.load(sys.stdin) if 'KEYWORD' in v['name'].lower()]"
```

## Step 6 — Build the payload

Required fields for LPD bugs:

- **Project**: `LPD`
- **Issue Type**: `Bug` (ID `10004`)
- **Affects Version**: from Step 5
- **Cross Cutting Properties** (`customfield_10979`): `None` (ID `14468`) unless the user specifies otherwise
- **Component**: from Step 4
- **Priority**: from Step 3 (omit the field to accept the project default)
- **Summary**: from Step 3
- **Description**: ADF with sections in order — Description, Steps to Reproduce, Expected Behavior, Actual Behavior, Branch (only when running inside a workspace git repository), Fix (only when a commit was referenced)

Show the assembled JSON payload to the user and ask: **"File this ticket? (y/N)"**.

## Step 7 — Create the ticket

```bash
JIRA_PAYLOAD=$(cat <<'EOF'
{
  "fields": {
    "project": {"key": "LPD"},
    "issuetype": {"id": "10004"},
    "summary": "<summary>",
    "components": [{"id": "<component-id>"}],
    "versions": [{"id": "<version-id>"}],
    "customfield_10979": {"id": "14468"},
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

## Step 8 — Output

Parse the response for the issue `key` and report:

```
Ticket Created
==============

Key:    <KEY>
URL:    https://liferay.atlassian.net/browse/<KEY>
```
