---
name: plan
description: Create an implementation plan for a Liferay feature or fix — analyze requirements, identify affected modules, and outline steps.
argument-hint: <ticket or description of what to implement>
disable-model-invocation: true
---

# Plan

Create a detailed implementation plan before writing code.

## Step 1 — Understand the requirement

Parse `$ARGUMENTS` for a ticket ID or description. Gather context:

- If a ticket ID is given, ask the user for the ticket details (summary, description, acceptance criteria) or use what's been shared in conversation.
- If a description is given, use it directly.

Read relevant workspace files to understand the current state:

```bash
ls modules/ client-extensions/ 2>/dev/null
```

```bash
cat .liferay-workspace.json 2>/dev/null
```

## Step 2 — Analyze scope

Identify:

1. **Which modules are affected** — existing modules to modify, new modules to create
2. **Which layers are involved** — service (backend), web (frontend), API, configuration
3. **Dependencies** — other modules, external services, Liferay APIs
4. **Risks** — breaking changes, performance concerns, migration needs

If the task involves Liferay Portal source code, invoke `liferay-workspace:core guide <feature>` to understand the relevant APIs.

## Step 3 — Generate the plan

Output the implementation plan:

```
Implementation Plan
===================

Ticket:      <TICKET-000 or N/A>
Summary:     <one-line description>
Complexity:  <Low | Medium | High>

Overview:
  <2-3 sentences describing the approach at a high level>

Affected Modules:
  - <module path> — <what changes here>
  - <module path> — <what changes here>

Steps:
  1. <step with specific files/classes to create or modify>
  2. <step>
  3. <step>
  ...

Testing Strategy:
  - Unit: <what to test with JUnit>
  - Integration: <what to test with integration tests>
  - Manual: <manual verification steps>

Risks & Considerations:
  - <risk and mitigation>
  - <risk and mitigation>

Open Questions:
  - <anything that needs clarification before starting>
```

## Step 4 — Confirm

Ask the user: **"Ready to proceed, or any adjustments?"**

Apply any changes and re-display. Once confirmed, the plan is ready to be used with `/implement`.
