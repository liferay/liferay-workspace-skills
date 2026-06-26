#!/usr/bin/env bash
# Prerequisite checks and portal source setup — sourced by local_setup.sh.

require() {
	local name="$1"
	local message="$2"
	shift 2
	[ "${1:-}" = "--" ] && shift

	if "$@" &>/dev/null; then
		echo "  ✓ ${name}"
	else
		echo "  ✗ ${name} — ${message}"
		MISSING_PREREQS=true
	fi
}

resolve_hotfix_name() {
	if [ "${LIFERAY_MODE:-docker}" = "source" ]; then
		local lcp_json="${SCRIPT_DIR}/../ci/LCP.json"

		if [ ! -f "$lcp_json" ]; then
			echo ""
			return
		fi

		jq -r '.env.LCP_CI_LIFERAY_DXP_HOTFIXES_COMMON // ""' "$lcp_json"
	else
		local bundles_dir="${PORTAL_BUNDLES:-bundles}"
		local -a hotfix_entries=()
		shopt -s nullglob
		hotfix_entries=( "$bundles_dir"/patching-tool/patches/liferay-dxp-*-hotfix-* )
		shopt -u nullglob

		if [ ${#hotfix_entries[@]} -eq 0 ]; then
			echo ""
			return
		fi

		basename "${hotfix_entries[0]%.zip}"
	fi
}

_hotfix_version_from_name() {
	echo "$1" | sed 's/^liferay-dxp-\(.*\)-hotfix-[0-9]*$/\1/'
}

# Resolves the local path to the hotfix zip without downloading.
# Canonical location is the workspace patches dir; ~/.liferay/hotfixes is a legacy cache.
_hotfix_zip_path() {
	local hotfix_name="${HOTFIX_NAME:-}"

	if [ -z "$hotfix_name" ]; then
		echo ""
		return
	fi

	local bundles_dir="${PORTAL_BUNDLES:-bundles}"
	local workspace_zip="${bundles_dir}/patching-tool/patches/${hotfix_name}.zip"

	if [ -f "$workspace_zip" ]; then
		echo "$workspace_zip"
		return
	fi

	local version
	version=$(_hotfix_version_from_name "$hotfix_name")
	local cache_zip="${HOME}/.liferay/hotfixes/${version}/${hotfix_name}.zip"

	if [ -f "$cache_zip" ]; then
		echo "$cache_zip"
	else
		echo ""
	fi
}

# Ensures the hotfix zip is present locally, downloading from releases-cdn.liferay.com
# if missing. Returns the zip path on stdout; all logs go to stderr so callers can
# capture the path via command substitution.
_ensure_hotfix_zip() {
	local hotfix_name="${HOTFIX_NAME:-}"

	if [ -z "$hotfix_name" ]; then
		echo ""
		return
	fi

	local existing
	existing=$(_hotfix_zip_path)

	if [ -n "$existing" ]; then
		echo "$existing"
		return
	fi

	local version
	version=$(_hotfix_version_from_name "$hotfix_name")
	local bundles_dir="${PORTAL_BUNDLES:-bundles}"
	local patches_dir="${bundles_dir}/patching-tool/patches"
	local target="${patches_dir}/${hotfix_name}.zip"
	local url="https://releases-cdn.liferay.com/dxp/hotfix/${version}/${hotfix_name}.zip"

	mkdir -p "$patches_dir"

	echo "  ↓ Downloading hotfix ${hotfix_name} from ${url}" >&2

	if ! curl -fsSL --retry 3 -o "${target}.part" "$url" >&2; then
		rm -f "${target}.part"
		log_error "Failed to download hotfix from ${url}"
		echo ""
		return 1
	fi

	mv "${target}.part" "$target"
	echo "  ✓ Saved hotfix to ${target}" >&2
	echo "$target"
}

# Read hotfix.json by dot-path. Splits the path inside jq via getpath so hyphenated
# keys (build.git-revision) work without bareword quoting. Reads directly from the
# zip via unzip -p — never extracts to a folder.
_read_hotfix_json() {
	local json_path="$1"
	local jq_filter='($path | split(".")) as $p | getpath($p) // ""'

	local zip
	zip=$(_ensure_hotfix_zip)

	if [ -z "$zip" ]; then
		echo ""
		return
	fi

	unzip -p "$zip" hotfix.json 2>/dev/null \
		| jq -r --arg path "$json_path" "$jq_filter" 2>/dev/null \
		|| true
}

resolve_git_revision()    { _read_hotfix_json "build.git-revision"; }
resolve_product_version() { _read_hotfix_json "requirement.product-version"; }

# Fallback when no hotfix.json is available: derive the portal branch/tag from
# liferay.workspace.product in gradle.properties (e.g. dxp-2026.q1.5-lts → 2026.q1.5).
resolve_product_version_from_gradle() {
	local gradle_props="${SCRIPT_DIR}/../gradle.properties"

	if [ ! -f "$gradle_props" ]; then
		echo ""
		return
	fi

	local product
	product=$(grep -E '^\s*liferay\.workspace\.product=' "$gradle_props" | sed 's/.*=//' | tr -d '[:space:]')

	if [ -z "$product" ]; then
		echo ""
		return
	fi

	product="${product#dxp-}"
	product="${product%-lts}"
	echo "$product"
}

readonly LIFERAY_DXP_URL="git@github.com:liferay/liferay-dxp.git"

_clone_or_update_dxp() {
	local git_revision="$1"
	local product_version="$2"

	if [ -d "$LIFERAY_PORTAL_SOURCE/.git" ]; then
		local current_commit
		current_commit=$(git -C "$LIFERAY_PORTAL_SOURCE" rev-parse HEAD 2>/dev/null || echo "")

		# Hotfix-specific revision wins over the product version (branch/tag).
		local target_ref="${git_revision:-$product_version}"

		# Fetch from the canonical upstream URL rather than `origin`. Users often
		# repoint origin at a personal fork that lacks upstream tags/branches,
		# and --single-branch clones restrict origin's fetch refspec.
		log_cmd git -C "$LIFERAY_PORTAL_SOURCE" fetch "$LIFERAY_DXP_URL" "$target_ref" --depth 1

		# ^{commit} dereferences annotated tags to the underlying commit.
		local target_commit
		target_commit=$(git -C "$LIFERAY_PORTAL_SOURCE" rev-parse 'FETCH_HEAD^{commit}' 2>/dev/null || echo "")

		if [ -z "$target_commit" ] || [ "$current_commit" = "$target_commit" ]; then
			echo "  ✓ liferay-dxp at ${current_commit:0:12} (${target_ref})"
		else
			log_step "Updating liferay-dxp to ${target_ref} ${target_commit:0:12} (was ${current_commit:0:12})"

			# `all` sets FORCE_PORTAL_RESET so checkout doesn't fail on tracked-file
			# modifications left by a prior ant build (bnd.bnd/packageinfo bumps).
			# `up` leaves the flag unset and aborts on dirty trees, preserving user work.
			if [ "${FORCE_PORTAL_RESET:-false}" = true ]; then
				log_warn "Discarding local modifications in $LIFERAY_PORTAL_SOURCE (all --source)."
				log_cmd git -C "$LIFERAY_PORTAL_SOURCE" reset --hard
			fi

			log_cmd git -C "$LIFERAY_PORTAL_SOURCE" checkout "$target_commit"
		fi
	else
		if [ -n "$git_revision" ]; then
			log_step "Cloning liferay-dxp at tag ${product_version} (commit ${git_revision:0:12})"
		else
			log_step "Cloning liferay-dxp at branch/tag ${product_version}"
		fi

		log_cmd git clone --depth 1 --single-branch --branch "$product_version" \
			"$LIFERAY_DXP_URL" "$LIFERAY_PORTAL_SOURCE"

		if [ -n "$git_revision" ]; then
			log_cmd git -C "$LIFERAY_PORTAL_SOURCE" fetch "$LIFERAY_DXP_URL" "$git_revision" --depth 1
			log_cmd git -C "$LIFERAY_PORTAL_SOURCE" checkout "$git_revision"
		fi
	fi
}

_ensure_binaries_cache() {
	local parent_dir="$1"
	local binaries_target="${parent_dir}/liferay-binaries-cache-2020"
	local binaries_shared="${HOME}/.liferay/liferay-binaries-cache-2020"

	if [ -d "${binaries_target}/.git" ]; then
		echo "  ✓ liferay-binaries-cache-2020 already present"
	elif [ -d "${binaries_shared}/.git" ]; then
		log_cmd ln -s "$binaries_shared" "$binaries_target"
		echo "  ✓ liferay-binaries-cache-2020 linked from ${binaries_shared}"
	else
		log_step "Cloning liferay-binaries-cache-2020 (speeds up ant all)"

		log_cmd git clone --depth 1 --single-branch --branch master \
			git@github.com:liferay/liferay-binaries-cache-2020.git \
			"$binaries_target"
	fi
}

step_clone_portal() {
	local git_revision="${HOTFIX_GIT_REVISION:-$(resolve_git_revision)}"

	local product_version
	product_version=$(resolve_product_version)

	if [ -z "$product_version" ]; then
		product_version=$(resolve_product_version_from_gradle)
	fi

	if [ -z "$product_version" ]; then
		log_error "Could not resolve portal version."
		log_error "Set liferay.workspace.product in gradle.properties, or ensure bundles/patching-tool/patches/${HOTFIX_NAME:-liferay-dxp-*-hotfix-*}.zip exists or is reachable at releases-cdn.liferay.com."
		exit 1
	fi

	local parent_dir
	parent_dir=$(dirname "$LIFERAY_PORTAL_SOURCE")
	mkdir -p "$parent_dir"

	_clone_or_update_dxp "$git_revision" "$product_version"
	_ensure_binaries_cache "$parent_dir"
}

step_build_portal() {
	log_step "Building Liferay from source (this may take 30-60+ minutes on first run)"

	export ANT_OPTS="${ANT_OPTS:-} -Xms3g -Xmx3g"

	log_cmd ant -f "$LIFERAY_PORTAL_SOURCE/build.xml" setup-profile-dxp
	log_cmd ant -f "$LIFERAY_PORTAL_SOURCE/build.xml" all
}

step_prereqs() {
	log_step "Checking prerequisites"

	MISSING_PREREQS=false

	require "JDK 17+" "JDK 17+ is required" -- bash -c 'java -version 2>&1 | grep -qE "\"(17|18|19|20|21|22|23)\."'
	require "Docker"  "Docker is required"  -- docker --version
	require "jq"      "jq is required (brew install jq | apt install jq)" -- jq --version

	if [ "$LIFERAY_MODE" = "source" ]; then
		require "Apache Ant" "Apache Ant is required for source builds" -- ant -version

		step_clone_portal
		echo "  ✓ Portal home"

		step_build_portal

		# ant honors app.server.${user}.properties' app.server.parent.dir, which can
		# write the bundle somewhere other than $PORTAL_BUNDLES. Catch that mismatch
		# here instead of failing minutes later in step_start.
		local tomcat_dir
		tomcat_dir=$(find_tomcat_dir 2>/dev/null || echo "")

		if [ -z "$tomcat_dir" ] || [ ! -f "$tomcat_dir/bin/catalina.sh" ]; then
			log_error "Build finished but no tomcat-* found in $PORTAL_BUNDLES."
			log_error "Check app.server.\${user}.properties' app.server.parent.dir against paths.bundles in .liferay-workspace.json."
			exit 1
		fi

		echo "  ✓ Portal bundles"
	fi

	if [ "$MISSING_PREREQS" = true ]; then
		echo ""
		echo "  Install missing prerequisites and try again."
		exit 1
	fi
}