---
description: Clean Liferay Workspace build artifacts, Docker containers, and bundle data. Use when the user asks to clean, reset, or wipe the workspace, or invokes /clean.
disable-model-invocation: false
name: clean
---

If invoked from another skill (e.g. setup), run with the defaults below without asking — skip the toggle prompt entirely.

`clean` only touches the **active mode's** bundles — running `bash scripts/local_setup.sh clean` in docker mode wipes `./bundles/` only; with `--source` it wipes `$PORTAL_BUNDLES` only. Switching modes via `bash scripts/local_setup.sh [--source]` does not invoke clean at all.

Otherwise, show the following selection and ask: **"Type numbers to toggle (e.g. `4`), or `ok` to confirm:"**

```
  [x] 1. Docker      — stop containers and remove orphans
  [x] 2. Bundles     — remove bundles/data, deploy, logs, osgi, routes, esdata
  [x] 3. Build       — remove node_modules, node_modules_cache, dist, build directories
  [ ] 4. Portal home — source mode only: kill processes on 8080/8000, delete $PORTAL_BUNDLES contents
```

Update the selection based on the user's response, then re-display and ask again until the user types `ok`.

Detect mode from `.env.source` — if it exists, pass `--source` to the script.

If items 1+2+3 are confirmed (the default), run:

```bash
bash scripts/local_setup.sh clean              # docker mode
bash scripts/local_setup.sh clean --source     # source mode
```

`local_setup.sh clean` always performs items 1+2+3 (and in `--source` mode also kills processes on 8080/8000). It does **not** support partial selections or item 4 (Portal home full delete) — if the user toggled off any of 1/2/3 or toggled on item 4, run the affected steps manually instead of invoking the script:

- **Docker only** → `docker compose down --remove-orphans` (use `-f docker-compose.yml -f docker-compose.source.yml` in source mode)
- **Bundles only (docker)** → `rm -rf bundles/data bundles/deploy bundles/logs bundles/osgi bundles/routes bundles/esdata`
- **Bundles only (source)** → `rm -rf "$PORTAL_BUNDLES"/{data,deploy,logs,routes,osgi/configs,osgi/modules,osgi/client-extensions}`
- **Build only** → `find . -depth -type d \( -name node_modules_cache -o -name node_modules -o -name dist -o -name build \) -exec rm -rf {} \;`
- **Portal home (source only)** → kill PIDs on 8080/8000, then `rm -rf "$PORTAL_BUNDLES"` — this **also removes** the `ant all` output, so the next `/setup` will rebuild from scratch (30–60+ min)

Report each item as ✓ done or — skipped.
