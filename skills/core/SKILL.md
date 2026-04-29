---
allowed-tools: Read Grep Glob Bash(bash scripts/rg-liferay.sh *) Bash(git -C *) Bash(cat *) Bash(ls *) Bash(find *)
argument-hint: <root-cause|guide> <query>
description: Search and analyze Liferay Portal source code. Modes — root-cause (investigate bugs from stack traces) or guide (understand a feature). Use when working with liferay-portal / liferay-portal-ee, or invoked via /core.
name: core
---

# Liferay Portal Source — Core Skill

You are working with a **large Liferay Portal monorepo** (~55k Java files). Every search must be targeted. Never search for common words like `String`, `Object`, `List`, `null`, `Exception`, `return`, or single-character tokens.

For detailed Liferay source structure, module conventions, and search strategies, see [liferay-patterns.md](liferay-patterns.md).

**Script usage:** `bash scripts/rg-liferay.sh [options] <pattern>` — pattern must be the **last** argument.

## Step 0 — Locate the portal source

Determine the portal source directory. Check in order:

1. Read `.liferay-workspace.json` — use `paths.source`
2. Read `.env.source` — use `LIFERAY_PORTAL_SOURCE`
3. Check if `../liferay-portal-ee` or `../liferay-portal` exists
4. Ask the user for the path

Store the resolved path as `$PORTAL_SRC` for all subsequent steps.

Verify the path: `[ -d "$PORTAL_SRC/portal-kernel" ] && echo "OK" || echo "NOT_FOUND"`

## Step 1 — Determine mode

Parse `$ARGUMENTS[0]` to select the mode:

- **`root-cause`** → go to [Root Cause Mode](#root-cause-mode). The rest of the arguments (`$ARGUMENTS` minus the mode) is the error, stack trace, or bug description.
- **`guide`** → go to [Guide Mode](#guide-mode). The rest of the arguments is the feature, module, or question to explore.
- **If neither is specified**, infer from the input: stack traces / error messages → root-cause; "how to", feature names, configuration questions → guide. If ambiguous, ask the user.

---

# Root Cause Mode

Identify the exact line of code or configuration responsible for a reported bug.

## RC-1 — Initial triage

Parse the query to extract actionable search tokens:

- **Stack trace**: extract the deepest Liferay class name and method (ignore Spring/OSGi/Tomcat frames). Use the fully qualified class name.
- **Error message**: extract the unique, specific portion (skip generic prefixes like `"com.liferay.portal.kernel.exception."`).
- **Bug description**: identify the Liferay feature area (e.g., "Journal", "User", "Commerce") and derive likely module names.

### RC-1a. Search for the error or class

Use the helper script with targeted parameters. Always pass `-d "$PORTAL_SRC"`.

```bash
# For a specific class name (e.g., JournalArticleLocalServiceImpl)
bash scripts/rg-liferay.sh -d "$PORTAL_SRC" -t java -n 10 "class JournalArticleLocalServiceImpl"

# For an error message (use the most specific substring)
bash scripts/rg-liferay.sh -d "$PORTAL_SRC" -n 20 "Specific error text here"
```

**Rules for searching:**
- Start with the most specific term (a unique class name, method, or error string)
- Never search the entire repo for patterns that match thousands of files
- If a class is found, note its **module path** (e.g., `modules/apps/journal/journal-service/`)
- If the first search returns too many results, narrow with `-m <module>` or `-t <type>`

### RC-1b. Identify the module

Once you find the class, determine its module:

```bash
bash scripts/rg-liferay.sh -d "$PORTAL_SRC" -t bnd -l "Bundle-SymbolicName:.*journal.service"
```

Or simply look at the directory path — the module is typically 2-3 levels up from `src/`.

## RC-2 — Context gathering

Now that you know the module, gather surrounding context. Read each file **only if it exists** — do not search globally for these.

### RC-2a. Module metadata

```bash
cat "$PORTAL_SRC/<module-path>/bnd.bnd"
[ -f "$PORTAL_SRC/<module-path>/service.xml" ] && echo "SERVICE_BUILDER=true"
```

### RC-2b. Service dependencies

```bash
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/<module-path>/src" -t java -n 30 "@Reference"
```

### RC-2c. Related configuration

```bash
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/<module-path>/src" -t java -n 10 "@Meta.OCD"
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/portal-impl/src" -t properties -n 15 "<component-keyword>"
```

### RC-2d. API contract (if investigating core APIs)

```bash
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/portal-kernel" -t java -n 5 "interface <ServiceName>"
bash scripts/rg-liferay.sh -d "$PORTAL_SRC" -t java -n 10 "implements <ServiceName>"
```

Check `portal-kernel`'s `bnd.bnd` for the exported package version if the bug involves API compatibility.

## RC-3 — Hypothesis testing

### RC-3a. Check for similar patterns elsewhere

```bash
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/modules/apps/<related-app>" -t java -n 15 "<pattern>"
```

If the pattern works elsewhere, the bug is **local**. If it fails everywhere, it may be **framework-level**.

### RC-3b. Check recent changes

```bash
git -C "$PORTAL_SRC" log --oneline -20 -- "<path-to-suspect-file>"
git -C "$PORTAL_SRC" log -p -5 -S "<method-name>" -- "<path-to-suspect-file>"
```

### RC-3c. Property / configuration defaults

```bash
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/portal-impl/src" -t properties -n 5 "<property.key>"
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/<module-path>" -t java -n 10 "<ConfigurationPID>"
```

## RC-4 — Findings report

```
Root Cause Analysis
===================

Bug:        <one-line summary of the reported issue>
Module:     <module path> (<Bundle-SymbolicName>)
File:       <exact file path relative to portal source>
Line:       <line number(s)>
Cause:      <concise explanation of why this code is wrong>

Evidence:
  - <what you found and how it leads to the bug>
  - <supporting context from dependencies, config, or related modules>

Scope:      Local | Global (does this affect other modules?)

Suggested Fix:
  <describe the code change needed — be specific about what to change and why>

Test Suites:
  - <which test class or suite validates this area>
  - <JUnit for unit, Integration for service-layer, Functional for UI>
```

---

# Guide Mode

Understand how to use a Liferay feature or module by reading the portal source code. Produce actionable usage instructions with concrete code/configuration snippets derived from the source — not from general knowledge.

## G-1 — Locate the feature

Parse the query to identify the feature area. Search for the relevant module:

```bash
# Find modules by keyword (e.g., "client-extension", "object-definition", "journal")
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/modules/apps" -t bnd -l -n 15 "<feature-keyword>"
```

If the feature involves core APIs, also check `portal-kernel`:

```bash
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/portal-kernel" -t java -n 10 "interface.*<FeatureName>"
```

Identify the module triplet when applicable: `*-api` (interfaces), `*-service` (implementation), `*-web` (UI).

## G-2 — Read the API contract

Once the module is found, read key files to understand the public API:

### G-2a. Interfaces and DTOs

Read interfaces from the `-api` module:

```bash
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/<module-api-path>/src" -t java -l -n 20 "public interface"
```

Then read the most relevant interface files directly with the Read tool.

### G-2b. Configuration shape

Find what's configurable — this is critical for questions about JSON structure, instance settings, or system settings:

```bash
# OSGi configuration interfaces (define what settings are available)
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/<module-path>/src" -t java -n 10 "@Meta.OCD"

# Read the configuration interface to see all @Meta.AD fields, defaults, and types
```

For Client Extension types, check the type definition:

```bash
# CET type interfaces define what properties each CX type supports
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/modules/apps/client-extension/client-extension-type-api" -t java -l "interface.*CET "
```

### G-2c. REST / Headless API shape

```bash
# Find OpenAPI specs
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/modules/apps/<module>" -n 1 "rest-openapi.yaml"

# Find resource implementations for endpoint behavior
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/modules/apps/<module>" -t java -l -n 10 "class.*ResourceImpl"
```

## G-3 — Find real usage examples

This is the most valuable step — find how the feature is actually used in the codebase.

### G-3a. Test classes (best source of usage patterns)

```bash
# Integration tests show real invocations with expected inputs/outputs
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/modules/apps/<module>/*-test" -t java -l -n 15 "<FeatureName>"

# Look for test methods that create/configure the feature
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/modules/apps/<module>/*-test" -t java -n 20 "public void test"
```

### G-3b. Sample workspace (especially for Client Extensions)

The `workspaces/liferay-sample-workspace/` directory contains official examples:

```bash
# List client extension samples
ls "$PORTAL_SRC/workspaces/liferay-sample-workspace/client-extensions/" 2>/dev/null

# Find sample client-extension.yaml files
find "$PORTAL_SRC/workspaces/liferay-sample-workspace/client-extensions" -name "client-extension.yaml" 2>/dev/null
```

Read the most relevant sample's `client-extension.yaml` and supporting files directly.

### G-3c. Internal consumers

Find how other modules use the feature internally:

```bash
# Who imports / references this service?
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/modules/apps" -t java -n 15 "@Reference.*<ServiceName>"

# Who calls a specific method?
bash scripts/rg-liferay.sh -d "$PORTAL_SRC/modules/apps" -t java -n 15 "<serviceName>\\.<methodName>"
```

### G-3d. JSON / data structure examples

For questions about JSON structure (batch engine data, configuration, REST payloads):

```bash
# Find JSON fixtures in tests
find "$PORTAL_SRC/modules/apps/<module>" -name "*.json" -not -path "*/build/*" 2>/dev/null | head -15

# Find batch-engine-data.json samples
find "$PORTAL_SRC/workspaces" -name "*.batch-engine-data.json" 2>/dev/null | head -10
```

Read the most relevant JSON files directly.

## G-4 — Usage report

Present findings as an actionable guide:

```
Usage Guide
===========

Feature:    <feature name>
Module:     <module path> (<Bundle-SymbolicName>)
API:        <key interface or service class>

How it works:
  <brief explanation of the feature's architecture — 2-3 sentences>

Configuration / Settings:
  <list of configurable properties with types and defaults, derived from @Meta.OCD or CET interfaces>

Code / JSON Example:
  <concrete snippet derived from source — tests, samples, or internal usage>
  <annotate each field/parameter with what it does, based on the source>

Source References:
  - <file path>:<line> — <what this file shows>
  - <file path>:<line> — <what this file shows>

Related:
  - <other modules/features that interact with this one>
  - <sample workspace path if applicable>
```

---

# Shared constraints

- **Never** search for generic terms: `String`, `Object`, `null`, `List`, `Map`, `Exception`, `return`, `this`, `new`, `import`, `public`, `private`, `void`
- **Always** scope searches to a specific directory or module when possible
- **Limit** results (`-n` flag) — if you get 40+ matches, narrow the search before reading results
- **Read** files directly (with the Read tool) once you know the exact path — don't grep for content you can just open
- If investigating a `portal-kernel` API issue, always check the kernel version in its `bnd.bnd`
- For Service Builder modules, always check `service.xml` and the generated `*ModelImpl` before drawing conclusions
- Derive all code examples and JSON structures from **actual source code** — do not fabricate snippets from general knowledge
