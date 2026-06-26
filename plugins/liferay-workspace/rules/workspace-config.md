---

paths:
  - "skills/**/*.md"
  - "scripts/**/*.sh"

---

# Workspace Configuration

The plugin treats `.liferay-workspace.json` as the **single source of truth** for workspace state. All skills and scripts read it before deciding what to do.

## Schema

```json
{
	"version": "<DXP version, e.g. 2024.Q3.13>",
	"hotfix": "<hotfix filename or null>",
	"hotfixCommit": "<git sha or null>",
	"mode": "docker|source",
	"paths": {
		"source": "<abs path to liferay-dxp checkout>",
		"bundleCache": "<abs path to cached bundle archives>",
		"bundles": "<abs path to active bundle directory>",
		"license": "<abs path to activation-key.xml>"
	},
	"elements": ["liferay", "db", "search", "mail"]
}
```

## Field Notes

- **version** — DXP version string. Used by `doctor` and `setup` to display the active release and by `setup-source` to derive the source branch.
- **hotfix** / **hotfixCommit** — `null` for clean releases; populated when a hotfix bundle is applied. The commit is the git sha of the hotfix resolution in `liferay-dxp`.
- **mode** — `docker` or `source`. Controls which Compose file is generated and whether the Liferay container is enabled.
- **paths.source** — Required in `source` mode. Optional in `docker` mode but useful for `/core` to find the portal repo.
- **paths.bundleCache** — Shared download cache, safe to delete; bundles are re-fetched on demand.
- **paths.bundles** — Active bundle root. In source mode, `app.server.parent.dir` is overridden to write here.
- **paths.license** — XML activation key for DXP. The `license` script step copies this into the running bundle's `deploy` directory.
- **elements** — Which Compose services to start. Order is informational; the actual order is determined by Compose dependencies.

## Portal-Source Resolution

The `/core` skill and any other skill that searches the portal source resolves the path in this order:

1. `.liferay-workspace.json` — `paths.source`.
2. `../liferay-dxp` (sibling to the workspace directory).
3. `../liferay-portal`.
4. Ask the user.

Verify the resolution with `[ -d "${PORTAL_SRC}/portal-kernel" ]`.

## Mode Detection

`scripts/_helpers.sh`'s `detect_mode` resolves the active mode in this order:

1. `--source` CLI flag passed to `scripts/local_setup.sh` (wins over everything).
2. `.liferay-workspace.json` — `mode` field.
3. Default: `docker`.

The `--source` flag is the only thing that overrides the file. Switching modes for real means editing the file, then re-running `scripts/local_setup.sh` without `--source` (Docker) or with `--source` (Source).

## File Overwrite Rules

| File | Overwritten By | Notes |
| --- | --- | --- |
| `scripts/*.sh` | Every `/setup` run | Plugin scripts always rewritten; local edits to these files are lost |
| `docker-compose.yml` | First `/setup` run or explicit mode switch | Subsequent runs preserve user edits unless mode changes |
| `configs/source/*` | `setup-source` skill | Idempotent — skipped when files exist |
| `.liferay-workspace.json` | `/setup` | Always rewritten with the latest answers |
| `gradle-local.properties` | `/setup` (source mode only) | Sets `liferay.workspace.home.dir` to `paths.bundles` |