#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
port="${BRICKFOLK_TEST_PORT:-8088}"
output="$root/apple/build/protocol"
mkdir -p "$output"
if curl --connect-timeout 1 --max-time 1 -fsS "http://127.0.0.1:$port/health" >/dev/null 2>&1; then
  echo "Port $port already has a server. Choose BRICKFOLK_TEST_PORT for an isolated test." >&2
  exit 1
fi
(cd "$root/server" && dart pub get)
swift build --package-path "$root/apple" --product brickfolk-protocol-probe
(
  cd "$root/server"
  exec dart run bin/server.dart --host 127.0.0.1 --port "$port" --db :memory: \
    --test-mode --seed 73 --match-length-scale "${BRICKFOLK_MATCH_SCALE:-0.08}" --results-ms 1000
) >"$output/server.log" 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true' EXIT
ready=false
for ((attempt = 0; attempt < 60; attempt++)); do
  if ! kill -0 "$server_pid" 2>/dev/null; then cat "$output/server.log" >&2; exit 1; fi
  if curl --connect-timeout 1 --max-time 1 -fsS "http://127.0.0.1:$port/health" >"$output/health.json" 2>/dev/null; then
    ready=true
    break
  fi
  sleep 1
done
if [[ "$ready" != true ]]; then cat "$output/server.log" >&2; exit 1; fi
swift run --skip-build --package-path "$root/apple" brickfolk-protocol-probe \
  "ws://127.0.0.1:$port/ws" 2>&1 | tee "$output/probe.log"
echo "Native protocol integration passed. Logs: $output"
