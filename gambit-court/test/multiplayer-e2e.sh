#!/usr/bin/env bash
# Exercises native Codable/URLSession clients against the real Dart server.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DART="${DART:-dart}"
PORT="${SERVER_PORT:-18765}"
LOGS="$ROOT/apple/build/protocol"
command -v "$DART" >/dev/null
command -v swift >/dev/null
command -v curl >/dev/null
mkdir -p "$LOGS"
if curl --silent --fail --max-time 1 "http://127.0.0.1:$PORT/health" >/dev/null; then
  echo "Port $PORT already has a server. Choose a different SERVER_PORT." >&2
  exit 1
fi
(cd "$ROOT/server" && "$DART" pub get)
(
  cd "$ROOT/server"
  exec "$DART" run bin/server.dart --host 127.0.0.1 --port "$PORT" \
    --seed 8 --frozen-clocks --bot-delay-ms 0
) >"$LOGS/server.log" 2>&1 &
SERVER_PID=$!
cleanup() { kill "$SERVER_PID" 2>/dev/null || true; }
trap cleanup EXIT
if ! curl --silent --show-error --fail --retry 30 --retry-connrefused \
  --retry-delay 1 --max-time 2 "http://127.0.0.1:$PORT/health" >"$LOGS/health.json"; then
  cat "$LOGS/server.log" >&2
  exit 1
fi
kill -0 "$SERVER_PID"
(
  cd "$ROOT/apple"
  GC_INTEGRATION_SERVER="ws://127.0.0.1:$PORT/ws" swift test
) 2>&1 | tee "$LOGS/swift-tests.log"
