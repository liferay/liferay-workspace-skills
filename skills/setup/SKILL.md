---
argument-hint: "[source]"
description: Interactive setup wizard for a Liferay Workspace. Configures paths, hotfix, mode, docker-compose elements, and writes a workspace config file. Use when the user asks to set up a workspace, initialize one, or invokes /setup.
disable-model-invocation: true
name: setup
---

If invoked with the argument `source`, the **chosen mode** is Source. Otherwise the chosen mode is Docker. The chosen mode determines what gets booted at the end (Step 7), but **all configuration files for both modes are written every run** so the user can flip modes later via `bash scripts/local_setup.sh [--source]` without re-running `/setup`.

Run all steps in order: 0, 1, 2 (chosen=docker only), 3 (chosen=source only), 4, 5, 6, 7, 8.

Before running the setup steps:

1. Invoke `liferay-workspace:doctor` — if any prerequisite fails, stop and ask the user to fix it before continuing.

(Cleaning is handled by `scripts/local_setup.sh all` in Step 7 — do not invoke `liferay-workspace:clean` separately unless the user asks for a partial clean with the toggle UI.)

Then guide the user through the setup steps below interactively. Wait for answers at each step before proceeding.

## General rules
- Do not create the `bundles` folder, except `bundles/patching-tool/patches/` for copying the Hotfix in Docker mode
- Steps that write files are idempotent: skip if the target already exists, unless this is a `/setup` reprocess and the file is regenerated (e.g. `scripts/*.sh`)

## Step 0 — Materialize project scripts

Copy the plugin's setup script set into the project so it is runnable without Claude on subsequent invocations:

```bash
mkdir -p scripts
cp "${CLAUDE_PLUGIN_ROOT}/scripts/local_setup.sh" \
   "${CLAUDE_PLUGIN_ROOT}/scripts/_logging.sh" \
   "${CLAUDE_PLUGIN_ROOT}/scripts/_helpers.sh" \
   "${CLAUDE_PLUGIN_ROOT}/scripts/_prereqs.sh" \
   "${CLAUDE_PLUGIN_ROOT}/scripts/_steps.sh" \
   scripts/
chmod +x scripts/local_setup.sh
```

This step always runs, including on `/setup` reprocess, so plugin script fixes propagate. **Local edits to `scripts/*.sh` will be overwritten** — tell the user up front. If `${CLAUDE_PLUGIN_ROOT}` is unset, fail with: "Cannot locate plugin scripts; ensure the plugin is installed via `claude plugin add`."

## Step 1 — Resources

Collect **all** of the following values regardless of chosen mode (so source-mode switching works later without re-running `/setup`). Display a summary table and ask: **"Type a setting name to change it, or `ok` to continue:"**

- **Mode**: Docker (default, can be flipped later via `bash scripts/local_setup.sh --source`) or Source.
- **Source**: where to clone `liferay-portal-ee` (default: `../liferay-portal-ee`, sibling to the workspace).
- **Bundle cache** (default `~/.liferay/liferay-binaries-cache-2020`).
- **Bundles**: source-mode bundles output (default: `<source>/bundles`, matching Ant's build output).
- **Hotfix**: scan `~/.liferay/hotfixes/` for zips; if multiple found present a numbered list, if none found leave blank.
- **DXP License**: scan `~/.liferay/activation/activation-key-*.xml`; if multiple found present a numbered list, if none found fail with an error.

Re-display the table after each change until the user types `ok`.

## Step 2 — Hotfix (Docker mode, optional)

Run: `ls ~/.liferay/hotfixes/liferay-dxp-*hotfix*.zip 2>/dev/null`

List what's found. Ask the user:
1. Which hotfix to use (if multiple)
2. How to apply it:
   - **Copy** → `bundles/patching-tool/patches/`
   - **Hash only** → extract `build.git-revision` from the zip's `hotfix.json` (for source builds)

## Step 3 — Base version (Source mode only)

If no hotfix is found, extract from `gradle.properties`:
```bash
grep 'liferay.workspace.product=dxp-' gradle.properties | sed 's/.*dxp-//' | sed 's/-.*//'
```
This strips the `dxp-` prefix and any suffix like `-lts`, yielding e.g. `2026.q1.2`.

Only ask the user manually if neither source yields a version.

## Step 4 — docker-compose.yml

Run regardless of chosen mode — Source mode uses the same compose file plus `docker-compose.source.yml` to disable the Liferay container.

Check if `docker-compose.yml` already exists. If it does, skip this step.

Otherwise, show the following selection and ask: **"Type numbers to toggle (e.g. `5`), or `ok` to confirm:"**

```
  [x] 1. Liferay    — DXP container (required)
  [x] 2. DB         — PostgreSQL 16
  [x] 3. Search     — Elasticsearch
  [x] 4. Mail       — Mailpit
  [ ] 5. ServiceNow — Mock server
```

Update the selection based on the user's response, then re-display and ask again until the user types `ok`.

Generate `docker-compose.yml` using only the selected elements. Use `liferay` as the network name. And create a new `configs/docker/` folder with required configs/files.

### Element recipes

**DB** (PostgreSQL)
```yaml
database:
  container_name: db
  environment:
    - PGUSER=lportal
    - POSTGRES_USER=lportal
    - POSTGRES_PASSWORD=lportal
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -d lportal"]
    interval: 10s
    retries: 5
    start_period: 15s
    timeout: 60s
  image: postgres:16
  networks: [liferay]
  ports: ["5432:5432"]
```

**Search** (Elasticsearch)
```yaml
search:
  build: ./search
  container_name: es
  environment:
    - ES_JAVA_OPTS=-Xms2g -Xmx2g
    - bootstrap.memory_lock=false
    - cluster.name=liferay_cluster
    - cluster.routing.allocation.disk.threshold_enabled=false
    - discovery.type=single-node
    - network.host=_site_
    - node.name=search
    - node.roles=master,data,ingest
    - xpack.security.enabled=false
  healthcheck:
    test: ["CMD-SHELL", "curl -s http://search:9200/_cluster/health?wait_for_status=green || exit 1"]
    interval: 30s
    retries: 5
    start_period: 15s
    timeout: 10s
  networks: [liferay]
  ports: ["127.0.0.1:9200:9200"]
```

**Mail** (Mailpit)
```yaml
mail:
  image: axllent/mailpit
  networks: [liferay]
  ports:
    - "1025:1025"
    - "8025:8025"
```

**ServiceNow** (mock)
```yaml
servicenow:
  build: ./servicenow-mock
  container_name: sn
  healthcheck:
    test: ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:5000/health')\""]
    interval: 10s
    retries: 3
    start_period: 5s
    timeout: 5s
  networks: [liferay]
  ports: ["8090:5000"]
```

**Liferay** (always included — add `depends_on` for whichever of DB/Search are selected)
```yaml
liferay:
  container_name: lr
  depends_on:
    database:
      condition: service_healthy  # if DB selected
    search:
      condition: service_healthy  # if Search selected
  environment:
    - LIFERAY_JVM_OPTS=-Xms4g -Xmx4g -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:8000
    - LIFERAY_MODULE_PERIOD_FRAMEWORK_PERIOD_PROPERTIES_PERIOD_OSGI_PERIOD_CONSOLE=0.0.0.0:11311
    - LIFERAY_UPGRADE_PERIOD_DATABASE_PERIOD_AUTO_PERIOD_RUN=true
    # Add JDBC env vars if DB selected:
    - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_lass_UPPERCASEN_ame=org.postgresql.Driver
    - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL=jdbc:postgresql://database:5432/lportal
    - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME=lportal
    - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD=lportal
  extra_hosts: ["host.cx.internal:host-gateway"]
  image: liferay/dxp:${LIFERAY_VERSION}
  networks: [liferay]
  ports:
    - "8000:8000"
    - "8080:8080"
    - "11311:11311"
  # Linux only: user: ${UID}:${GID}
  volumes:
    - ./configs/common/portal-ext.properties:/opt/liferay/portal-ext.properties
    - ./configs/docker/portal-env.properties:/opt/liferay/portal-env.properties
    - ./configs/docker/files:/mnt/liferay/files
    - ./configs/docker/scripts:/mnt/liferay/scripts
    - ./bundles/patching-tool/patches:/mnt/liferay/patching
    - ./bundles/data:/opt/liferay/data
    - ./bundles/deploy:/mnt/liferay/deploy
    - ./bundles/osgi/modules:/opt/liferay/osgi/modules
    - ./bundles/osgi/configs:/opt/liferay/osgi/configs
    - ./bundles/logs:/opt/liferay/logs
```

## Step 5 — Config file

Read `.liferay-workspace.json` and `gradle-local.properties` first if they already exist (required before overwriting). Then write `.liferay-workspace.json` to the workspace root:

```json
{
  "version": "<extracted>",
  "hotfix": "<filename>",
  "hotfixCommit": "<sha or null>",
  "mode": "docker|source",
  "paths": {
    "source": "<abs path>",
    "bundleCache": "<abs path>",
    "bundles": "<abs path>",
    "license": "<abs path>"
  },
  "elements": ["liferay", "db", "search"]
}
```

In source mode, also write `gradle-local.properties`:
```
liferay.workspace.home.dir=<bundles path>
```

## Step 6 — Source Setup

Invoke the `liferay-workspace:setup-source` skill **regardless of chosen mode**. It writes the source-mode config files (`configs/source/portal-env.properties`, `docker-compose.source.yml`, `.env.source`) idempotently. Seeding these in Docker-first installs means the user can later run `bash scripts/local_setup.sh --source` without going back through `/setup`.

The portal clone and `ant all` build are handled by `scripts/local_setup.sh`'s prereq step on the first source-mode boot — do not run them separately.

## Step 7 — Start up

Hand off to `scripts/local_setup.sh`, which runs prereqs, env, clean, build, start, and (Docker mode) license install in sequence — including log waits and port checks.

Docker mode:
```bash
bash scripts/local_setup.sh all
```

Source mode:
```bash
bash scripts/local_setup.sh all --source
```

On Linux, before invoking the script in Docker mode, uncomment `user: ${UID}:${GID}` in the `liferay` service of `docker-compose.yml`.

The script reads `paths.license` from `.liferay-workspace.json` (with a fallback glob to `~/.liferay/activation/activation-key-*.xml`). Source mode does **not** install the license inside the script — after the script returns, copy it manually:

```bash
source .env.source
cp <paths.license> "$LIFERAY_PORTAL_BUNDLES/osgi/modules/"
```

## Step 8 — Finish

Print a summary table:

```
  Mode:     Docker | Source
  Version:  <version>
  Hotfix:   <hotfix>
  Elements: Liferay, DB, Search, Mail
  URL:      http://localhost:8080
  Mail UI:  http://localhost:8025   (only if Mail element selected)
```

Then print the AI-free re-run cheat sheet:

```
  Next time (no AI required):
    bash scripts/local_setup.sh           # docker mode
    bash scripts/local_setup.sh --source  # source mode (first run will clone+build)
    bash scripts/local_setup.sh stop      # stop services
    bash scripts/local_setup.sh clean     # wipe current mode's bundles only

  Switching modes via the script does NOT clean the other mode's bundles.
  Re-run /setup to refresh scripts and rebuild from scratch.
```
