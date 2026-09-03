---
allowed-tools: Bash(bash scripts/local_setup.sh *) Bash(grep *) Edit Read Write
description: Enable Liferay feature flags in a Liferay Workspace. Use when the user asks to enable a feature flag, when a Headless endpoint returns 404 or a bare 400 UnsupportedOperationException, or invokes /feature-flags.
disable-model-invocation: false
name: feature-flags
---

Flag levels, the Instance Settings UI, properties, and environment variable forms are documented at https://learn.liferay.com/w/dxp/security-and-administration/administration/configuring-liferay/feature-flags. Read it; do not answer from memory.

Portal properties in `portal-ext.properties` are read at boot, so adding any feature flag there requires a restart when portal is live. Toggling a flag in the Instance Settings UI takes effect immediately.

## Enabling a Flag

Enable the flag at **Control Panel → Instance Settings → Feature Flags**. The change takes effect immediately.

Dev flags are not listed there. Enable one by adding its property to `portal-ext.properties` and restarting:

```properties
feature.flag.LPD-63311=true
```

## Determining a Flag Level

Never state a level from memory and never infer one from the flag key. The feature's own page on Liferay Learn names the flag and the level it sits under, and reflects the most recent quarterly release. Changes to a flag's level are listed per release on the **Default Setting and Feature Flag Changes** pages indexed at https://learn.liferay.com/w/dxp/self-hosted-installation-and-upgrades/upgrading-liferay/deprecations-and-breaking-changes-reference.

A flag that does not appear in Instance Settings is a dev flag.

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
