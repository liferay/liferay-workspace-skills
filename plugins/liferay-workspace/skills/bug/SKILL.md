---
allowed-tools: Bash(cat *) Bash(git branch *) Bash(git log *) Bash(git show *) Bash(test *) Read
argument-hint: "[commit hash or description]"
description: Build the Jira REST `curl` command to file a Bug in the LPD project and print it for the user to run. Use when the user asks to file or create a bug, report an issue, open an LPD bug, or invokes /bug.
disable-model-invocation: true
name: bug
---

# File a Jira Bug in LPD

Construct the `curl` command that files a Bug in the LPD Jira project and **print it for the user to run manually**. Do not invoke `curl`. Follow the conventions in [`../../rules/jira.md`](../../rules/jira.md) — auth, endpoint, project, issue type IDs, custom fields, ADF skeleton, and the print-do-not-run execution model.

The Bug uses these description sections in order — Description, Steps to Reproduce, Expected Behavior, Actual Behavior, Branch (only inside a workspace git repository), Fix (only when a commit was referenced).

## Step 1 — Verify Credentials

```bash
[ -n "${JIRA_API_USER}" ] && [ -n "${JIRA_API_TOKEN}" ] && echo "OK" || echo "MISSING"
```

When `MISSING`, instruct the user to export both environment variables and stop without printing any `curl` block.

## Step 2 — Gather Context

Parse `${ARGUMENTS}`:

- When it is a commit hash, run `git show <hash>` to understand the fix and infer the bug.
- When it is a free-form description, use it directly.

Determine the Liferay version (used for the **Affects Version** field). Check in order:

1. `.liferay-workspace.json` — `version` field.
2. `gradle.properties` — `liferay.workspace.product`.
3. Ask the user.

When running inside a workspace git repository, also capture the current branch — useful as supplementary detail in the description:

```bash
git branch --show-current 2>/dev/null
```

## Step 3 — Collect Bug Details

Request any missing pieces from the user:

- **Summary** — concise title.
- **Steps to Reproduce** — clear, minimal steps.
- **Expected Behavior** — what should have happened.
- **Actual Behavior** — what happened instead.
- **Component** — affected Liferay module or feature area (Journal, Commerce, Objects, etc.).
- **Priority** — `Highest`, `High`, `Medium` (default), `Low`, or `Lowest`. Map any user input like "critical" / "major" / "minor" / "trivial" onto the closest Jira priority.

When the user supplies a stack trace or error message, include it verbatim in the **Actual Behavior** section.

## Step 4 — Resolve the Component ID

Common LPD components (use the listed ID when one matches):

- `Content Publishing > Resource Importer` → `15805`
- `Data Integration > Export/Import` → `16131`
- `Headless Batch Engine API` → `16022`
- `Journal` → search dynamically (changes over time)
- `Object Definitions` → search dynamically

When the component is not in the list, **print the component-search `curl` command from [`../../rules/jira.md`](../../rules/jira.md)** for the user to run and pick an ID from the response. Do not invoke the search yourself.

## Step 5 — Resolve the Affects Version ID

For changes targeting the latest development branch, use **Master** (ID `16660`).

For a specific DXP release, **print the version-search `curl` command from [`../../rules/jira.md`](../../rules/jira.md)** for the user to run.

## Step 6 — Build the Payload

Required fields for LPD bugs:

- **Project**: `LPD`
- **Issue Type**: `Bug` (ID `10004`)
- **Affects Version**: from Step 5
- **Cross Cutting Properties** (`customfield_10979`): `None` (ID `14468`) unless the user specifies otherwise
- **Component**: from Step 4
- **Priority**: from Step 3 (omit the field to accept the project default)
- **Summary**: from Step 3
- **Description**: ADF object built from the section list above

Show the assembled JSON payload to the user and ask: **"Print the `curl` command? (Y/n)"**.

## Step 7 — Print the Command

Emit a single fenced `bash` block following the canonical command shape from [`../../rules/jira.md`](../../rules/jira.md). Use a `JIRA_PAYLOAD` heredoc to keep the `curl` flags sorted:

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

Stop after the block is printed. The user runs the command and reads the response — the new issue `key` is in the response JSON. Do not run the command, do not parse the response, and do not chain follow-up actions.