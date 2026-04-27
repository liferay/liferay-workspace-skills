---
allowed-tools: Read Bash(git branch *) Bash(cat *)
argument-hint: <summary of the bug>
description: Create a Jira bug ticket with structured fields — description, steps to reproduce, Liferay version, actual/expected results. Use when the user asks to file a bug, report an issue, or invokes /bug.
disable-model-invocation: true
name: bug
---

# Bug Report

Generate a structured Jira bug ticket ready to be filed.

## Step 1 — Gather context

Determine the Liferay version. Check in order:

1. Read `.liferay-workspace.json` — use `version` field
2. Read `gradle.properties` — extract from `liferay.workspace.product`
3. Ask the user

If running in a workspace with git, also collect:

```bash
git branch --show-current
```

## Step 2 — Collect bug details

Parse `$ARGUMENTS` for the bug summary. If the arguments are sparse, ask the user for clarification on:

1. **Summary** — one-line description of the issue
2. **Component/Module** — which Liferay feature area is affected (e.g. Journal, Commerce, Objects)
3. **Steps to reproduce** — if not obvious from context, ask

If the user provides a stack trace or error message, include it in the description.

## Step 3 — Generate the ticket

Output the bug report in this format:

```
Bug Report
==========

Summary:     <concise one-line summary>
Component:   <Liferay module or feature area>
Affects:     <Liferay DXP version>
Severity:    <Critical | Major | Minor | Trivial>
Branch:      <current git branch, if applicable>

Description:
  <2-3 sentences explaining the issue and its impact>

Steps to Reproduce:
  1. <step>
  2. <step>
  3. <step>

Actual Result:
  <what currently happens>

Expected Result:
  <what should happen instead>

Additional Context:
  <stack traces, error messages, screenshots, logs, or configuration details>
```

## Step 4 — Confirm and refine

Ask the user: **"Anything to adjust before filing?"**

Apply any changes the user requests and re-display the final version.
