#!/usr/bin/env bash
set -eux -o pipefail

: "${APP_HOME:="$(pwd)"}"
: "${LITESTREAM_BUCKET:="uptime-kuma"}"
: "${LITESTREAM_PATH:="uptime-kuma-db"}"
: "${DATA_DIR:="$APP_HOME/fs/"}"

cat <<EOF > "$APP_HOME"/litestream.yml
dbs:
  - path: "$DATA_DIR/kuma.db"
    replicas:
      - type: s3
        bucket: "$LITESTREAM_BUCKET"
        path: "$LITESTREAM_PATH"
        endpoint: "$LITESTREAM_URL"
        access-key-id: "$LITESTREAM_ACCESS_KEY_ID"
        secret-access-key: "$LITESTREAM_SECRET_ACCESS_KEY"
        snapshot-interval: 12h
        retention: 72h
EOF

echo "Done Litestream config."

