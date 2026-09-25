#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dart="${DART:-dart}"
port="${PP_TEST_PORT:-18787}"
mkdir -p "$root/test/artifacts"
if curl --silent --fail "http://127.0.0.1:$port/health" >/dev/null; then
  echo "Port $port is already serving a backend; choose PP_TEST_PORT." >&2
  exit 1
fi
(
  cd "$root/server"
  "$dart" pub get >/dev/null
  exec "$dart" run bin/server.dart --host 127.0.0.1 --port "$port" --test-harness
) >"$root/test/artifacts/native-server.log" 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT
ready=0
for ((attempt=0; attempt<150; attempt++)); do
  if ! kill -0 "$pid" 2>/dev/null; then
    cat "$root/test/artifacts/native-server.log" >&2
    exit 1
  fi
  if curl --silent --fail "http://127.0.0.1:$port/health" >/dev/null; then
    ready=1
    break
  fi
  sleep 0.2
done
if [[ "$ready" != 1 ]]; then
  echo "Dart server did not become ready." >&2
  exit 1
fi
PP_INTEGRATION_SERVER="ws://127.0.0.1:$port/ws" swift test --package-path "$root/apple"
