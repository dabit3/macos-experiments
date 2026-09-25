#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DART=${DART:-dart}
PORT=${LF_PORT:-8790}
OUT=${LF_OUT:-"$ROOT/test/output"}
mkdir -p "$OUT"
if curl --fail --silent "http://127.0.0.1:$PORT/health" >/dev/null; then
  echo "Port $PORT already has a server. Choose another LF_PORT." >&2
  exit 1
fi
(cd "$ROOT/server" && "$DART" pub get --enforce-lockfile)
(cd "$ROOT/server" && exec "$DART" run bin/server.dart --host 127.0.0.1 --port "$PORT" --fast --seed 4242) >"$OUT/server.log" 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true' EXIT
for ((attempt = 0; attempt < 100; attempt++)); do
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    cat "$OUT/server.log" >&2
    exit 1
  fi
  if curl --fail --silent "http://127.0.0.1:$PORT/health" >/dev/null; then break; fi
  sleep 0.1
done
curl --fail --silent "http://127.0.0.1:$PORT/health" >/dev/null
LASTFORT_TEST_SERVER="ws://127.0.0.1:$PORT/ws" \
  swift test --package-path "$ROOT/apple" --filter LiveServerTests 2>&1 | tee "$OUT/native-protocol.log"
