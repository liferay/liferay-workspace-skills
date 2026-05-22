# Liferay Portal Source — Structure & Patterns Reference

## Top-level directory layout

| Directory | Description |
|---|---|
| `portal-kernel/` | Public API (`com.liferay.portal.kernel.*`). Interfaces, exceptions, utility classes. **Start here for core API bugs.** |
| `portal-impl/` | Core implementation of `portal-kernel` interfaces. Service layer, persistence, search, security. |
| `portal-web/` | JSPs, tag libraries, and classic UI resources for the portal core. |
| `modules/` | OSGi modules organized by domain. The bulk of DXP features live here. |
| `modules/apps/` | Product features (Journal, Blogs, Commerce, Workflow, etc.). |
| `modules/dxp/apps/` | DXP-only (enterprise) features. |
| `modules/core/` | Core framework modules (Petra, portal-configuration, etc.). |
| `modules/sdk/` | SDK tooling, Gradle plugins, project templates. |
| `portal-test/` | Shared test utilities. |
| `util-java/` | Core Java utilities shared across portal-impl and modules. |
| `util-taglib/` | Tag library utilities for JSP rendering. |
| `sql/` | Database schema definitions and SQL scripts. |
| `tools/` | Build and development tooling (source formatter, etc.). |
| `definitions/` | DTD and XML schema definitions. |
| `workspaces/` | Sample workspaces including `liferay-sample-workspace/` with client extension examples. |

## Key files inside a module

| File | Purpose |
|---|---|
| `bnd.bnd` | OSGi bundle metadata: `Bundle-SymbolicName`, `Export-Package`, `Import-Package`, version. **Check this to understand module boundaries and dependencies.** |
| `build.gradle` | Build config, dependency declarations. |
| `service.xml` | Service Builder entity definitions (if the module uses Service Builder). Generates model, persistence, and service classes. |
| `src/main/resources/META-INF/portlet-model-hints.xml` | Column type hints for Service Builder entities. |
| `src/main/resources/META-INF/spring/` | Spring XML configs (legacy modules). |
| `src/main/resources/portlet.properties` | Portlet-specific properties and defaults. |

**Note on i18n:** Language strings are **centralized** in `modules/apps/portal-language/portal-language-lang/src/main/resources/content/Language.properties` (~23k lines). Individual modules generally do not have their own Language.properties files.

## Common Java patterns

### Service references (OSGi Declarative Services)

```java
@Reference
private UserLocalService _userLocalService;
```

To find all consumers of a service:  
Search for `@Reference` + the service interface name.

### Service Builder services

- `*LocalServiceImpl` — business logic (no permission checks)
- `*ServiceImpl` — remote service (permission-checked wrapper)
- `*LocalServiceUtil` — static utility facade (calls the OSGi service under the hood)
- `*Persistence` / `*PersistenceImpl` — database CRUD
- `*FinderImpl` — custom SQL finders (check `src/main/resources/META-INF/sql/`)
- `*ModelImpl` — generated entity model

### Configuration (OSGi Config Admin)

```java
@Meta.OCD(id = "com.liferay.foo.internal.configuration.FooConfiguration")
public interface FooConfiguration {
    @Meta.AD(deflt = "true", name = "enabled")
    public boolean enabled();
}
```

Search for `@Meta.OCD` or the configuration PID to find configurable behavior.

### Portlet classes

- `*Portlet` — main portlet class
- `*MVCActionCommand` — handles form submissions (`/action/path`)
- `*MVCRenderCommand` — handles render requests (`/render/path`)
- `*MVCResourceCommand` — handles AJAX / resource requests (`/resource/path`)

### REST / Headless APIs

- `modules/apps/headless/` — REST endpoints (OpenAPI-based)
- `*ResourceImpl` — endpoint implementation
- `rest-openapi.yaml` — OpenAPI spec for the module

### Client Extensions

Client Extensions are "detached" from the portal core — they run as external apps that the portal hosts. The portal-side infrastructure that registers, routes, and serves them lives in these locations:

**Portal source modules:**
- `modules/apps/client-extension/` — core framework: registration, lifecycle, metadata storage
- `modules/apps/batch-engine/` — batch engine used by `batch` type client extensions (Object definitions, data imports)
- `modules/apps/headless/headless-batch-engine/` — REST APIs for the batch engine
- `modules/apps/object/` — Objects framework (custom objects defined by batch client extensions)
- `modules/apps/oauth2-provider/` — OAuth 2.0 scopes and token handling for client extension auth

**Key classes and patterns (CET = Client Extension Type):**
- `*ClientExtensionEntry*` — registration and metadata for a deployed client extension
- `CETDeployerImpl` — deploys/undeploys client extension types at runtime (in `client-extension-web`)
- `CustomElementCETPortlet` extends `BaseCETPortlet` — renders `custom-element` type client extensions inside a portlet wrapper
- `CustomElementCET` / `CustomElementCETImpl` — type definition and implementation for custom-element extensions
- `*BatchEngineImportTask*` — processes batch client extension payloads (Object definitions, data)
- `*OAuth2Application*` — OAuth app entries that client extensions register for API access

**Client extension submodules** (under `modules/apps/client-extension/`):
- `client-extension-api` / `client-extension-service` — core API and persistence
- `client-extension-type-api` / `client-extension-type-impl` — CET type definitions (CustomElementCET, IFrameCET, etc.)
- `client-extension-web` — admin UI, portlet renderers, deployer

**Key files in a client extension project (workspace side, not portal source):**
- `client-extension.yaml` — declares the extension type, OAuth scopes, and metadata
- `*.batch-engine-data.json` — batch data payloads (Object definitions, etc.)
- `assets/` — static assets for custom-element types

**CSRF / auth flow:**
When a custom-element makes API calls back to Liferay, it must include the CSRF token (`p_auth`). The portal validates this in `com.liferay.portal.security.auth` — search for `AuthTokenUtil` or `AntiSamyFilter` when debugging 403 errors from client extension requests.

## Portal properties

- `portal.properties` — full defaults (in `portal-impl/src/portal.properties`)
- `portal-ext.properties` — user overrides
- Key prefixes for common areas:
  - `com.liferay.portal.search.*` — search engine config
  - `com.liferay.portal.security.*` — security/auth
  - `jdbc.default.*` — database connection
  - `dl.store.*` — document library storage
  - `module.framework.*` — OSGi framework settings

## Module naming conventions

| Pattern | Example | Meaning |
|---|---|---|
| `*-api` | `journal-api` | Public interfaces and DTOs |
| `*-service` | `journal-service` | Service Builder implementation |
| `*-web` | `journal-web` | Portlet UI (JSP/React) |
| `*-rest-impl` | `headless-delivery-impl` | REST endpoint implementation |
| `*-rest-client` | `headless-delivery-client` | Generated REST client |
| `*-test` | `journal-test` | Integration tests |
| `*-taglib` | `journal-taglib` | JSP tag library |
| `*-item-selector-*` | `journal-item-selector-web` | Item selector integration |

## Where to find usage examples (guide mode)

| Source | What it provides |
|---|---|
| `*-test/` modules (e.g., `journal-test`) | Integration tests with real invocations, expected inputs/outputs, setup/teardown patterns |
| `workspaces/liferay-sample-workspace/client-extensions/` | Official client extension samples — `client-extension.yaml`, batch data, custom elements |
| `rest-openapi.yaml` in headless modules | Full API shape with request/response schemas |
| `@Meta.OCD` / `@Meta.AD` interfaces | All configurable settings with types, defaults, and valid values |
| `*-api` module interfaces | Public contract — method signatures, parameter types, return types |
| `*.json` fixtures in test resources | JSON structure examples for batch engine, REST payloads, Object definitions |

## Common search strategies by bug type (root-cause mode)

| Bug type | Where to look first |
|---|---|
| NPE in a service | `*ServiceImpl` or `*LocalServiceImpl` in the module, then check `@Reference` targets |
| Permission denied | `*ServiceImpl` (wraps local service with permission checks), `*ModelResourcePermission` |
| Missing data / wrong query | `*FinderImpl`, `custom-sql/*.xml` files, `*PersistenceImpl` |
| UI rendering issue | `*Portlet`, `*MVCRenderCommand`, JSPs in `src/main/resources/META-INF/resources/` |
| Upgrade / migration failure | `*UpgradeProcess` classes, `src/main/resources/META-INF/sql/tables.sql` |
| Configuration not taking effect | `@Meta.OCD` config interface, `*ConfigurationProvider` usage |
| Search index problem | `*ModelDocumentContributor`, `*ModelIndexerWriterContributor`, `*KeywordQueryContributor` |
| Workflow / notification | `*WorkflowHandler`, `*UserNotificationHandler` |
| Import/Export (LAR) | `*StagedModelDataHandler`, `*PortletDataHandler` |
| Scheduler / background task | `*MessageListener`, `*BackgroundTaskExecutor` |
| Client extension not registering | `*ClientExtensionEntry*`, `CETDeployerImpl`, `osgi/client-extensions/` deploy path |
| Client extension 403 / auth failure | `AuthTokenUtil`, `*OAuth2Application*`, `*OAuth2ProviderScopeChecker*` |
| Batch import failure (Objects) | `*BatchEngineImportTask*`, `*.batch-engine-data.json` field definitions, `*ObjectDefinition*` |
| Custom element not rendering | `CustomElementCETPortlet`, `BaseCETPortlet`, `*ClientExtensionEntryRel*`, page fragment registration |
