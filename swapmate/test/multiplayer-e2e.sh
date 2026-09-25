#!/usr/bin/env bash
# Native Swift clients against an isolated authoritative Dart server; no UI automation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-18787}"
SEED="${SEED:-42}"
OUT="${OUT:-$ROOT/test/output/$(date -u +%Y%m%dT%H%M%SZ)}"
HTTP="http://127.0.0.1:$PORT"

command -v dart >/dev/null
command -v swift >/dev/null
if curl --silent --fail --max-time 1 "$HTTP/healthz" >/dev/null 2>&1; then
  echo "Port $PORT already has a server; choose another PORT." >&2
  exit 1
fi

mkdir -p "$OUT"
(cd "$ROOT/server" && dart pub get)
(cd "$ROOT/server" && exec dart run bin/server.dart --host 127.0.0.1 \
  --port "$PORT" --test --seed "$SEED" --bot-delay-ms 20) >"$OUT/server.log" 2>&1 &
SERVER_PID=$!
cleanup() {
  kill "$SERVER_PID" 2>/dev/null || true
  wait "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT TERM

READY=0
for ((attempt = 0; attempt < 100; attempt++)); do
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    cat "$OUT/server.log" >&2
    exit 1
  fi
  if curl --silent --fail --max-time 1 "$HTTP/healthz" >/dev/null; then
    READY=1
    break
  fi
  sleep 0.1
done
if [[ "$READY" != 1 ]]; then
  echo "Server startup timed out. See $OUT/server.log" >&2
  exit 1
fi

SWAPMATE_INTEGRATION_URL="ws://127.0.0.1:$PORT/ws" \
  swift test --package-path "$ROOT/apple" 2>&1 | tee "$OUT/native-tests.log"
echo "Native protocol integration passed. Logs: $OUT"
