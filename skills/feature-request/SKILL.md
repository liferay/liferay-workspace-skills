---
name: feature-request
description: Create a Jira feature request with description, Liferay version, assumptions, and acceptance criteria.
argument-hint: <summary of the feature>
disable-model-invocation: true
---

# Feature Request

Generate a structured Jira feature request ready to be filed.

## Step 1 — Gather context

Determine the Liferay version. Check in order:

1. Read `.liferay-workspace.json` — use `version` field
2. Read `gradle.properties` — extract from `liferay.workspace.product`
3. Ask the user

## Step 2 — Collect feature details

Parse `$ARGUMENTS` for the feature summary. If the arguments are sparse, ask the user for:

1. **Summary** — one-line description of the feature
2. **Component/Module** — which Liferay feature area this relates to
3. **Motivation** — why this feature is needed (user pain point, business case)

## Step 3 — Generate the ticket

Output the feature request in this format:

```
Feature Request
===============

Summary:     <concise one-line summary>
Component:   <Liferay module or feature area>
Target:      <Liferay DXP version>
Priority:    <High | Medium | Low>

Description:
  <2-3 paragraphs explaining the feature, its purpose, and how it fits
   into the existing product. Include user stories if applicable.>

Assumptions:
  - <assumption about the current system or user behavior>
  - <assumption about scope or limitations>
  - <assumption about dependencies or prerequisites>

Acceptance Criteria:
  - [ ] <specific, testable criterion>
  - [ ] <specific, testable criterion>
  - [ ] <specific, testable criterion>
  - [ ] <specific, testable criterion>

Out of Scope:
  - <anything explicitly not included in this request>

Additional Context:
  <mockups, references, related tickets, or technical notes>
```

## Step 4 — Confirm and refine

Ask the user: **"Anything to adjust before filing?"**

Apply any changes the user requests and re-display the final version.
