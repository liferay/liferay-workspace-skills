# Liferay Workspace Claude Plugin

A Claude plugin for Liferay Workspace projects. It provides skills for local development setup, portal source navigation, and integration with the Liferay product Jira project (LPD). Targets both **Docker** mode (Liferay runs in a container) and **Source** mode (Liferay built from `liferay-portal-ee`).

## Skill Catalog

### Workspace Lifecycle

| Skill | Purpose |
| --- | --- |
| `doctor` | Verify prerequisites (JDK 17–23, Docker, Ant 1.10.14+ for source mode) and show the health summary of running services |
| `setup` | Interactive workspace configuration wizard. Generates `.liferay-workspace.json`, `docker-compose.yml`, source-mode configs, then runs `scripts/local_setup.sh` |
| `setup-source` | Write source-mode files (`docker-compose.source.yml`, `configs/source/portal-env.properties`, `configs/source/osgi/configs/`). Idempotent |
| `clean` | Stop containers, wipe bundles, clear build artifacts. Interactive toggle UI or scripted via `scripts/local_setup.sh clean` |

### Development

| Skill | Purpose |
| --- | --- |
| `core` | Search and analyze the Liferay Portal source. Two modes — `root-cause` for bug investigation, `guide` for feature understanding |
| `plan` | Produce an implementation plan for a ticket or feature, scoped to the active workspace |
| `implement` | Create or modify workspace files (Java, JSP, gradle, client-extension), build, and deploy |
| `commit` | Stage and create a Git commit per the Liferay convention (see [`rules/commit.md`](rules/commit.md)) |
| `pr` | Create a GitHub PR, then **print** the Jira `curl` commands for the user to run manually (see [`rules/jira.md`](rules/jira.md)) |

### Jira

| Skill | Purpose |
| --- | --- |
| `bug` | Build the Jira REST `curl` command to file a Bug in LPD and print it for the user to run |
| `feature-request` | Build the Jira REST `curl` command to file a Task (feature request) in LPD and print it for the user to run |

The Jira skills follow the **print, do not run** pattern documented in [`rules/jira.md`](rules/jira.md). Skills assemble the payload and emit the `curl` invocation; the user reviews and runs it.

## Configuration Source of Truth

`.liferay-workspace.json` at the workspace root holds the full plugin state — mode, version, hotfix, paths, and enabled elements. Schema and resolution rules: [`rules/workspace-config.md`](rules/workspace-config.md).

## Docker vs Source Mode

| Aspect | Docker | Source |
| --- | --- | --- |
| Liferay | Runs in the `liferay` container | Built from `liferay-portal-ee`, runs locally on 8080 |
| Setup time | ~5 minutes | 30–60+ minutes (first build) |
| Compose file | `docker-compose.yml` | `docker-compose.yml` + `docker-compose.source.yml` (disables the `liferay` service) |
| Use when | Iterating on workspace modules and client extensions | Modifying portal core or debugging into portal source |

Both modes share the same `.liferay-workspace.json`. Switching modes does not require re-running `/setup` — pass `--source` (or omit it) to `scripts/local_setup.sh` after editing `mode`.

## Scripts

The plugin ships a small bash toolkit under `scripts/`:

| Script | Role |
| --- | --- |
| `local_setup.sh` | Lifecycle orchestrator. Subcommands — `up`, `all`, `prereqs`, `clean`, `build`, `start`, `stop`, `license` |
| `rg-liferay.sh` | Ripgrep wrapper tuned for the Liferay Portal monorepo. Used by `/core` |
| `_logging.sh` | Sourced helper — ANSI colors, step timing, `log_step_done` |
| `_helpers.sh` | Sourced helper — Compose invocation, mode detection, port-conflict cleanup |
| `_prereqs.sh` | Sourced helper — JDK/Docker/Ant checks, hotfix resolution, portal-source clone and build |
| `_steps.sh` | Sourced helper — `step_setup_env`, `step_clean`, `step_build`, `step_start`, `step_stop`, `step_license` |

The `_*.sh` files are sourced by `local_setup.sh`, never executed standalone.

## Conventions

The plugin keeps cross-skill conventions in dedicated rules files so they live in one place:

- [`rules/jira.md`](rules/jira.md) — Jira REST API auth, project / issue type / transition IDs, the print-do-not-run execution model
- [`rules/commit.md`](rules/commit.md) — `TICKET-000 Imperative verb description` format and ticket-extraction order
- [`rules/workspace-config.md`](rules/workspace-config.md) — `.liferay-workspace.json` schema, portal-source resolution, mode detection
- [`rules/markdown-style.md`](rules/markdown-style.md) — Markdown style for plugin files (Title Case, long-form flags, tab indentation, no trailing newline)

## Environment Variables

| Variable | Used By | Purpose |
| --- | --- | --- |
| `JIRA_API_USER` | `bug`, `feature-request`, `pr` | Jira Cloud user email |
| `JIRA_API_TOKEN` | `bug`, `feature-request`, `pr` | Jira API token (https://id.atlassian.com/manage-profile/security/api-tokens) |
| `NO_COLOR` | `scripts/_logging.sh` | Disables ANSI color output (no-color.org standard) |

## External Tools

- `gh` — GitHub CLI, used by `pr` for PR creation
- `git` — used by `commit`, `pr`, and most other skills
- `docker compose` (v2) — used by `setup`, `clean`, and `local_setup.sh`
- `java`, `ant`, `gradle` — runtime requirements verified by `doctor`