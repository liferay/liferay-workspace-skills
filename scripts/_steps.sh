#!/usr/bin/env bash
# Setup step functions — sourced by local_setup.sh.

readonly LOG_MARKER_TOMCAT_STARTUP='org.apache.catalina.startup.Catalina.start Server startup'
readonly LOG_MARKER_WELCOME_SITE='Initialized com.liferay.site.initializer.welcome'
readonly LOG_MARKER_LICENSE='License registered for DXP Development'

step_setup_env() {
	if [ "$LIFERAY_MODE" = "docker" ]; then
		log_step "Setting up Docker environment"

		mkdir -p tmp
		rm -f .env
		touch .env

		if [ "$(uname)" = "Darwin" ]; then
			echo "UID=1000" >> .env
			echo "GID=1000" >> .env
		else
			echo "UID=$(id -u)" >> .env
			echo "GID=$(id -g)" >> .env
		fi

		local liferay_version
		liferay_version=$(sed -n '/liferay.workspace.product=dxp-/{s/liferay.workspace.product=dxp-//g; p;}' gradle.properties)
		echo "LIFERAY_VERSION=$liferay_version" >> .env
	fi
}

step_clean() {
	log_step "Cleaning environment"

	if [ "$LIFERAY_MODE" = "source" ]; then
		for port in 8080 8000; do
			local pid
			pid=$(lsof -ti :"$port" 2>/dev/null || true)
			if [ -n "$pid" ]; then
				echo "  Killing process on port $port (PID $pid)"
				_force_kill "$pid"
			fi
		done
	fi

	log_cmd docker_compose_cmd down --remove-orphans

	# Force-remove stale containers from prior runs that may have used a different
	# compose project name. Our docker-compose.yml pins explicit container_name
	# values, so a same-named stopped container blocks recreate.
	local stale_names=(lr db es sn)
	for name in "${stale_names[@]}"; do
		if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$name"; then
			echo -e "  ${YELLOW}Removing stale container '${name}'${RESET}"
			docker rm -f "$name" >/dev/null 2>&1 || true
		fi
	done

	check_required_ports

	if [ "$LIFERAY_MODE" = "source" ]; then
		# Only remove workspace-owned subdirectories; preserve portal-built OSGi bundles
		# (osgi/core, osgi/portal, osgi/static, etc.) that "ant all" populates.
		log_cmd rm -rf \
			"$PORTAL_BUNDLES/data" \
			"$PORTAL_BUNDLES/deploy" \
			"$PORTAL_BUNDLES/logs" \
			"$PORTAL_BUNDLES/routes" \
			"$PORTAL_BUNDLES/osgi/configs" \
			"$PORTAL_BUNDLES/osgi/modules" \
			"$PORTAL_BUNDLES/osgi/client-extensions"
	else
		log_cmd rm -rf bundles/data bundles/deploy bundles/logs bundles/osgi bundles/routes bundles/esdata
	fi
	# Scope to known workspace subdirs so a misinvocation from the wrong CWD
	# can't recursively wipe unrelated trees.
	local -a clean_targets=()
	for dir in modules client-extensions; do
		[ -d "$dir" ] && clean_targets+=("$dir")
	done

	if [ ${#clean_targets[@]} -gt 0 ]; then
		log_cmd find "${clean_targets[@]}" -depth -type d \( -name node_modules_cache -o -name node_modules -o -name dist -o -name build \) -exec rm -rf {} \;
	fi
}

step_build() {
	log_step "Building modules and client extensions"

	if [ -d modules ] && compgen -G "modules/*/build.gradle" > /dev/null; then
		log_cmd ./gradlew -p modules deploy
	else
		echo "  — skipped modules (no build.gradle found)"
	fi

	if [ -d client-extensions ] && compgen -G "client-extensions/*/build.gradle" > /dev/null; then
		log_cmd ./gradlew -p client-extensions deploy
	else
		echo "  — skipped client-extensions (no build.gradle found)"
	fi
}

step_start() {
	if [ "$LIFERAY_MODE" = "source" ]; then
		log_step "Starting supporting services"

		log_cmd docker_compose_cmd up -d

		log_step "Copying portal properties for source mode"

		local tomcat_dir
		if ! tomcat_dir=$(find_tomcat_dir); then
			log_error "Could not find tomcat-* under $PORTAL_BUNDLES."
			log_error "Portal source build is missing. Run: bash scripts/local_setup.sh prereqs --source"
			exit 1
		fi

		local prop
		for prop in \
			configs/common/portal-ext.properties \
			configs/common/portal-all.properties \
			configs/source/portal-env.properties \
			configs/common/portal-setup-wizard.properties; do
			if [ -f "$prop" ]; then
				log_cmd cp "$prop" "$PORTAL_BUNDLES/"
			fi
		done

		mkdir -p "$PORTAL_BUNDLES/osgi/configs"
		shopt -s nullglob
		local -a osgi_configs=(configs/source/osgi/configs/*.config)
		shopt -u nullglob
		if [ ${#osgi_configs[@]} -gt 0 ]; then
			log_cmd cp "${osgi_configs[@]}" "$PORTAL_BUNDLES/osgi/configs/"
		fi

		mkdir -p "$PORTAL_BUNDLES/deploy"
		mkdir -p "$PORTAL_BUNDLES/osgi/modules"
		mkdir -p "$PORTAL_BUNDLES/osgi/client-extensions"

		log_step "Starting Liferay from source ($tomcat_dir)"

		export CATALINA_OPTS="${CATALINA_OPTS:-} -Xms4g -Xmx4g -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:8000"

		log_cmd "$tomcat_dir/bin/catalina.sh" start

		wait_for_log "$LOG_MARKER_TOMCAT_STARTUP" "Liferay startup"
	else
		log_step "Starting docker services"

		log_cmd docker_compose_cmd up -d

		wait_for_log "$LOG_MARKER_WELCOME_SITE" "Liferay Welcome Site"
	fi
}

step_stop() {
	if [ "$LIFERAY_MODE" = "source" ]; then
		log_step "Stopping Liferay and supporting services"

		local tomcat_dir
		tomcat_dir=$(find_tomcat_dir)

		log_cmd "$tomcat_dir/bin/catalina.sh" stop || true
		log_cmd docker_compose_cmd down
	else
		log_step "Stopping docker services"

		log_cmd docker_compose_cmd down
	fi
}

_resolve_license_path() {
	local config=".liferay-workspace.json"

	if [ -f "$config" ]; then
		local from_config
		from_config=$(jq -r '.paths.license // ""' "$config" 2>/dev/null || true)

		if [ -n "$from_config" ] && [ -f "$from_config" ]; then
			echo "$from_config"
			return
		fi
	fi

	# Fallback: pick the newest activation key under ~/.liferay/activation/
	local fallback
	# shellcheck disable=SC2012
	fallback=$(ls -t "$HOME"/.liferay/activation/activation-key-*.xml 2>/dev/null | head -1)
	echo "$fallback"
}

step_license() {
	log_step "Installing DXP license"

	local license_target="bundles/osgi/modules"
	if [ "$LIFERAY_MODE" = "source" ]; then
		license_target="$PORTAL_BUNDLES/osgi/modules"
	fi

	local license_path
	license_path=$(_resolve_license_path)

	if [ -z "$license_path" ] || [ ! -f "$license_path" ]; then
		log_error "No DXP activation license found."
		log_error "Set paths.license in .liferay-workspace.json or place a key at ~/.liferay/activation/activation-key-*.xml"
		exit 1
	fi

	log_cmd cp "$license_path" "$license_target"

	wait_for_log "$LOG_MARKER_LICENSE" "DXP License"
}
