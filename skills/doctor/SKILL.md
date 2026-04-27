---
allowed-tools: Read Bash(java *) Bash(docker *) Bash(ant *) Bash(cat *) Bash(ls *)
description: Check Liferay Workspace prerequisites (JDK 17–23, Docker) and show a health summary of running services. Use when the user asks about workspace health, prerequisites, or invokes /doctor.
disable-model-invocation: false
name: doctor
---

## Prerequisite checks

Run all checks in a **single** Bash call, then report each item as ✓ or ✗. For failures, include the install hint.

```bash
echo "---JAVA---" && java -version 2>&1; echo "---DOCKER---" && docker --version 2>&1; echo "---ANT---" && ant -version 2>&1; echo "---SOURCE---" && ([ -f .env.source ] && echo "SOURCE_MODE=true" || echo "SOURCE_MODE=false")
```

**Pass criteria:**
- **JDK 17–23**: version string matches `"17.`, `"18.`, `"19.`, `"20.`, `"21.`, `"22.`, or `"23.`
- **Docker**: command succeeds
- **Apache Ant**: only required when `SOURCE_MODE=true`

**Install hints:**
- JDK: `sdk install java 21-tem` (SDKMAN) or download from https://adoptium.net
- Docker: install Docker Desktop from https://www.docker.com/products/docker-desktop
- Ant: `brew install ant` (macOS) or `apt-get install ant` (Debian/Ubuntu) or download from https://ant.apache.org/bindownload.cgi

## Health summary (standalone only)

Skip this section if invoked from another skill (e.g. setup).

Run: `[ -f .liferay-workspace.json ] && cat .liferay-workspace.json || echo "NOT_CONFIGURED"`

If `.liferay-workspace.json` exists, read mode/version/hotfix/elements from it. Then run:

```bash
docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null
```

Print a summary table using the config values plus container health. For each element in `elements`, show its container status from `docker compose ps`. Append URLs for running services:

```
  Mode:     <mode>
  Version:  <version>
  Hotfix:   <hotfix or none>
  Elements: <elements>

  Services:
    ✓ lr   — Up (healthy)  → http://localhost:8080
    ✓ db   — Up (healthy)
    ✓ es   — Up (healthy)
    ✓ mail — Up            → http://localhost:8025
    ✗ sn   — not running
```

If `.liferay-workspace.json` does not exist, skip the health summary and show:
`Workspace not configured — run /liferay-workspace:setup first.`
