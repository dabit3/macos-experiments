#!/usr/bin/env bash
# One-command local play on macOS: checks prerequisites, builds the macOS
# client, starts the Dart server and launches the app connected to it.
#
#   bash run.sh                # survival room, player name from $USER
#   VH_NAME=Alice bash run.sh  # custom name
#   VH_PORT=9000 bash run.sh   # custom server port
#   bash run.sh --no-build     # reuse the last build
#
# Quitting the app (or Ctrl-C) also stops the server.
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
port="${VH_PORT:-8787}"
name="${VH_NAME:-$USER}"
build=1
for arg in "$@"; do
  case "$arg" in
    --no-build) build=0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

fail() { echo "error: $*" >&2; exit 1; }

if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find xcodebuild >/dev/null 2>&1; then
  fail "full Xcode is required (https://developer.apple.com/xcode/); run 'sudo xcode-select -s /Applications/Xcode.app' after installing"
fi

if ! command -v dart >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "==> dart not found; installing dart-sdk with Homebrew"
    brew install dart-sdk
  else
    fail "dart not found; install with 'brew install dart-sdk' or from https://dart.dev/get-dart"
  fi
fi

if [[ "$build" == 1 ]]; then
  if ! xcrun --find metal >/dev/null 2>&1 || ! xcrun metal --version >/dev/null 2>&1; then
    echo "==> Metal Toolchain not installed; downloading (~700 MB)"
    xcodebuild -downloadComponent MetalToolchain \
      || xcodebuild -downloadComponent MetalToolchain \
      || fail "could not download the Metal Toolchain; retry 'xcodebuild -downloadComponent MetalToolchain'"
  fi

  echo "==> Building VoxelHearth-macOS"
  xcodebuild -project "$root/apple/VoxelHearth.xcodeproj" -scheme VoxelHearth-macOS \
    -destination 'platform=macOS' -derivedDataPath "$root/apple/DerivedData" \
    CODE_SIGNING_ALLOWED=NO -quiet build
fi

app="$root/apple/DerivedData/Build/Products/Debug/VoxelHearth.app"
[[ -x "$app/Contents/MacOS/VoxelHearth" ]] || fail "no build at $app; run without --no-build"

echo "==> Starting server on port $port"
(cd "$root/server" && dart pub get >/dev/null)
mkdir -p "$root/server/saves"
(cd "$root/server" && exec dart run bin/server.dart --host 0.0.0.0 --port "$port" \
  --save-dir saves --seed 424242) &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true' EXIT

for _ in {1..300}; do
  kill -0 "$server_pid" 2>/dev/null || fail "server exited"
  curl --silent --fail "http://127.0.0.1:$port/health" >/dev/null && break
  sleep 0.1
done
curl --silent --fail "http://127.0.0.1:$port/health" >/dev/null || fail "server did not become healthy"

echo "==> Launching VoxelHearth as $name (creating a room)"
VH_SERVER="ws://127.0.0.1:$port/ws" VH_NAME="$name" VH_CREATE=1 \
  "$app/Contents/MacOS/VoxelHearth"
