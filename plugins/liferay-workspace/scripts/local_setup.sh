#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# All other paths in the scripts are relative to the workspace root.
cd "$WORKSPACE_DIR"

# Logging must load before helpers so log_error is in scope when detect_mode runs.
# shellcheck source=scripts/_logging.sh
source "$SCRIPT_DIR/_logging.sh"
# shellcheck source=scripts/_helpers.sh
source "$SCRIPT_DIR/_helpers.sh"

detect_mode "$@"

# shellcheck source=scripts/_prereqs.sh
source "$SCRIPT_DIR/_prereqs.sh"
# shellcheck source=scripts/_steps.sh
source "$SCRIPT_DIR/_steps.sh"

HOTFIX_NAME=$(resolve_hotfix_name)
HOTFIX_GIT_REVISION=""

if [ "$LIFERAY_MODE" = "source" ]; then
	HOTFIX_GIT_REVISION=$(resolve_git_revision)
fi

print_banner

usage() {
	echo "Usage: $0 [command] [--source]"
	echo ""
	echo "Commands:"
	echo "  (none)   Start workspace using existing bundles (no clean) — same as 'up'"
	echo "  up       Start workspace using existing bundles (no clean)"
	echo "  prereqs  Check required tools are installed"
	echo "  all      Run full setup with clean+rebuild (used by /setup reprocess)"
	echo "  clean    Stop containers and remove build artifacts (active mode only)"
	echo "  build    Build modules and client extensions"
	echo "  start    Start docker services and wait for Liferay"
	echo "  stop     Stop Liferay and docker services"
	echo "  license  Install DXP activation license"
	echo ""
	echo "Flags:"
	echo "  --source  Use locally-built source portal instead of Docker image"
	echo "            Requires .liferay-workspace.json with paths.source set."
	echo "            Run /setup to generate it."
	echo ""
	echo "Switching modes via 'up' (the default) does NOT clean the other mode's"
	echo "bundles. Re-run /setup to refresh scripts and rebuild from scratch."
	echo ""
}

run_up() {
	step_prereqs
	step_setup_env
	step_build
	step_start
	log_step_done
	echo -e "\n  ${GREEN}${BOLD}Workspace started.${RESET} ${DIM}Total time: $(format_duration $(( SECONDS - SETUP_START_TIME )))${RESET}\n"
}

command="${SETUP_ARGS[0]:-}"

case "$command" in
	"" | up)
		run_up
		;;
	all)
		# all is the full-reset path — let prereqs discard local modifications in
		# the portal source (e.g. ant's bnd.bnd/packageinfo bumps) when switching
		# versions. `up` leaves this unset and preserves user work.
		export FORCE_PORTAL_RESET=true
		step_prereqs
		step_setup_env
		step_clean
		step_build
		step_start
		if [ "$LIFERAY_MODE" != "source" ]; then
			step_license
		fi
		log_step_done
		echo -e "\n  ${GREEN}${BOLD}Local environment setup complete.${RESET} ${DIM}Total time: $(format_duration $(( SECONDS - SETUP_START_TIME )))${RESET}\n"
		;;
	prereqs)
		step_prereqs
		log_step_done
		;;
	clean)
		step_clean
		log_step_done
		;;
	build)
		step_build
		log_step_done
		;;
	start)
		step_start
		log_step_done
		;;
	stop)
		step_stop
		log_step_done
		;;
	license)
		step_license
		log_step_done
		;;
	help | -h | --help)
		usage
		;;
	*)
		echo "Unknown command: ${command}"
		usage
		exit 1
		;;
esac