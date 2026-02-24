#!/usr/bin/env bash
set -eu -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.test.yml"
IMAGE_NAME="litestream-uptime-kuma:test"

cleanup() {
  echo "[e2e] Tearing down..."
  docker compose -f "$COMPOSE_FILE" down -v --remove-orphans 2>/dev/null || true
}
trap cleanup EXIT

echo "[e2e] =========================================="
echo "[e2e] Litestream + Uptime Kuma E2E Test"
echo "[e2e] =========================================="

# 1. Build image if not exists
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
  echo "[e2e] Building image..."
  docker build -t "$IMAGE_NAME" "$PROJECT_DIR"
fi

# 2. Install socket.io-client locally for the test script
if [ ! -d "$SCRIPT_DIR/node_modules/socket.io-client" ]; then
  echo "[e2e] Installing test dependencies..."
  cd "$SCRIPT_DIR" && npm install --no-save socket.io-client 2>&1 | tail -1
fi

# 3. Start services
echo "[e2e] Starting services..."
docker compose -f "$COMPOSE_FILE" up -d

# 4. Run the test
echo "[e2e] Running tests..."
cd "$SCRIPT_DIR" && node e2e-test.mjs
EXIT_CODE=$?

# 5. Show logs if failed
if [ $EXIT_CODE -ne 0 ]; then
  echo "[e2e] FAILED — dumping logs..."
  docker compose -f "$COMPOSE_FILE" logs uptime-kuma 2>&1 | tail -30
fi

exit $EXIT_CODE
