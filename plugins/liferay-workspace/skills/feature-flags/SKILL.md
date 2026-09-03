---
allowed-tools: Bash(bash scripts/local_setup.sh *) Bash(grep *) Edit Read Write
description: Enable Liferay feature flags in a Liferay Workspace. Use when the user asks to enable a feature flag, when a Headless endpoint returns 404 or a bare 400 UnsupportedOperationException, or invokes /feature-flags.
disable-model-invocation: false
name: feature-flags
---

Flag levels, the Instance Settings UI, properties, and environment variable forms are documented at https://learn.liferay.com/w/dxp/security-and-administration/administration/configuring-liferay/feature-flags. Read it; do not answer from memory.

Portal properties in `portal-ext.properties` are read at boot, so a restart is required if dev feature flags are added and portal is live.

## Locate the Portal Source

Determine the portal source directory. Check in order:

1. Read `.liferay-workspace.json` — use `paths.source`

1. Check if `../liferay-portal-ee` or `../liferay-portal` exists

1. Ask the user for the path

Do not search the filesystem for the checkout. When the first two checks fail, ask.

Store the resolved path as `${PORTAL_SRC}` for all subsequent steps.

Verify the path: `[ -d "${PORTAL_SRC}/portal-kernel" ] && echo "OK" || echo "NOT_FOUND"`

## Diagnosing an Unknown Flag Gate

When a Headless operation returns `400 UnsupportedOperationException` and the log is silent, the feature may be hidden behind a feature flag. The portal pattern is:

```java
if (!FeatureFlagManagerUtil.isEnabled(companyId, "LPD-XXXXX")) {
	throw new UnsupportedOperationException();
}
```

JAX-RS converts the bare `UnsupportedOperationException` into a 400 with no useful response body, so the flag key never reaches the client. To find it, search the portal source for `LPD-` references in the relevant `*ResourceImpl`.
