---
description: Write source-mode config files for a Liferay Workspace (portal-env.properties, docker-compose.source.yml, .env.source). Cloning and building liferay-portal-ee is handled by scripts/local_setup.sh --source. Use when the user asks to set up portal source mode or invokes /setup-source.
disable-model-invocation: false
name: setup-source
---

Invoked unconditionally by `/setup` (regardless of the user's chosen initial mode) so that `bash scripts/local_setup.sh --source` works later without re-running `/setup`. All file writes are idempotent — skip if the target already exists.

Read `.liferay-workspace.json`. Extract:
- `paths.source` → `PORTAL_SOURCE` (abs path to liferay-portal-ee clone)
- `paths.bundles` → `PORTAL_BUNDLES` (abs path to built portal bundles)

The clone of `liferay-portal-ee` and the `ant all` build are run by `scripts/local_setup.sh --source` (via `step_prereqs`) on the first source-mode boot — do not invoke them from this skill.

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
