---
name: clean
description: Clean Liferay Workspace build artifacts, Docker containers, and bundle data.
disable-model-invocation: false
---

If invoked from another skill (e.g. setup), run with the defaults below without asking — skip the toggle prompt entirely.

Otherwise, show the following selection and ask: **"Type numbers to toggle (e.g. `4`), or `ok` to confirm:"**

```
  [x] 1. Docker      — stop containers and remove orphans
  [x] 2. Bundles     — remove bundles/data, deploy, logs, osgi, routes, esdata
  [x] 3. Build       — remove node_modules, node_modules_cache, dist, build directories
  [ ] 4. Portal home — source mode only: kill processes on 8080/8000, delete $PORTAL_BUNDLES
```

Update the selection based on the user's response, then re-display and ask again until the user types `ok`.

Run the clean script with flags matching the confirmed items:

```bash
# Examples:
bash scripts/clean.sh --docker --bundles --build            # items 1+2+3
bash scripts/clean.sh --docker --bundles --build --portal-home  # all four
bash scripts/clean.sh --all                                  # shorthand for 1+2+3
```

Report each item as ✓ done or — skipped based on the script output.
