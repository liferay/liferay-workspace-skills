---
argument-hint: "[source]"
description: Interactive setup wizard for a Liferay Workspace. Configures paths, hotfix, mode, docker-compose elements, and writes a workspace config file. Use when the user asks to set up a workspace, initialize one, or invokes /setup.
disable-model-invocation: true
name: setup
---

If invoked with the argument `source`, follow the **Source mode** flow throughout (Steps 1, 3, 5–8). Otherwise follow the **Docker mode** flow (Steps 1, 2, 4, 5, 7–8).

Before running any setup steps, execute in order:

1. Invoke `liferay-workspace:doctor` — if any prerequisite fails, stop and ask the user to fix it before continuing.
2. Invoke `liferay-workspace:clean` — wait for it to complete before proceeding.

Then guide the user through the setup steps below interactively. Wait for answers at each step before proceeding.

## General rules
- Do not create the `bundles` folder, except `bundles/patching-tool/patches/` for copying the Hotfix in Docker mode

## Step 1 — Resources

Collect the following values, then display a summary table and ask: **"Type a setting name to change it, or `ok` to continue:"**

- **Mode**: Docker (default) or Source. In Source mode, also ask where to clone `liferay-portal-ee` (default: `../liferay-portal-ee`, use from parent folder)
- **Bundle cache** (`~/.liferay/liferay-binaries-cache-2020`, use from .liferay folder): default sibling to source
- **Bundles**: Source mode only (default: `<portal source>/bundles`, matching Ant's build output)
- **Hotfix**: scan `~/.liferay/hotfixes/` for zips; if multiple found present a numbered list, if none found leave blank
- **DXP License**: scan `~/.liferay/activation/activation-key-*.xml`; if multiple found present a numbered list, if none found fail with an error

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

## Step 4 — docker-compose.yml (Docker mode only)

Check if `docker-compose.yml` already exists. If it does, skip this step.

Otherwise, show the following selection and ask: **"Type numbers to toggle (e.g. `5`), or `ok` to confirm:"**

```
  [x] 1. Liferay    — DXP container (required)
  [x] 2. DB         — PostgreSQL 16
  [x] 3. Search     — Elasticsearch
  [x] 4. Mail       — Mailhog
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
    - node.roles=[master, data, ingest]
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

**Mail** (Mailhog)
```yaml
mail:
  image: mailhog/mailhog
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

## Step 6 — Source Setup (Source mode only)

Invoke the `liferay-workspace:setup-source` skill.

## Step 7 — Start up

Run each sub-step in order to start Liferay.

**7a. Environment**
Generate `.env` from `gradle.properties`:
```bash
bash scripts/setup_env.sh
```

On Linux, also uncomment `user: ${UID}:${GID}` in the `liferay` service of `docker-compose.yml`.

**7b. Build/Deploy**

Check that each directory exists **and** contains a `build.gradle` or `settings.gradle` (an empty directory is not deployable). Run as a single command — skip silently if the check fails:

```bash
[ -d modules ] && ls modules/*/build.gradle >/dev/null 2>&1 && ./gradlew -p modules deploy; [ -d client-extensions ] && ls client-extensions/*/build.gradle >/dev/null 2>&1 && ./gradlew -p client-extensions deploy; true
```

**7c. Start services**

Docker mode:
```bash
docker compose up -d
```

Source mode:
```bash
bash scripts/start_source.sh
```

**7d. License** (use the `license` path from `.liferay-workspace.json`)

Docker mode:
```bash
cp <paths.license> bundles/osgi/modules/
```
Wait for `License registered for DXP Development` in `bundles/logs/liferay.*.log`.

Source mode — just copy, do **not** wait for log output:
```bash
source .env.source
cp <paths.license> "$PORTAL_BUNDLES/osgi/modules/"
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
