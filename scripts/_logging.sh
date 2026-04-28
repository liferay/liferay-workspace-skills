#!/usr/bin/env bash
# Logging utilities — sourced by local_setup.sh

set -euo pipefail

BOLD='\033[1m'
CYAN='\033[36m'
YELLOW='\033[33m'
GREEN='\033[32m'
DIM='\033[2m'
RESET='\033[0m'

SETUP_START_TIME=$SECONDS
STEP_START_TIME=$SECONDS
LAST_STEP_NAME=""

format_duration() {
	local total_seconds=$1
	local hours=$((total_seconds / 3600))
	local minutes=$(( (total_seconds % 3600) / 60 ))
	local seconds=$((total_seconds % 60))

	if [ "$hours" -gt 0 ]; then
		printf '%dh %dm %ds' "$hours" "$minutes" "$seconds"
	elif [ "$minutes" -gt 0 ]; then
		printf '%dm %ds' "$minutes" "$seconds"
	else
		printf '%ds' "$seconds"
	fi
}

log_step_done() {
	if [ -n "$LAST_STEP_NAME" ]; then
		local elapsed=$(( SECONDS - STEP_START_TIME ))
		echo -e "  ${DIM}✓ ${LAST_STEP_NAME} completed in $(format_duration $elapsed)${RESET}"
	fi
}

log_cmd() {
	echo -e "  ${DIM}\$ $*${RESET}"
	"$@"
}

log_step() {
	log_step_done
	STEP_START_TIME=$SECONDS
	LAST_STEP_NAME="$1"
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	echo -e "\n  ${DIM}[${timestamp}]${RESET} ${YELLOW}${BOLD}>> $1${RESET}\n"
}

log_error() { echo -e "  ${BOLD}✗ $*${RESET}" >&2; }
log_warn()  { echo -e "  ${YELLOW}! $*${RESET}" >&2; }
