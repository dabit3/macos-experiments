#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DART="${DART:-dart}"
PORT="${NT_PORT:-8788}"
OUT="$ROOT/apple/.derived/integration"
mkdir -p "$OUT"
if curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
  echo "Port $PORT already has a server. Choose another NT_PORT." >&2
  exit 1
fi
(
  cd "$ROOT/packages/nitro_server"
  "$DART" pub get
) >"$OUT/pub.log" 2>&1
(
  cd "$ROOT/packages/nitro_server"
  exec "$DART" run bin/nitro_server.dart --host 127.0.0.1 --port "$PORT" --seed 4242 --verbose
) >"$OUT/server.log" 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true' EXIT
READY=0
for _ in {1..100}; do
  if curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then READY=1; break; fi
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then cat "$OUT/server.log"; exit 1; fi
  sleep 0.1
done
if [ "$READY" != 1 ]; then cat "$OUT/server.log"; exit 1; fi
NT_SERVER="ws://127.0.0.1:$PORT/ws" bash "$ROOT/tools/test-native-protocol.sh"
