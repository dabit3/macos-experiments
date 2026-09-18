#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
swift build -c release
APP="$ROOT/dist/ShareStage.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ShareStage "$APP/Contents/MacOS/ShareStage"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --identifier ai.typesafe.sharestage "$APP"
if [[ "${1:-}" == "--build-only" ]]; then
  printf 'Built %s\n' "$APP"
  exit 0
fi
exec "$APP/Contents/MacOS/ShareStage" "$@"
