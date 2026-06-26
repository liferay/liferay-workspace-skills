---

paths:
  - "skills/pr/**/*.md"

---

# CODEOWNERS-Based Fork Routing

Liferay Portal contributions are not opened against upstream `liferay/liferay-portal`. Each team maintains its own fork (for example, `liferay-bpm/liferay-portal`), and a pull request is opened against the fork that owns the changed module. The mapping lives in the repository's `.github/CODEOWNERS` file, where every path is assigned a single `@liferay-<team>` handle.

The team handle corresponds 1:1 to a GitHub organization of the same name hosting a fork with the same repository name. For example, `@liferay-bpm` owns `https://github.com/liferay-bpm/liferay-portal`. PR https://github.com/liferay-bpm/liferay-portal/pull/5923 is a representative example.

## When This Rule Applies

A skill enters **fork routing** mode when both of the following are true:

1. `.github/CODEOWNERS` exists in the repository root.

1. The file contains at least one `@liferay-*` handle.

When either condition fails, the skill keeps its default behavior (single-repo PR against `origin`).

Detect both with a single check:

```bash
test -f .github/CODEOWNERS && grep --quiet '@liferay-' .github/CODEOWNERS && echo "ROUTING" || echo "DEFAULT"
```

## Valid Team Handles

The following handles route to a fork. Anything else is treated as "no owner".

| Handle | Target Organization |
| --- | --- |
| `@liferay-ac` | `liferay-ac` |
| `@liferay-appsec` | `liferay-appsec` |
| `@liferay-bpm` | `liferay-bpm` |
| `@liferay-commerce` | `liferay-commerce` |
| `@liferay-content-management` | `liferay-content-management` |
| `@liferay-core-infra` | `liferay-core-infra` |
| `@liferay-database-infra` | `liferay-database-infra` |
| `@liferay-devtools` | `liferay-devtools` |
| `@liferay-frontend` | `liferay-frontend` |
| `@liferay-headless` | `liferay-headless` |
| `@liferay-page-management` | `liferay-page-management` |
| `@liferay-platform-experience` | `liferay-platform-experience` |
| `@liferay-search` | `liferay-search` |
| `@liferay-site-management` | `liferay-site-management` |

The target repository is always `<organization>/<repo-name>` (for example, `liferay-bpm/liferay-portal`). Derive `<repo-name>` from the upstream remote:

```bash
basename "$(git config --get remote.origin.url)" .git
```

Contributors do not have access to open pull requests against `liferay-dxp` (the private EE repository) or its forks. When this command returns `liferay-dxp`, use **`liferay-portal`** as `<repo-name>` instead — contributions are routed to the public `liferay-portal` and its team forks even when the local checkout is `liferay-dxp`. For any other repository, use the returned name as-is.

## Resolving Owners from Changed Files

CODEOWNERS uses **last-match-wins** semantics. The file is ordered general → specific, so a path under `modules/apps/asset/asset-display-page-api/` resolves to the more specific `@liferay-page-management` even though `modules/apps/asset/` matches `@liferay-content-management` earlier in the file. Always scan the entire file and keep the **last** matching prefix per path.

Step 1. Collect the changed file list against the base branch:

```bash
git diff \
	--name-only \
	"<base-branch>...HEAD"
```

Step 2. For each changed file, walk every non-comment, non-blank line of `.github/CODEOWNERS`. A line has the shape `<path-prefix><whitespace><owner-or-empty>`. Match when the file path starts with `<path-prefix>` (treating trailing `/` as a directory boundary). Remember the owner from the **last** line that matched. A line with no owner clears the assignment for any path it matches.

Step 3. Aggregate the per-team file counts and list files with no resolved owner separately. Present the breakdown to the user in the form:

```
@liferay-bpm: 4 files
@liferay-content-management: 1 file
(no owner): 2 files — modules/apps/archived/foo.java, modules/apps/counter/bar.java
```

## Choosing the Target Team

1. **Single owner across all owned files** — use it without prompting.

1. **Multiple owners** — present the breakdown and use `AskUserQuestion` to let the user pick one team. Never auto-pick the team with the most files; a close split (for example, 3 vs 2 files) is a real ambiguity that the user must resolve.

1. **All files lack an owner** — ask the user to pick a target team from the table above, or to fall back to upstream `liferay/<repo>`.

## Resolving the User's Personal Fork

The PR `--head` reference for a cross-repository PR has the form `<user-organization>:<branch>`. Detect the user's fork by scanning the repository remotes for a `<organization>/<repo-name>` URL where the organization is neither `liferay` nor any `liferay-*` team handle from the table above.

```bash
git remote --verbose
```

1. **Exactly one matching remote** — that remote is the user's fork. Push the branch there with `git push --set-upstream <remote-name> HEAD`. Derive `<user-organization>` from the remote URL.

1. **Multiple matching remotes** — present the candidates and use `AskUserQuestion` to let the user pick one.

1. **No matching remote** — ask the user to add one (for example, `git remote add myfork git@github.com:<user>/<repo>.git`) before continuing. Do not push to `origin` or to a team remote.

## Constructing the `gh pr create` Invocation

When fork routing is active, the PR creation uses cross-repository flags. The PR always targets `liferay-portal` (see the `<repo-name>` normalization above), so the base branch is always `master` — the default (HEAD) branch of `liferay-portal`.

```bash
PR_BODY=$(cat <<'EOF'
<body>
EOF
)

gh pr create \
	--base master \
	--body "${PR_BODY}" \
	--head "<user-organization>:<branch>" \
	--repo "<team-organization>/<repo-name>" \
	--title "<title>"
```

When fork routing is not active, the invocation keeps its default form (no `--repo`, no `--head`, no explicit `--base`).