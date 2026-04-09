<p align="center">
  <img src="https://img.shields.io/badge/Claude_Code-Plugin-blueviolet?style=for-the-badge&logo=anthropic" alt="Claude Code Plugin" />
  <img src="https://img.shields.io/badge/Liferay_DXP-2024.q+-%230B63CE?style=for-the-badge&logo=liferay" alt="Liferay DXP" />
  <img src="https://img.shields.io/badge/version-0.1.0-blue?style=for-the-badge" alt="Version" />
  <img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="License" />
</p>

<h1 align="center">Liferay Workspace Claude Plugin</h1>

<p align="center">
  <strong>Set up, manage, and develop in Liferay DXP workspaces with AI-powered slash commands.</strong>
  <br />
  Workspace setup, portal source analysis, implementation workflows, and Jira ticket generation — all from your terminal.
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> &middot;
  <a href="#skills">Skills</a> &middot;
  <a href="#workflow">Workflow</a> &middot;
  <a href="#examples">Examples</a> &middot;
  <a href="#scripts">Scripts</a> &middot;
  <a href="#contributing">Contributing</a>
</p>

---

## Why

Setting up a Liferay DXP workspace involves juggling Docker Compose files, Gradle properties, hotfix management, DXP licenses, portal source builds, and dozens of configuration files across multiple modes. This plugin turns that into a single guided conversation.

Each skill encodes the team's institutional knowledge — version extraction logic, service healthcheck patterns, portal module conventions — so you get a consistent, reproducible setup every time.

---

## Quick Start

**Install the plugin into your Liferay Workspace project:**

```bash
# From your Liferay Workspace root directory
claude plugin add /path/to/liferay-workspace-claude-plugin
```

**Run your first command:**

```
/liferay-workspace:setup
```

That's it. The setup wizard walks you through everything.

---

## Skills

### Workspace Management

| Skill | Command | Description |
|-------|---------|-------------|
| **Setup** | `/liferay-workspace:setup [source]` | Interactive workspace configuration wizard — Docker or source mode |
| **Setup Source** | `/liferay-workspace:setup-source` | Clone and build `liferay-portal-ee` from source |
| **Doctor** | `/liferay-workspace:doctor` | Prerequisite checks and running service health dashboard |
| **Clean** | `/liferay-workspace:clean` | Remove containers, build artifacts, and bundle data |
| **Core** | `/liferay-workspace:core <mode> <query>` | Deep analysis of portal source code (root-cause & guide modes) |

### Development Workflow

| Skill | Command | Description |
|-------|---------|-------------|
| **Plan** | `/liferay-workspace:plan <ticket or description>` | Create an implementation plan — affected modules, steps, testing strategy, and risks |
| **Implement** | `/liferay-workspace:implement <ticket or description>` | Implement a feature or fix based on a plan or ticket description |
| **Commit** | `/liferay-workspace:commit [TICKET-000] [description]` | Create a git commit following `TICKET-000 Imperative verb description` convention |
| **PR** | `/liferay-workspace:pr [TICKET-000]` | Create a GitHub pull request with Jira ticket link and structured description |

### Jira Tickets

| Skill | Command | Description |
|-------|---------|-------------|
| **Bug** | `/liferay-workspace:bug <summary>` | Generate a Jira bug report with steps to reproduce, Liferay version, actual/expected results |
| **Feature Request** | `/liferay-workspace:feature-request <summary>` | Generate a Jira feature request with assumptions and acceptance criteria |

---

## Workflow

The skills are designed to work together in a natural development lifecycle:

```
  Doctor               Setup               Clean
  ┌─────────┐     ┌──────────────┐     ┌─────────┐
  │ Check    │────▶│ Configure    │────▶│ Reset    │
  │ prereqs  │     │ workspace    │     │ state    │
  └─────────┘     └──────┬───────┘     └─────────┘
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
        Docker Mode           Source Mode
     ┌──────────────┐     ┌──────────────┐
     │ Generate      │     │ Clone portal │
     │ compose.yml   │     │ Build source │
     │ Start all     │     │ Start deps   │
     └──────────────┘     └──────────────┘
              │                     │
              └──────────┬──────────┘
                         ▼
  Bug / Feature     ┌──────────┐     Plan
  ┌──────────┐      │  Core    │     ┌──────────┐
  │ Create   │      │ Analyze  │────▶│ Design   │
  │ tickets  │      │ source   │     │ approach │
  └──────────┘      └──────────┘     └────┬─────┘
                                          │
                                          ▼
                    Implement         Commit            PR
                    ┌──────────┐     ┌──────────┐     ┌──────────┐
                    │ Build &  │────▶│ Stage &  │────▶│ Push &   │
                    │ deploy   │     │ commit   │     │ open PR  │
                    └──────────┘     └──────────┘     └──────────┘
```

- **`setup`** orchestrates the entire flow — it calls `doctor` and `clean` automatically before configuring.
- **`setup-source`** is invoked by `setup` when source mode is selected.
- **`core`** works independently for portal source code investigation at any time.
- **`bug`** / **`feature-request`** generate structured Jira tickets.
- **`plan`** → **`implement`** → **`commit`** → **`pr`** is the development workflow chain.

---

## Examples

### Setting up a Docker workspace

```
> /liferay-workspace:setup

┌─────────────────────────────────────────────────┐
│ Liferay Workspace Setup                         │
├──────────────┬──────────────────────────────────┤
│ Mode         │ Docker                           │
│ Bundle cache │ ~/.liferay/liferay-binaries-...  │
│ Hotfix       │ liferay-dxp-2026.q1.2-hf-1.zip  │
│ DXP License  │ activation-key-enterprise.xml    │
└──────────────┴──────────────────────────────────┘

Type a setting name to change it, or "ok" to continue.

> ok

Select services:
  [x] 1. Liferay      — DXP container (required)
  [x] 2. DB           — PostgreSQL 16
  [x] 3. Search       — Elasticsearch
  [x] 4. Mail         — Mailhog
  [ ] 5. ServiceNow   — Mock server

✓ docker-compose.yml generated
✓ .liferay-workspace.json written
✓ Modules deployed
✓ Services started
✓ DXP license applied

Liferay DXP 2026.q1.2 is running at http://localhost:8080
```

### Setting up from source

```
> /liferay-workspace:setup source

# Same interactive setup, plus:
✓ liferay-portal-ee cloned at abc123d
✓ Portal built (took 42 minutes)
✓ Source configs written
✓ Supporting services started (DB, Search, Mail)

Liferay DXP (source) running at http://localhost:8080
```

### Checking workspace health

```
> /liferay-workspace:doctor

Prerequisites
  ✓ JDK 21.0.2
  ✓ Docker 27.5.1

Workspace
  Mode: Docker | Version: 2026.q1.2 | Hotfix: hf-1

Services
  ✓ lr       — Up (healthy) → http://localhost:8080
  ✓ db       — Up (healthy) → localhost:5432
  ✓ search   — Up (healthy) → http://localhost:9200
  ✓ mail     — Up (healthy) → http://localhost:8025
```

### Investigating a bug in portal source

```
> /liferay-workspace:core root-cause NPE in JournalArticleLocalServiceImpl when approving articles with null display date

Searching portal source...
  → Found JournalArticleLocalServiceImpl in modules/apps/journal/journal-service
  → Located updateStatus() method at line 4521
  → displayDate accessed without null check after workflow transition

Root Cause: When an article is approved via workflow, updateStatus()
reads displayDate from the article's current version. If the article
was created via Headless API without a displayDate, the field is null,
and the subsequent Calendar conversion at line 4538 throws NPE.

Module: journal-service
File: JournalArticleLocalServiceImpl.java:4538
Fix: Add null guard before Calendar.getInstance() conversion.
```

### Learning how to use a feature

```
> /liferay-workspace:core guide batch engine client extensions for importing object definitions

Searching portal source...
  → Found batch-engine modules in modules/apps/batch-engine
  → Reading BatchEngineImportTaskResource API
  → Found sample client extensions in workspaces/

Usage Guide:
  1. Create a batch client extension with client-extension.yaml
  2. Define your object schema in batch/*.json files
  3. Configure import strategy in batch-engine-data.json
  ...
  [complete guide with code snippets derived from source]
```

### Planning and implementing a feature

```
> /liferay-workspace:plan LPD-12345 Add custom field validation for object definitions

Implementation Plan
===================
Ticket:      LPD-12345
Summary:     Add custom field validation for object definitions
Complexity:  Medium

Affected Modules:
  - modules/objects/objects-validation — new validation logic
  - modules/objects/objects-web — UI for validation rules

Steps:
  1. Create ObjectFieldValidationImpl in objects-validation
  2. Register OSGi component with @Component annotation
  3. Add validation rule configuration UI in objects-web
  4. Write integration tests

Ready to proceed, or any adjustments?
```

```
> /liferay-workspace:implement LPD-12345

# Implements the plan, builds, and deploys
✓ ObjectFieldValidationImpl.java created
✓ Validation UI component added
✓ Build passed
✓ Deployed to bundles/deploy

Next: run /commit to commit, then /pr to open a pull request.
```

### Committing and creating a PR

```
> /liferay-workspace:commit LPD-12345 Add custom field validation for object definitions

✓ 4 files staged
✓ Created: LPD-12345 Add custom field validation for object definitions
```

```
> /liferay-workspace:pr LPD-12345

Pull Request Created
====================
PR:       https://github.com/org/repo/pull/42
Ticket:   https://liferay.atlassian.net/browse/LPD-12345
Title:    LPD-12345 Add custom field validation for object definitions
Base:     main
Commits:  1
```

### Filing a bug report

```
> /liferay-workspace:bug NPE when approving journal articles with null display date

Bug Report
==========
Summary:     NPE when approving journal articles with null display date
Component:   Journal
Affects:     Liferay DXP 2026.q1.2
Severity:    Major

Steps to Reproduce:
  1. Create a journal article via Headless API without displayDate
  2. Submit for workflow approval
  3. Approve the article

Actual Result:   NullPointerException at JournalArticleLocalServiceImpl:4538
Expected Result: Article approved successfully with default display date

Anything to adjust before filing?
```

### Cleaning the workspace

```
> /liferay-workspace:clean

Select items to clean:
  [x] 1. Docker      — stop containers, remove orphans
  [x] 2. Bundles     — remove data, deploy, logs, osgi, esdata
  [x] 3. Build       — remove node_modules, dist, build dirs
  [ ] 4. Portal home — kill processes, delete bundles (source mode)

  ✓ Docker containers stopped
  ✓ Bundle data removed
  ✓ Build artifacts cleaned
```

---

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| **JDK** | 17 – 23 | Required for all modes |
| **Docker** | Any recent | Required for containerized services |
| **Apache Ant** | Any | Source mode only |
| **ripgrep (`rg`)** | Any | Required for `core` skill portal searches |

Run `/liferay-workspace:doctor` to verify your environment.

---

## Project Structure

```
liferay-workspace-claude-plugin/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata (name, version)
├── skills/
│   ├── core/
│   │   ├── SKILL.md             # Portal source analysis skill
│   │   └── liferay-patterns.md  # Module conventions & search strategies
│   ├── setup/
│   │   └── SKILL.md             # Interactive workspace setup wizard
│   ├── setup-source/
│   │   └── SKILL.md             # Source mode clone & build
│   ├── doctor/
│   │   └── SKILL.md             # Prerequisite checks & health dashboard
│   ├── clean/
│   │   └── SKILL.md             # Artifact cleanup
│   ├── plan/
│   │   └── SKILL.md             # Implementation planning
│   ├── implement/
│   │   └── SKILL.md             # Feature/fix implementation
│   ├── commit/
│   │   └── SKILL.md             # Git commit with ticket convention
│   ├── pr/
│   │   └── SKILL.md             # GitHub pull request creation
│   ├── bug/
│   │   └── SKILL.md             # Jira bug report generator
│   └── feature-request/
│       └── SKILL.md             # Jira feature request generator
├── scripts/
│   ├── rg-liferay.sh            # Fast portal source search
│   ├── clone_portal.sh          # Clone liferay-portal-ee
│   ├── build_portal.sh          # Build portal from source
│   ├── setup_env.sh             # Generate .env with version info
│   ├── start_source.sh          # Start source mode services
│   └── clean.sh                 # Cleanup script
└── claude-docs/
    ├── create-plugins.md        # Plugin development guide
    └── extend-claude-with-skills.md  # Skill authoring docs
```

---

## Configuration

The plugin generates a `.liferay-workspace.json` file in your workspace root during setup:

```json
{
  "version": "2026.q1.2",
  "hotfix": "liferay-dxp-2026.q1.2-hotfix-1.zip",
  "hotfixCommit": "abc123def",
  "mode": "docker",
  "paths": {
    "source": "/path/to/liferay-portal-ee",
    "bundleCache": "~/.liferay/liferay-binaries-cache-2020",
    "bundles": "/path/to/bundles",
    "license": "~/.liferay/activation/activation-key.xml"
  },
  "elements": ["liferay", "db", "search", "mail"]
}
```

| Field | Description |
|-------|-------------|
| `version` | DXP version extracted from `gradle.properties` or hotfix |
| `hotfix` | Selected hotfix filename (if any) |
| `hotfixCommit` | Git commit SHA from hotfix metadata |
| `mode` | `docker` or `source` |
| `paths.source` | Path to `liferay-portal-ee` clone |
| `paths.bundleCache` | Path to binary cache for offline builds |
| `paths.bundles` | Output directory for compiled bundles |
| `paths.license` | Path to DXP activation key |
| `elements` | Services included in docker-compose |

---

## Scripts

All scripts live in `scripts/` and are called by the skills automatically. They can also be run directly:

| Script | Usage | Description |
|--------|-------|-------------|
| `rg-liferay.sh` | `bash scripts/rg-liferay.sh -t java -m journal "updateStatus"` | Search portal source by type, module, or pattern |
| `clone_portal.sh` | `bash scripts/clone_portal.sh <source> <cache> <ref>` | Clone portal-ee and binary cache at a specific ref |
| `build_portal.sh` | `bash scripts/build_portal.sh <source>` | Build portal with `ant setup-profile-dxp && ant all` |
| `setup_env.sh` | `bash scripts/setup_env.sh` | Generate `.env` with UID/GID and LIFERAY_VERSION |
| `start_source.sh` | `bash scripts/start_source.sh` | Start supporting services for source mode |
| `clean.sh` | `bash scripts/clean.sh --docker --bundles --build` | Clean containers, data, and build artifacts |

<details>
<summary><strong>rg-liferay.sh options</strong></summary>

| Flag | Description |
|------|-------------|
| `-d <dir>` | Scope search to a directory |
| `-t <type>` | File type filter: `java`, `xml`, `jsp`, `js`, `properties`, `gradle`, `bnd`, `yaml` |
| `-m <module>` | Scope to a specific module name |
| `-l` | List matching files only (no content) |
| `-n <limit>` | Limit number of results |
| `-i` | Case-insensitive search |
| `-w` | Whole word matching |
| `-C <lines>` | Context lines around matches |

</details>

---

## Docker vs Source Mode

| | Docker Mode | Source Mode |
|---|---|---|
| **How it runs** | Liferay in a DXP container image | Liferay built and run from source |
| **Setup time** | ~5 minutes | 30–60+ minutes (first build) |
| **Best for** | Client extensions, theme dev, testing | Core debugging, portal patches, deep investigation |
| **Services** | All in Docker (Liferay + DB + Search + ...) | Only supporting services in Docker; Liferay runs locally |
| **Config files** | `docker-compose.yml`, `configs/docker/` | `docker-compose.source.yml`, `configs/source/`, `.env.source` |

---

## Contributing

Contributions are welcome! Here's how the plugin is structured:

- **Skills** are defined in `skills/<name>/SKILL.md` using Claude Code's skill format
- **Scripts** in `scripts/` handle the actual system operations
- **Documentation** in `claude-docs/` provides reference material for skill development

To add a new skill:
1. Create a new directory under `skills/`
2. Add a `SKILL.md` following the [skill authoring guide](claude-docs/extend-claude-with-skills.md)
3. Reference any helper scripts in `scripts/`

---

## License

MIT
