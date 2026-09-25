#!/usr/bin/env bash
# Restart a fresh deterministic test-mode server on :8787 serving the web build.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
save="${VH_SAVE_DIR:-/tmp/vh-saves}"
pkill -f "bin/server.dart" 2>/dev/null || true
sleep 0.5
rm -rf "$save"
mkdir -p "$save"
cd "$here/../server"
nohup dart run bin/server.dart --test-mode --seed "${VH_SEED:-1234}" --save-dir "$save" \
  --web-root ../app/build/web --port "${VH_PORT:-8787}" >"${VH_SERVER_LOG:-/tmp/vh-server.log}" 2>&1 &
for _ in $(seq 1 60); do
  if curl -sf "http://localhost:${VH_PORT:-8787}/health" >/dev/null 2>&1; then
    echo "server up"
    exit 0
  fi
  sleep 0.5
done
echo "server failed to start" >&2
cat "${VH_SERVER_LOG:-/tmp/vh-server.log}" >&2
exit 1
