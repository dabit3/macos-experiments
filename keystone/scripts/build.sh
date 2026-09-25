#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release
APP="$ROOT/dist/Keystone.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/Keystone" "$APP/Contents/MacOS/Keystone"
cp "$ROOT/scripts/Info.plist" "$APP/Contents/Info.plist"
xcrun swift "$ROOT/scripts/Icon.swift" "$APP/Contents/Resources"
codesign --force --sign - "$APP"
echo "Built native macOS app: $APP"
