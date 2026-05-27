---
allowed-tools: Bash(cat *) Bash(git branch *) Bash(git log *) Bash(git show *) Bash(test *) Read
argument-hint: "[summary or commit hash]"
description: Build the Jira REST `curl` command to file a Task (feature request) in the LPD project and print it for the user to run. Use when the user asks to file or create a feature request, propose a feature, open an LPD task for new work, or invokes /feature-request.
disable-model-invocation: true
name: feature-request
---

# File a Jira Feature Request in LPD

Construct the `curl` command that files a feature-request Task in the LPD Jira project and **print it for the user to run manually**. Do not invoke `curl`. Follow the conventions in [`../../rules/jira.md`](../../rules/jira.md) — auth, endpoint, project, issue type IDs, ADF skeleton, and the print-do-not-run execution model.

Filed as issue type **Task** (ID `10002`) — LPD's default for new feature work that is not already covered by an Epic or Story. The Task uses these description sections in order — Motivation, Description, Assumptions, Acceptance Criteria, Out of Scope, Reference (only when a commit was referenced).

## Step 1 — Verify Credentials

```bash
[ -n "${JIRA_API_USER}" ] && [ -n "${JIRA_API_TOKEN}" ] && echo "OK" || echo "MISSING"
```

When `MISSING`, instruct the user to export both environment variables and stop without printing any `curl` block.

## Step 2 — Gather Context

Parse `${ARGUMENTS}`:

- When it is a commit hash, run `git show <hash>` to understand existing work the request builds on.
- When it is a free-form summary, use it directly.

Determine the target Liferay version. Check in order:

1. `.liferay-workspace.json` — `version` field.
2. `gradle.properties` — `liferay.workspace.product`.
3. Ask the user.

## Step 3 — Collect Feature Details

Request any missing pieces from the user:

- **Summary** — concise one-line title.
- **Component** — affected Liferay module or feature area (Journal, Commerce, Objects, etc.).
- **Motivation** — why this is needed: user pain point, business case, or constraint that drives the request.
- **Description** — 2–3 paragraphs explaining the feature, its purpose, and how it fits into the existing product. Include user stories when applicable.
- **Assumptions** — what the request takes as given about the current system, user behavior, or dependencies.
- **Acceptance Criteria** — testable bullets that define "done".
- **Out of Scope** — things the request explicitly does not cover.
- **Priority** — `Highest`, `High`, `Medium` (default), `Low`, or `Lowest`. Map any user input like "high" / "medium" / "low" onto the closest Jira priority.

## Step 4 — Resolve the Component ID

Common LPD components:

- `Content Publishing > Resource Importer` → `15805`
- `Data Integration > Export/Import` → `16131`
- `Headless Batch Engine API` → `16022`

For others, **print the component-search `curl` command from [`../../rules/jira.md`](../../rules/jira.md)** for the user to run and pick an ID from the response. Do not invoke the search yourself.

## Step 5 — Build the Payload

Required fields for LPD feature-request tasks:

- **Project**: `LPD`
- **Issue Type**: `Task` (ID `10002`)
- **Component**: from Step 4
- **Priority**: from Step 3 (omit the field to accept the project default)
- **Summary**: from Step 3
- **Description**: ADF object built from the section list above

Tasks do not require Affects Version or Cross Cutting Properties.

Show the assembled JSON payload to the user and ask: **"Print the `curl` command? (Y/n)"**.

## Step 6 — Print the Command

Emit a single fenced `bash` block following the canonical command shape from [`../../rules/jira.md`](../../rules/jira.md). Use a `JIRA_PAYLOAD` heredoc to keep the `curl` flags sorted:

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

Stop after the block is printed. The user runs the command and reads the response — the new issue `key` is in the response JSON. Do not run the command, do not parse the response, and do not chain follow-up actions.