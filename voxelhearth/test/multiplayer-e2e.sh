#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
port="${VH_PORT:-18787}"
out="$root/.native-tests"
mkdir -p "$out"
dart="${DART:-dart}"
(cd "$root/server" && "$dart" pub get)
(cd "$root/server" && exec "$dart" run bin/server.dart --host 127.0.0.1 --port "$port" --save-dir "$out/saves" --seed 424242) >"$out/server.log" 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true' EXIT
ready=0
for _ in {1..100}; do
  if ! kill -0 "$server_pid" 2>/dev/null; then
    cat "$out/server.log"
    exit 1
  fi
  if curl --silent --fail "http://127.0.0.1:$port/health" >/dev/null; then
    ready=1
    break
  fi
  sleep 0.1
done
if [[ "$ready" != 1 ]]; then
  cat "$out/server.log"
  exit 1
fi
(cd "$root/apple/Core" && VH_INTEGRATION="ws://127.0.0.1:$port/ws" swift test -c release)
