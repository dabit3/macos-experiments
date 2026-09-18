#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
swift build --package-path "$ROOT" -c release
APP="$ROOT/dist/Watchword.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/Watchword" "$APP/Contents/MacOS/Watchword"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
ditto "$ROOT/Fixtures" "$APP/Contents/Resources/Fixtures"
codesign --force --sign - --identifier ai.typesafe.watchword "$APP" >/dev/null 2>&1
exec "$APP/Contents/MacOS/Watchword" "$@"
