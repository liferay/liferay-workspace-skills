---

paths:
  - "skills/pr-review/**/*.md"

---

# Commit Message Convention

Commit titles and pull request titles follow the same Liferay convention:

```
TICKET-000 Imperative verb description
```

## Rules

- Ticket ID in uppercase (e.g. `LPD-12345`, `LPS-100`, `COMMERCE-456`), followed by a single space.
- Description starts with a capitalized imperative verb (`Add`, `Fix`, `Update`, `Remove`, `Refactor`).
- No period at the end of the first line.
- First line at most 72 characters.
- For more context, add a blank line followed by a body paragraph. Wrap the body at 72 characters where reasonable.

## Examples

- `LPD-12345 Add custom field validation`
- `LPS-100 Fix null pointer in article approval`
- `COMMERCE-456 Refactor cart pricing pipeline`

## Ticket Extraction Order

When a skill needs to derive the ticket ID, check in order:

1. Explicit argument supplied by the user (matches `[A-Z]+-[0-9]+`).
2. Current branch name (e.g. `feature/LPD-12345-some-description` → `LPD-12345`).
3. Most recent commits on the branch — pull the ticket prefix from the latest commit whose subject matches the convention.
4. Ask the user.

## Secret-File Guard

When auto-staging, exclude files that commonly hold secrets — `.env`, `.env.*`, `*.pem`, `*.key`, `credentials.json`, anything under `secrets/`. Warn before staging if the user explicitly lists one.