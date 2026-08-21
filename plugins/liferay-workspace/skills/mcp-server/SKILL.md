---
description: Enable the Liferay MCP server for a Liferay Workspace and diagnose MCP failure modes, restart ordering, transport mismatch, dropped connections, 403s on tool calls. Use when the user asks to enable or set up MCP, when an MCP tool call returns errors, or invokes /mcp-server.
disable-model-invocation: false
name: mcp-server
---

Setup, endpoint, transport, auth, and client configuration are documented at https://learn.liferay.com/w/dxp/ai/using-liferay-as-an-mcp-server. Read it; do not answer from memory.

Route any feature flag the docs name through `liferay-workspace:feature-flags` rather than editing properties directly.

## 403 Error

A fresh instance creates `test@liferay.com` with `passwordReset=true` and `agreedToTermsOfUse=false`, and every authenticated call returns 403 until both clear. The handshake still succeeds and tools still list, so a healthy connection is not evidence that tool calls will work.

In a developer environment, skip it by adding the following to `portal-ext.properties` before first boot:

```properties
passwords.default.policy.change.required=false
terms.of.use.required=false
```

When the instance already booted without them or if the database is Hypersonic, have the user sign in as `test@liferay.com` / `test`, accept the Terms of Use, and set the password to `test`. Do not automate it; the form varies across releases.

## Restart Ordering

CLI agents load MCP configs only at startup. After creating the MCP server configs, have the user restart their session **before** the portal boots, otherwise the session will need to be restarted and the portal will need to be booted a second time.

## Failure Modes

**"Disconnected" with a correct URL.** Usually a transport mismatch. The status gives no hint; confirm the required transport in the docs and check the client config.

**Configuration change appears to have no effect.** Restart the session. If the server shows connected with zero tools, an agent side reconnect may recover a dropped connection but never a config change, which always needs a full restart.

**Connection dead after a portal restart.** It does not autoreconnect, and the agent cannot reconnect itself. Confirm the portal is up then have the user reconnect and wait for their reply.
