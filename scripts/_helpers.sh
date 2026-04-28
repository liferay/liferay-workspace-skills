#!/usr/bin/env bash
# General helpers — sourced by local_setup.sh.

docker_compose_cmd() {
	if [ "$LIFERAY_MODE" = "source" ]; then
		docker compose -f docker-compose.yml -f docker-compose.source.yml "$@"
	else
		docker compose "$@"
	fi
}

find_tomcat_dir() {
	local tomcat_dir=""

	if [ -n "${LIFERAY_PORTAL_SOURCE:-}" ] && [ -f "$LIFERAY_PORTAL_SOURCE/app.server.properties" ]; then
		local tomcat_version
		tomcat_version=$(grep -E '^\s*app\.server\.tomcat\.version=' "$LIFERAY_PORTAL_SOURCE/app.server.properties" | sed 's/.*=//' | tr -d '[:space:]')

		if [ -n "$tomcat_version" ] && [ -d "$PORTAL_BUNDLES/tomcat-$tomcat_version" ]; then
			tomcat_dir="$PORTAL_BUNDLES/tomcat-$tomcat_version"
		fi
	fi

	# shellcheck disable=SC2012
	if [ -z "$tomcat_dir" ]; then
		tomcat_dir=$(ls -td "$PORTAL_BUNDLES"/tomcat-* 2>/dev/null | head -1)
	fi

	if [ -z "$tomcat_dir" ]; then
		return 1
	fi

	echo "$tomcat_dir"
}

_force_kill() {
	local pid="$1"
	kill "$pid" 2>/dev/null || true
	sleep 1
	kill -0 "$pid" 2>/dev/null || return 0
	kill -9 "$pid" 2>/dev/null || true
}

check_required_ports() {
	local ports=(5432 1025 8025 9200 8090)

	if [ "$LIFERAY_MODE" = "docker" ]; then
		ports+=(8000 8080 11311)
	fi

	for port in "${ports[@]}"; do
		local pid
		pid=$(lsof -ti :"$port" 2>/dev/null || true)

		if [ -z "$pid" ]; then
			continue
		fi

		# If the port is published by a Docker container, stop the container
		# rather than killing the docker-proxy/Docker Desktop process (which
		# would crash Docker entirely).
		local container_id
		container_id=$(docker ps --format '{{.ID}}\t{{.Ports}}' 2>/dev/null | awk -v p=":${port}->" '$0 ~ p {print $1; exit}')

		if [ -n "$container_id" ]; then
			local container_name
			container_name=$(docker ps --format '{{.Names}}' --filter "id=$container_id" 2>/dev/null | head -1)
			echo -e "  ${YELLOW}Port $port held by docker container '${container_name}' — stopping it.${RESET}"
			docker stop "$container_id" >/dev/null 2>&1 || true
		else
			echo -e "  ${YELLOW}Port $port held by PID $pid — killing.${RESET}"
			_force_kill "$pid"
		fi
	done
}

detect_mode() {
	LIFERAY_MODE="docker"

	SETUP_ARGS=()
	for arg in "$@"; do
		case "$arg" in
			--source) LIFERAY_MODE="source" ;;
			*)        SETUP_ARGS+=("$arg") ;;
		esac
	done

	if [ "$LIFERAY_MODE" = "source" ]; then
		if [ ! -f ".env.source" ]; then
			log_error ".env.source not found. Copy .env.source.example and configure paths."
			exit 1
		fi

		# shellcheck disable=SC1091
		source .env.source

		PORTAL_BUNDLES="${LIFERAY_PORTAL_BUNDLES:-${LIFERAY_PORTAL_SOURCE}/bundles}"

		echo "liferay.workspace.home.dir=$PORTAL_BUNDLES" > gradle-local.properties
	else
		# Docker mode: ensure gradle module deploys go to ./bundles/, not lingering
		# source bundles from a previous --source run.
		rm -f gradle-local.properties
	fi
}

print_banner() {
	echo ""
	echo -e "  ${CYAN}${BOLD}Liferay Workspace${RESET} ${DIM}|${RESET} ${BOLD}Local Setup${RESET}"
	echo -e "  ${DIM}─────────────────────────────────${RESET}"
	echo -e "  ${DIM}Workspace:${RESET} ${SCRIPT_DIR}"

	if [ "$LIFERAY_MODE" = "source" ]; then
		echo -e "  ${DIM}Mode:${RESET}      ${CYAN}Source${RESET}"
		echo -e "  ${DIM}Bundles:${RESET}   ${PORTAL_BUNDLES}"
		echo -e "  ${DIM}Source:${RESET}    ${LIFERAY_PORTAL_SOURCE}"

		if [ -n "$HOTFIX_NAME" ]; then
			if [ -n "$HOTFIX_GIT_REVISION" ]; then
				echo -e "  ${DIM}Hotfix:${RESET}    ${HOTFIX_NAME} ${DIM}(${HOTFIX_GIT_REVISION:0:12})${RESET}"
			else
				echo -e "  ${DIM}Hotfix:${RESET}    ${HOTFIX_NAME}"
			fi
		fi
	else
		echo -e "  ${DIM}Mode:${RESET}      Docker"
		echo -e "  ${DIM}Bundles:${RESET}   ${SCRIPT_DIR}/bundles"

		if [ -n "$HOTFIX_NAME" ]; then
			echo -e "  ${DIM}Hotfix:${RESET}    ${HOTFIX_NAME}"
		fi
	fi

	echo ""
}

wait_for_log() {
	local message="$1"
	local label="$2"
	local timeout_seconds="${3:-${WAIT_FOR_LOG_TIMEOUT:-1800}}"
	local start_time=$SECONDS
	local found=false
	local log_pid=""

	echo "Waiting for ${label}..."

	# A named FIFO + tracked PID is more robust than a `cmd | while read` pipeline,
	# which would require pkill-by-name to clean up the tailer.
	local fifo
	fifo=$(mktemp -u /tmp/wait_for_log.XXXXXX)
	mkfifo "$fifo"

	if [ "$LIFERAY_MODE" = "source" ]; then
		local tomcat_dir
		tomcat_dir=$(find_tomcat_dir)
		local log_file="$tomcat_dir/logs/catalina.out"

		while [ ! -f "$log_file" ]; do
			if (( SECONDS - start_time >= timeout_seconds )); then
				rm -f "$fifo"
				echo "Error: Timed out waiting for ${label} log file to appear."
				return 1
			fi
			sleep 1
		done

		tail -f "$log_file" > "$fifo" 2>/dev/null &
		log_pid=$!
	else
		docker compose logs -f liferay --tail 0 > "$fifo" 2>/dev/null &
		log_pid=$!
	fi

	# Expand now: locals unbind before the RETURN trap fires under set -u.
	# shellcheck disable=SC2064
	trap "kill $log_pid 2>/dev/null; rm -f $fifo; true" RETURN

	while IFS= read -r line; do
		echo "$line"
		if echo "$line" | grep -q -- "$message"; then
			found=true
			break
		fi
		if (( SECONDS - start_time >= timeout_seconds )); then
			break
		fi
	done < "$fifo"

	if [ "$found" = true ]; then
		echo "${label} detected"
		return 0
	fi

	echo "Error: Timed out after $(format_duration "$timeout_seconds") waiting for '${label}'."
	return 1
}