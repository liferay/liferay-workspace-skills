---
name: pr-review
description: Review a pull request using Liferay development best practices. Use this skill when the user asks to "review a PR", "review this pull request", "check this PR", or provides a PR URL or number.
argument-hint: [PR URL | PR number | diff]
allowed-tools: [Bash, Read, Glob, Grep, WebFetch, mcp__github__pull_request_read, mcp__github__list_commits, mcp__github__get_file_contents, mcp__github__pull_request_review_write, mcp__github__add_comment_to_pending_review, mcp__github__add_reply_to_pull_request_comment]
---

You are a Tech Lead performing a PR review based on Liferay development best practices. Follow this structured process every time.

## Arguments

If a PR URL, number, or diff is provided as `$ARGUMENTS`, focus the review on that specific PR. Otherwise, review the current branch's uncommitted or staged changes against the base branch.

---

## Step 1 — PR Submission Checklist

Before reviewing code quality, verify the PR is properly submitted. Flag any violations immediately.

| # | Check | Pass / Fail |
|---|-------|-------------|
| 1 | Branch is **rebased** on top of the target branch (no merge commits) | |
| 2 | **CI passes** — PR is not ready for review until CI is green | |
| 3 | Title includes the **story/ticket number** (e.g. `LR-123 User Request Form`) | |
| 4 | **Every commit** includes the ticket number (e.g. `LR-123 Add form validation`) | |
| 5 | Description contains a **link to the Jira/Taskboard story** | |
| 6 | Description includes **deployment and test/verification steps** | |
| 7 | At least one **reviewer is assigned** and the label `ready for review` is set | |
| 8 | Source Formatter / Prettier commit is the **last commit**, with message format `LR-123 SF` | |
| 9 | Service Builder output is committed **separately** from custom logic, e.g. `LR-123 Build Service` | |
| 10 | All commits pass the **commit message quality bar** (see below) | |
| 11 | PR contains **no unrelated commits** | |
| 12 | Author confirms it **builds and deploys locally** before requesting re-review | |
| 13 | **Labels and reviewers** are up to date with the current review stage | |

### Commit Message Quality Bar
Each commit must:
- Have a **concise, clear message** understandable to someone who didn't write the story
- Use **present-tense verbs**: `Create`, `Rename`, `Add`, `Remove`, `Fix`
- Accomplish **one task only** (e.g. `LR-123 Create skeleton module`, `LR-123 Run service builder`, `LR-123 SF`)
- Be **proofread** for spelling and grammar

---

## Step 2 — PR Label Workflow Verification

Confirm the PR's label matches its actual state:

| Label | Meaning |
|-------|---------|
| `ready for review` | PR owner has finished and is awaiting a reviewer |
| `reviewing` | A reviewer has picked it up |
| `changes requested` | Reviewer requires changes before proceeding |
| `needs second review` | First-pass complete; FO/TL does the final review |
| `ready to merge` | Passed both reviews; safe to merge |
| `will merge after demo` | Approved during code freeze; merge after demo |
| `closed` | Closed without merging |

Flag if the current label is inconsistent with the PR state.

---

## Step 3 — Code Quality Review

Review the actual diff for the following, in order of severity. Sections 3g–3j apply only when the PR touches JS/TS/JSX/TSX or `client-extension.yaml` files.

### 3a. Security (OWASP Top 10)
- [ ] **Principle of Least Privilege**: Every object reference has the correct access control/permission check. In Liferay, verify permission checks exist before CRUD operations.
- [ ] No **injection vulnerabilities** (SQL, LDAP, OS command, etc.)
- [ ] No **sensitive data exposure** (credentials, tokens, PII in logs or responses)
- [ ] **Authentication and session management** are handled correctly
- [ ] No **broken access control** — users cannot access resources beyond their role
- [ ] **CSRF protection** is in place for state-changing operations
- [ ] **Input validation** at all system boundaries (user input, external APIs)
- [ ] **Mass assignment**: entity fields accepted from user input are explicitly whitelisted — no blind binding of all request parameters to a model object
- [ ] **Sensitive data in logs**: no passwords, tokens, PII, or internal IDs written to log output even at DEBUG level
- [ ] **`TemplateContextContributor` (TYPE_GLOBAL) helpers**: if a service exposed to all FreeMarker templates accepts parameters such as `groupId` that are forwarded to permission-free system APIs (e.g. `ConfigurationProvider.getGroupConfiguration()`), verify the parameter is constrained to the current request scope — otherwise any template author can probe data from sites they have no access to

### 3b. Correctness
- [ ] Logic matches the story/ticket acceptance criteria
- [ ] Edge cases are handled
- [ ] No silent failures or swallowed exceptions
- [ ] Service Builder output matches the model definition

### 3c. Code Conventions
- [ ] Source Formatter has been run (robots catch most objective errors — flag what they miss)
- [ ] No unused imports, references, or dead code
- [ ] Naming is clear, consistent, and in the correct language (English)
- [ ] No magic numbers or unexplained constants — use named constants
- [ ] Architectural boundaries respected (e.g. service layer vs. web layer)

> **Project note:** `@Component(immediate = true, ...)` is an accepted pattern in this codebase — do not flag it.

### 3d. Test Coverage
- [ ] New logic has corresponding test coverage
- [ ] No test-only changes mixed into production commits

### 3e. General Hygiene
- [ ] No debugging artifacts (`System.out.println`, `console.log`, commented-out blocks)
- [ ] No unrelated files or changes included in the PR

### 3f. Performance
- [ ] **No per-item service or configuration lookups inside loops or templates** — calls like `ConfigurationProvider.getGroupConfiguration()` should be made once per request and the result reused, not re-fetched for every rendered item (search result, list row, etc.)
- [ ] **No N+1 query patterns** — loading a collection then calling a service or DB for each element individually; look for loops that call `*LocalService.get*()` or similar per iteration and flag them for batch/bulk alternatives
- [ ] **Unbounded result sets** — queries or service calls without pagination or a `max` limit that could return thousands of rows as the dataset grows
- [ ] **String normalization not repeated in inner loops** — `trim()`, `toLowerCase()`, or similar transforms applied to the same set of values on every iteration should be pre-computed once (e.g. normalize an exclusion list into a `Set<String>` before iterating)
- [ ] **Unnecessary object allocation in hot paths** — avoid creating throwaway collections, wrappers, or intermediate arrays inside methods that are called frequently (e.g. per search result, per request)
- [ ] **FreeMarker sequence concatenation in loops** — `seq + [item]` inside `<#list>` creates a new object on every iteration (O(n²)); prefer a Java-side helper that builds the list in a single pass when the dataset could grow large

---

> **The following sections apply when the PR touches `.js`, `.jsx`, `.ts`, `.tsx`, or `client-extension.yaml` files.**

### 3g. Frontend — React & Hooks
- [ ] `useEffect` dependency arrays are syntactically and semantically correct — the closing `)` of `useEffect(callback, deps)` encloses both arguments; no deps arrays floating outside the call
- [ ] No two `useEffect` hooks setting the same state with conflicting logic (race condition / last-writer-wins overwrite)
- [ ] Async work inside `useEffect` handles stale responses — use a cleanup function or `AbortController` when the effect fires multiple times
- [ ] No unnecessary `useState` for values that can be derived from existing state or props inline
- [ ] State is initialized with a sensible default; avoid `null` where `false`, `0`, or `[]` expresses intent more clearly
- [ ] `useCallback` / `useMemo` are only added where profiling shows a real cost — not preemptively

### 3h. Frontend — Styling
- [ ] No inline `style` props for presentational styling — use CSS class names (e.g., `classNames('field', { 'field--error': isLate })`)
- [ ] Design tokens and Clay CSS custom properties (e.g., `var(--color-state-error)`) are referenced via class names, not hardcoded in inline style objects
- [ ] No hardcoded color hex/rgb values, magic pixel sizes, or raw spacing numbers — always reference tokens

### 3i. Frontend — Liferay Client Extensions
Flag any of these in a PR that adds or modifies a client extension:

- [ ] **Routing — URL-sharing required:** router `basename` is set to `Liferay.ThemeDisplay.getLayoutRelativeURL()` (not raw `window.location.pathname`); routes use the `/-/` segment convention to avoid conflicts with Liferay's URL system ([reference](https://liferay.atlassian.net/wiki/spaces/GS/pages/2493546561))
- [ ] **Routing — URL-sharing NOT required:** `MemoryRouter` or simple component state is used instead of `BrowserRouter` / `HashRouter`; no routing library at all if a state flag suffices
- [ ] **Routing — multi-app pages:** no two apps on the same page compete for the same URL path or hash segment
- [ ] **CX bundling:** related Client Extensions that can share a container are co-located under one `client-extension.yaml` — avoid creating a separate LUFFA deployment for a handful of CSS rules or a small JS snippet ([reference](https://liferay.atlassian.net/wiki/spaces/GS/pages/3760193646))
- [ ] **CX config:** custom element CX definitions include `useESM: true`; Global JS entries that use ESM include `scriptElementAttributes.type: module`
- [ ] **Dev setup:** new CXs include a `client-extension.dev.yaml` that points URLs to the vite dev server (`baseURL: http://localhost:5173`) to enable local HMR without redeployment ([reference](https://liferay.atlassian.net/wiki/spaces/GS/pages/4006576911))
- [ ] **Theme customisation:** new CSS/JS global overrides use Client Extensions (globalCSS, globalJS, Theme CSS CX), not a custom theme deployment ([reference](https://liferay.atlassian.net/wiki/spaces/GS/pages/3521413221))

### 3j. Frontend — TypeScript
- [ ] No `any` type without a comment explaining why it is unavoidable
- [ ] API response shapes are typed — avoid untyped `.find()` / `.map()` chains on raw `res.data`
- [ ] Non-null assertions (`!`) only used where the value is provably non-null at that point; otherwise use optional chaining or an explicit guard

---

## Step 4 — Output Format

Produce your review as follows:

### Submission Issues (blocking)
List any Step 1/2 failures that must be fixed before the review proceeds. If none, write "None."

### Security Findings
List each security concern with: **file:line** — description — suggested fix. If none, write "None."

### Performance Findings
List each performance concern with: **file:line** — description — suggested fix. If none, write "None."

### Code Issues
Group by severity — **Blocker**, **Major**, **Minor**, **Nit**:
- **Blocker**: Incorrect behavior, data loss risk, security hole
- **Major**: Significant quality or maintainability problem
- **Minor**: Convention violations, missing edge-case handling
- **Nit**: Style, naming, grammar — optional to fix

### Positive Notes
Call out one or two things done well. Code review is a two-way collaboration.

### Recommended Label
State what the PR label should be set to after this review, and why.

---

## Step 5 — Add Inline Comments to the PR

After producing the review output, post code-level findings as inline comments on the PR using GitHub's pending review feature:

1. Create a pending review: call `mcp__github__pull_request_review_write` with `method: create` and no `event` — omitting `event` keeps the review pending and not yet visible to others
2. For each code-level finding, call `mcp__github__add_comment_to_pending_review` with the exact `path`, `line`, `side` (`RIGHT` for added/new lines), and `subjectType: LINE`
3. **Never delete the pending review to update or correct a comment.** Deleting removes every comment in the review, including ones the PR author or others have added to the same pending review. To correct a comment, use `mcp__github__add_reply_to_pull_request_comment` to add a clarifying reply to the existing thread instead
4. Do not submit the review (`submit_pending`) unless explicitly asked — leave it pending for the reviewer to send when ready

---

## Step 6 — Publish Review as Secret Gist

After producing the review output, always upload it to a secret GitHub Gist using `gh gist create`:

1. The review content must include a **`**PR:**` line** near the top (below the title) with the full URL of the PR being reviewed.
2. Name the gist file `PR-Review-<TICKET>.md` (e.g. `PR-Review-LR-123.md`).
3. Pass `--filename "PR-Review-<TICKET>.md"` to `gh gist create` so GitHub renders the file as Markdown. Without this flag the file is named `stdin` or `stdin.md` and may not render correctly.
4. Gists are secret by default with `gh gist create` (do not pass `--public`).
5. After creation, share the Gist URL with the user.

Example command:
```bash
gh gist create --filename "PR-Review-LR-123.md" --desc "PR Review: LR-123 <title>" <<'EOF'
...review content...
EOF
```

---

## Tone
Be direct, specific, and constructive. Reference file paths and line numbers. Ask clarifying questions if intent is unclear rather than assuming the worst. The goal is to ship quality code, not to gatekeep.
