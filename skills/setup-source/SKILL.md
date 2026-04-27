---
description: Clone and build Liferay Portal from source, then write source-mode config files. Use when the user asks to set up portal source mode, clone liferay-portal, or invokes /setup-source.
disable-model-invocation: false
name: setup-source
---

Read `.liferay-workspace.json`. Extract:
- `paths.source` → `PORTAL_SOURCE` (abs path to liferay-portal-ee clone)
- `paths.bundleCache` → `BUNDLE_CACHE` (abs path to liferay-binaries-cache-2020)
- `paths.bundles` → `PORTAL_BUNDLES` (abs path to built portal bundles)
- `hotfixCommit` → if not null, use as `REF`
- `version` → if `hotfixCommit` is null, extract the `YYYY.qN.N` part (strip any suffix like `-lts`) and use it directly as `REF` (e.g. `"2026.q1.2-lts"` → `REF=2026.q1.2`)

## Step A — Clone portal

Run: `[ -d "<PORTAL_SOURCE>" ] && echo "EXISTS" || echo "MISSING"`

If EXISTS → report `— already cloned` and skip.

If MISSING → run:

```bash
bash scripts/clone_portal.sh "<PORTAL_SOURCE>" "<BUNDLE_CACHE>" "<COMMIT>"
```

Report ✓ done or ✗ failed.

## Step B — Build portal

⚠️ This takes 30–60+ minutes on first run.

Run: `[ -d "<PORTAL_BUNDLES>" ] && echo "EXISTS" || echo "MISSING"`

If EXISTS and invoked standalone → ask: **"Portal bundles already exist at `<PORTAL_BUNDLES>`. Rebuild? (y/N)"** — skip unless the user confirms.
If EXISTS and invoked from setup → rebuild without asking (clean already ran).

If MISSING or confirmed → run:

```bash
bash scripts/build_portal.sh "<PORTAL_SOURCE>"
```

Report ✓ done or — skipped.

## Step C — Source configs

Create `configs/source/portal-env.properties` if it doesn't exist:

```properties
# Database (must match the database service in docker-compose.yml)
jdbc.default.driverClassName=org.postgresql.Driver
jdbc.default.url=jdbc:postgresql://localhost:5432/lportal
jdbc.default.username=lportal
jdbc.default.password=lportal

# OSGi console
module.framework.properties.osgi.console=localhost:11311

# Startup
upgrade.database.auto.run=true
setup.wizard.enabled=false
```

Run: `mkdir -p configs/source/osgi/configs`

This directory is intentionally empty — place workspace-specific OSGI `.config` files here.

Report ✓ created or — already exists for each item.

## Step D — Docker Compose source override

Create `docker-compose.source.yml` if it doesn't exist. This disables the `liferay` container so only supporting services (DB, search, mail) run in Docker while portal runs from local source:

```yaml
services:
  liferay:
    deploy:
      replicas: 0
```

Report ✓ created or — already exists.

## Step E — Write `.env.source`

Write `.env.source` to the workspace root. This file is the source-mode marker that `doctor` detects and the variable source that `clean` relies on:

```
PORTAL_SOURCE=<PORTAL_SOURCE>
PORTAL_BUNDLES=<PORTAL_BUNDLES>
```

Report ✓ written.
