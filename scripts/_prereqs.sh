#!/usr/bin/env bash
# Prerequisite checks and portal source setup — sourced by local_setup.sh.
# Strict mode (set -euo pipefail) is set once in the entry script.

require() {
	local name="$1"
	local check="$2"
	local message="$3"

	if ! eval "$check" &>/dev/null; then
		echo "  ✗ ${name} — ${message}"
		MISSING_PREREQS=true
	else
		echo "  ✓ ${name}"
	fi
}

resolve_hotfix_name() {
	if [ "${LIFERAY_MODE:-docker}" = "source" ]; then
		local lcp_json="${SCRIPT_DIR}/../ci/LCP.json"

		if [ ! -f "$lcp_json" ]; then
			echo ""
			return
		fi

		python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('env',{}).get('LCP_CI_LIFERAY_DXP_HOTFIXES_COMMON',''))" < "$lcp_json"
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

_hotfix_zip_path() {
	local hotfix_name="${HOTFIX_NAME:-}"

	if [ -z "$hotfix_name" ]; then
		echo ""
		return
	fi

	local version
	version=$(echo "$hotfix_name" | sed 's/^liferay-dxp-\(.*\)-hotfix-[0-9]*$/\1/')

	local zip="${HOME}/.liferay/hotfixes/${version}/${hotfix_name}.zip"

	if [ -f "$zip" ]; then
		echo "$zip"
	else
		echo ""
	fi
}

# Extracts a value from hotfix.json using a dot-separated key path.
# Tries the local hotfix zip first, then falls back to the bundles directory.
_read_hotfix_json() {
	local json_path="$1"
	local python_script='
import sys, json
d = json.load(sys.stdin)
for k in sys.argv[1].split("."):
    d = d[k]
print(d)
'
	local zip
	zip=$(_hotfix_zip_path)

	if [ -n "$zip" ]; then
		unzip -p "$zip" hotfix.json 2>/dev/null \
			| python3 -c "$python_script" "$json_path" 2>/dev/null \
			|| true
		return
	fi

	local bundles_dir="${PORTAL_BUNDLES:-bundles}"
	local -a hotfix_jsons=()
	shopt -s nullglob
	hotfix_jsons=( "$bundles_dir"/patching-tool/patches/liferay-dxp-*-hotfix-*/hotfix.json )
	shopt -u nullglob

	if [ ${#hotfix_jsons[@]} -eq 0 ]; then
		echo ""
		return
	fi

	python3 -c "$python_script" "$json_path" 2>/dev/null < "${hotfix_jsons[0]}" || true
}

resolve_git_revision()    { _read_hotfix_json "build.git-revision"; }
resolve_product_version() { _read_hotfix_json "requirement.product-version"; }

_clone_or_update_portal_ee() {
	local git_revision="$1"
	local product_version="$2"

	if [ -d "$LIFERAY_PORTAL_SOURCE/.git" ]; then
		local current_commit
		current_commit=$(git -C "$LIFERAY_PORTAL_SOURCE" rev-parse HEAD 2>/dev/null || echo "")

		if [ "$current_commit" = "$git_revision" ]; then
			echo "  ✓ liferay-portal-ee already at ${git_revision:0:12}"
		else
			log_step "Updating liferay-portal-ee to commit ${git_revision:0:12} (was ${current_commit:0:12})"

			log_cmd git -C "$LIFERAY_PORTAL_SOURCE" fetch origin "$git_revision" --depth 1
			log_cmd git -C "$LIFERAY_PORTAL_SOURCE" checkout "$git_revision"
		fi
	else
		log_step "Cloning liferay-portal-ee at tag ${product_version} (commit ${git_revision:0:12})"

		log_cmd git clone --depth 1 --single-branch --branch "$product_version" \
			git@github.com:liferay/liferay-portal-ee.git "$LIFERAY_PORTAL_SOURCE"

		log_cmd git -C "$LIFERAY_PORTAL_SOURCE" fetch origin "$git_revision" --depth 1
		log_cmd git -C "$LIFERAY_PORTAL_SOURCE" checkout "$git_revision"
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

	if [ -z "$git_revision" ] || [ -z "$product_version" ]; then
		log_error "Could not resolve git revision from hotfix.json."
		log_error "Ensure bundles/patching-tool/patches/liferay-dxp-*-hotfix-*/hotfix.json exists."
		exit 1
	fi

	local parent_dir
	parent_dir=$(dirname "$LIFERAY_PORTAL_SOURCE")
	mkdir -p "$parent_dir"

	_clone_or_update_portal_ee "$git_revision" "$product_version"
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

	require "JDK 17+" "java -version 2>&1 | grep -qE '\"(17|18|19|20|21|22|23)\.'" "JDK 17+ is required"
	require "Docker" "docker --version" "Docker is required"

	if [ "$LIFERAY_MODE" = "source" ]; then
		require "Apache Ant" "ant -version" "Apache Ant is required for source builds"

		step_clone_portal
		echo "  ✓ Portal home"

		local tomcat_dir
		tomcat_dir=$(find_tomcat_dir 2>/dev/null || echo "")

		local portal_osgi_ok=false
		# shellcheck disable=SC2086
		if compgen -G "$PORTAL_BUNDLES/osgi/portal/com.liferay.portal.file.install.impl-*.jar" > /dev/null 2>&1; then
			portal_osgi_ok=true
		fi

		if [ -z "$tomcat_dir" ] || [ ! -f "$tomcat_dir/bin/catalina.sh" ] || [ "$portal_osgi_ok" = false ]; then
			echo "  ✗ Portal bundles — missing Tomcat or core OSGi bundles in $PORTAL_BUNDLES"
			echo ""
			echo "  Building portal from source..."
			step_build_portal
			echo "  ✓ Portal bundles"
		else
			echo "  ✓ Portal bundles"
		fi
	fi

	if [ "$MISSING_PREREQS" = true ]; then
		echo ""
		echo "  Install missing prerequisites and try again."
		exit 1
	fi
}