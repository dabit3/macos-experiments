#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
BIN="$(swift build -c release --show-bin-path)"
APP="$PWD/.build/IntentFinder.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/IntentFinder" "$APP/Contents/MacOS/IntentFinder"
cp Info.plist "$APP/Contents/Info.plist"
cp -R "$BIN/IntentFinder_IntentCore.bundle" "$APP/Contents/Resources/"
"$BIN/intent-check" fixtures "$APP/Contents/Resources/Demo Vault"
codesign --force --deep --sign - "$APP"
if [[ "${1:-}" == "--build-only" ]]; then
  printf 'Built %s\n' "$APP"
  exit 0
fi
export INTENTFINDER_DEMO_DIR="$APP/Contents/Resources/Demo Vault"
exec "$APP/Contents/MacOS/IntentFinder" "$@"
