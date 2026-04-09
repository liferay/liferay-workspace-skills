#!/usr/bin/env bash
# Generate .env file with UID/GID (Linux) and LIFERAY_VERSION from gradle.properties.
# Usage: setup_env.sh
# Must be run from the workspace root.

set -euo pipefail

if [ ! -f gradle.properties ]; then
  echo "Error: gradle.properties not found in $(pwd)"
  exit 1
fi

# Linux needs UID/GID for Docker volume permissions; macOS Docker Desktop handles mapping
if [ "$(uname)" != "Darwin" ]; then
  echo "UID=$(id -u)" > .env
  echo "GID=$(id -g)" >> .env
else
  rm -f .env && touch .env
fi

grep 'liferay.workspace.product=dxp-' gradle.properties \
  | sed 's/liferay.workspace.product=dxp-/LIFERAY_VERSION=/' >> .env

echo "Generated .env:"
cat .env
