---

paths:
  - "skills/pr-review/**/*.md"

---

# Jira REST API

All Jira interactions go through the Jira Cloud REST API at `liferay.atlassian.net` using `curl`. Do not use Atlassian MCP tools, Jira CLI wrappers, or any other Jira integration. Every Jira read or write must be a `curl` call against the REST API.

## Execution Model — Print, Do Not Run

Skills under this plugin construct the `curl` command and **print it to the chat for the user to run manually**. Skills do not invoke `curl` themselves. Rationale:

- Keeps `${JIRA_API_USER}` and `${JIRA_API_TOKEN}` out of the tool-call stream.
- Lets the user inspect ADF JSON and field IDs before any network call.
- Removes `Bash(curl *)` from skill `allowed-tools`, reducing permission prompts.
- The user can edit fields (component ID, version, summary, payload) before running.

The skill flow ends when the command block is printed. The skill does not parse a response, chain follow-up requests, or branch on success/failure. Any follow-up action the user wants triggers a fresh skill invocation.

## Authentication

Authenticate every request with the `${JIRA_API_USER}` and `${JIRA_API_TOKEN}` environment variables. With `curl`, pass them through the `--user` flag:

```bash
curl \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/<endpoint>" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}"
```

When a skill needs to know whether the credentials exist before constructing the command, run:

```bash
[ -n "${JIRA_API_USER}" ] && [ -n "${JIRA_API_TOKEN}" ] && echo "OK" || echo "MISSING"
```

When `MISSING`, the skill instructs the user to export both variables and stops without printing any `curl` block.

## Project

All issues live in the **LPD** project (Liferay Product Development).

## Issue Types

| Name | ID |
| --- | --- |
| Bug | `10004` |
| Story | `10001` |
| Task | `10002` |
| Technical Task | `10153` |

## Transitions

| From Type | To State | Transition ID |
| --- | --- | --- |
| Bug | In Progress | `61` |
| Bug | In Review | `71` |
| Technical Task | In Progress | `41` |
| Technical Task | In Peer Review | `31` |
| Story | Ready for Development | `41` |
| Story | In Development | `61` |
| Task | In Progress | `21` |

When a transition fails because the ticket is already in a later state (HTTP 400 with `Transition is not valid`), the user can ignore and proceed with the next step.

## Custom Fields

| Field | ID | Notes |
| --- | --- | --- |
| Git Pull Request | `customfield_10201` | Plain text URL — set after the PR is created |
| Cross Cutting Properties | `customfield_10979` | Defaults to None (option ID `14468`) for bugs |

## Affects Version

For Bugs targeting the latest development branch, use **Master** (ID `16660`). For a specific DXP release, search for the version by name first (see "Version Search" below).

## Component Search

```bash
curl \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/project/LPD/components" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}"
```

Filter the response by name on the user's side (or with `jq` / `python3 -c '...'`) — the skill must not invoke this; print it for the user.

## Version Search

```bash
curl \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/project/LPD/versions" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}"
```

## Target Resolution

For a **Bug**, the bug is the target. For a **Task** or **Story** with a **Technical Task** subtask, the **Technical Task** is the target — apply transitions and write `customfield_10201` to the subtask, not the parent. When no Technical Task subtask exists, ask the user whether to fall back to updating the parent directly.

To fetch the issue type and subtasks:

```bash
curl \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/issue/<TICKET>?fields=issuetype,subtasks,status" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}"
```

## Canonical Command Shape

Skills must print the `curl` command inside a fenced `bash` block. When the payload is multi-line, lift it into a `JIRA_PAYLOAD` heredoc so the `curl` invocation keeps its sorted long-form flags. The user copies the block and runs it.

```bash
JIRA_PAYLOAD=$(cat <<'EOF'
{
	"fields": {
		"project": {"key": "LPD"},
		"issuetype": {"id": "10004"},
		"summary": "<summary>",
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

For a transition:

```bash
curl \
	--data '{"transition": {"id": "<ID>"}}' \
	--header "Content-Type: application/json" \
	--request POST \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/issue/<TARGET>/transitions" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}"
```

For a field update:

```bash
curl \
	--data '{"fields": {"customfield_10201": "<PR-URL>"}}' \
	--header "Content-Type: application/json" \
	--request PUT \
	--silent \
	--url "https://liferay.atlassian.net/rest/api/3/issue/<TARGET>" \
	--user "${JIRA_API_USER}:${JIRA_API_TOKEN}"
```

## ADF Skeleton

Descriptions are Atlassian Document Format. Minimal shape:

```json
{
	"type": "doc",
	"version": 1,
	"content": [
		{
			"type": "heading",
			"attrs": {"level": 2},
			"content": [{"type": "text", "text": "<Section Title>"}]
		},
		{
			"type": "paragraph",
			"content": [{"type": "text", "text": "<Section body>"}]
		}
	]
}
```

Each section heading is `level: 2`. Body paragraphs follow. Code blocks use `"type": "codeBlock"` with an `"attrs": {"language": "<lang>"}` element. Bullet lists use `"type": "bulletList"` with `"listItem"` children.