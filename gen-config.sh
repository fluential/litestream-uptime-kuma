#!/usr/bin/env bash
set -eu -o pipefail

: "${APP_HOME:="/app"}"
: "${LITESTREAM_BUCKET:="uptime-kuma"}"
: "${LITESTREAM_PATH:="uptime-kuma-db"}"
: "${DATA_DIR:="$APP_HOME/data"}"
: "${LITESTREAM_SYNC_INTERVAL:="30s"}"
: "${LITESTREAM_SNAPSHOT_INTERVAL:="1h"}"

cat <<EOF > "$APP_HOME"/litestream.yml
dbs:
  - path: "$DATA_DIR/kuma.db"
    replica:
      type: s3
      bucket: "$LITESTREAM_BUCKET"
      path: "$LITESTREAM_PATH"
      endpoint: "$LITESTREAM_URL"
      access-key-id: "$LITESTREAM_ACCESS_KEY_ID"
      secret-access-key: "$LITESTREAM_SECRET_ACCESS_KEY"
      sync-interval: $LITESTREAM_SYNC_INTERVAL
      snapshot-interval: $LITESTREAM_SNAPSHOT_INTERVAL
EOF

echo "Litestream config generated."
