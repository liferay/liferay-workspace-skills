#!/usr/bin/env bash
# Clone liferay-portal-ee at a specific ref (commit hash or release branch) and liferay-binaries-cache-2020.
# Usage: clone_portal.sh <PORTAL_SOURCE> <BUNDLE_CACHE> <REF>
#   REF: a commit SHA (e.g. abc1234) or a release branch (e.g. release-2026.q1.2)

set -euo pipefail

PORTAL_SOURCE="$1"
BUNDLE_CACHE="$2"
REF="$3"

echo "Cloning liferay-portal-ee → $PORTAL_SOURCE"
git clone git@github.com:liferay/liferay-portal-ee.git --no-checkout "$PORTAL_SOURCE"

echo "Checking out $REF"
git -C "$PORTAL_SOURCE" checkout "$REF"

if [ ! -d "$BUNDLE_CACHE" ]; then
  echo "Cloning liferay-binaries-cache-2020 → $BUNDLE_CACHE"
  git clone git@github.com:liferay/liferay-binaries-cache-2020.git "$BUNDLE_CACHE"
else
  echo "Binaries cache already exists at $BUNDLE_CACHE — skipping"
fi
