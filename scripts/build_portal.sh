#!/usr/bin/env bash
# Build Liferay Portal from source using ant setup-profile-dxp + ant all.
# Usage: build_portal.sh <PORTAL_SOURCE>
#   PORTAL_SOURCE: absolute path to the liferay-portal-ee checkout

set -euo pipefail

PORTAL_SOURCE="$1"

if [ ! -d "$PORTAL_SOURCE" ]; then
  echo "Error: $PORTAL_SOURCE is not a directory"
  exit 1
fi

cd "$PORTAL_SOURCE"

echo "Running ant setup-profile-dxp..."
ANT_OPTS="-Xms3g -Xmx3g" ant setup-profile-dxp

echo "Running ant all (this may take 30–60+ minutes on first run)..."
ANT_OPTS="-Xms3g -Xmx3g" ant all

echo "✓ Portal build complete"
