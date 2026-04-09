#!/usr/bin/env bash
# Clean Liferay Workspace artifacts.
# Usage: clean.sh [--docker] [--bundles] [--build] [--portal-home] [--all]
# Must be run from the workspace root.

set -euo pipefail

DO_DOCKER=false
DO_BUNDLES=false
DO_BUILD=false
DO_PORTAL_HOME=false

if [ $# -eq 0 ]; then
  echo "Usage: clean.sh [--docker] [--bundles] [--build] [--portal-home] [--all]"
  exit 1
fi

for arg in "$@"; do
  case "$arg" in
    --docker)      DO_DOCKER=true ;;
    --bundles)     DO_BUNDLES=true ;;
    --build)       DO_BUILD=true ;;
    --portal-home) DO_PORTAL_HOME=true ;;
    --all)         DO_DOCKER=true; DO_BUNDLES=true; DO_BUILD=true ;;
    *) echo "Unknown flag: $arg"; exit 1 ;;
  esac
done

if [ "$DO_DOCKER" = true ]; then
  echo "Stopping containers..."
  docker compose down --remove-orphans -v
  echo "✓ Docker"
fi

if [ "$DO_BUNDLES" = true ]; then
  echo "Removing bundle data..."
  rm -rf bundles/data bundles/deploy bundles/logs bundles/osgi bundles/routes bundles/esdata
  echo "✓ Bundles"
fi

if [ "$DO_BUILD" = true ]; then
  echo "Removing build artifacts..."
  find . -depth -type d \( -name node_modules_cache -o -name node_modules -o -name dist -o -name build \) -exec rm -rf {} \;
  echo "✓ Build"
fi

if [ "$DO_PORTAL_HOME" = true ]; then
  if [ ! -f .env.source ]; then
    echo "Error: .env.source not found — cannot clean portal home"
    exit 1
  fi

  # shellcheck disable=SC1091
  source .env.source

  echo "Killing processes on ports 8080/8000..."
  for port in 8080 8000; do
    pid=$(lsof -ti :"$port" 2>/dev/null || true)
    if [ -n "$pid" ]; then
      kill "$pid" 2>/dev/null || true
    fi
  done

  echo "Removing $PORTAL_BUNDLES..."
  rm -rf "$PORTAL_BUNDLES"
  echo "✓ Portal home"
fi
