#!/usr/bin/env bash
# Start Liferay in source mode: docker services, portal configs, Tomcat.
# Usage: start_source.sh
# Must be run from the workspace root. Requires .env.source.

set -euo pipefail

if [ ! -f .env.source ]; then
  echo "Error: .env.source not found in $(pwd)"
  exit 1
fi

# shellcheck disable=SC1091
source .env.source

# Start DB, Search, Mail (liferay container disabled by docker-compose.source.yml)
echo "Starting supporting services..."
docker compose -f docker-compose.yml -f docker-compose.source.yml up -d

# Copy portal configs
echo "Copying portal configs..."
cp configs/common/portal-ext.properties "$PORTAL_BUNDLES/"
cp configs/source/portal-env.properties "$PORTAL_BUNDLES/"
cp -r configs/source/osgi/configs/. "$PORTAL_BUNDLES/osgi/configs/"
mkdir -p "$PORTAL_BUNDLES/osgi/modules" \
         "$PORTAL_BUNDLES/osgi/client-extensions" \
         "$PORTAL_BUNDLES/deploy"

# Stop any stale Tomcat before starting (prevents port conflicts across sessions)
echo "Clearing stale processes..."
"$PORTAL_BUNDLES/tomcat-"*/bin/catalina.sh stop 2>/dev/null || true
sleep 2
for port in 8080 8000; do
  pid=$(lsof -ti :"$port" 2>/dev/null || true)
  [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null || true
done

# Wait for DB to be healthy before starting Tomcat (avoids connection-refused flood)
echo "Waiting for DB..."
until docker compose exec -T database pg_isready -q 2>/dev/null; do sleep 2; done
echo "DB is ready"

# Start Tomcat
echo "Starting Tomcat..."
CATALINA_OPTS="-Xms4g -Xmx4g -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:8000" \
  "$PORTAL_BUNDLES/tomcat-"*/bin/catalina.sh start

echo "✓ Liferay started from source"
