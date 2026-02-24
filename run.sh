#!/usr/bin/env bash
set -eu -o pipefail

: "${APP_HOME:="/app"}"
: "${DATA_DIR:="$APP_HOME/data"}"

mkdir -p "$DATA_DIR"

cd "$APP_HOME/uptime-kuma"

if [[ -n "${LITESTREAM_URL:-}" ]]; then
  # Generate litestream config only when replication is enabled
  "$APP_HOME/gen-config.sh"

  echo "Litestream enabled — restoring database from replica..."
  "$APP_HOME/litestream" restore -if-replica-exists -config "$APP_HOME/litestream.yml" "$DATA_DIR/kuma.db"

  echo "Starting Uptime Kuma under Litestream replication..."
  exec "$APP_HOME/litestream" replicate -config "$APP_HOME/litestream.yml" -exec "node server/server.js"
else
  echo "Litestream not configured — running Uptime Kuma standalone..."
  exec node server/server.js
fi
