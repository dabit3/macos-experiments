#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
swift build -c release
APP="$ROOT/.app/TaskDeck.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/TaskDeck "$APP/Contents/MacOS/TaskDeck"
cp Info.plist "$APP/Contents/Info.plist"
ditto Fixtures "$APP/Contents/Resources/Fixtures"
codesign --force --sign - --identifier ai.typesafe.taskdeck "$APP"
if [[ "${1:-}" == "--build-only" ]]; then
  printf 'Built %s\n' "$APP"
  exit 0
fi
exec "$APP/Contents/MacOS/TaskDeck" "$@"
