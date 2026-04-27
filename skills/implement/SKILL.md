---
argument-hint: <ticket or description of what to implement>
description: Implement a feature or fix in the Liferay Workspace based on a plan or ticket description. Use when the user asks to implement, build, or code a ticket, or invokes /implement.
disable-model-invocation: true
name: implement
---

# Implement

Execute an implementation based on a plan or ticket description.

## Step 1 — Locate the plan

Check if a plan was previously created in this conversation. If so, use it.

If no plan exists:

- Parse `$ARGUMENTS` for context (ticket ID, description).
- Ask the user: **"No plan found. Should I create one first with `/plan`, or proceed directly?"**
- If proceeding directly, do a quick analysis of what needs to be done before writing code.

## Step 2 — Understand the workspace

Read the workspace structure:

```bash
cat .liferay-workspace.json 2>/dev/null
```

```bash
ls modules/ client-extensions/ themes/ 2>/dev/null
```

```bash
cat gradle.properties
```

Identify:
- Workspace mode (Docker or Source)
- Liferay version
- Existing modules and client extensions

## Step 3 — Implement

Follow the plan steps (or your analysis) and implement the changes:

- **Create or modify files** as needed — Java classes, JSPs, React components, configuration files, `service.xml`, `build.gradle`, etc.
- **Follow Liferay conventions** — package naming (`com.liferay.<module>`), Service Builder patterns, OSGi component annotations, MVC portlet structure.
- **Use the portal source** as reference when needed — invoke `liferay-workspace:core guide <feature>` to look up APIs, patterns, or configuration shapes.

After each significant change, verify it compiles:

```bash
./gradlew -p <module-path> classes 2>&1 | tail -20
```

## Step 4 — Build and deploy

Once implementation is complete:

```bash
./gradlew -p <module-path> deploy
```

If multiple modules were changed, deploy each one.

Report the result of each deploy as done or failed.

## Step 5 — Summary

```
Implementation Summary
======================

Ticket:    <TICKET-000 or N/A>

Changes:
  - <file path> — <what was done>
  - <file path> — <what was done>

Build:     <passed | failed>
Deploy:    <deployed | failed>

Next Steps:
  - <manual testing instructions>
  - <run /commit to commit the changes>
  - <run /pr to create a pull request>
```
