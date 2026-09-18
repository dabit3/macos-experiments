#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP="$PWD/build/MenuLens.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MenuLens "$APP/Contents/MacOS/MenuLens"
cp Info.plist "$APP/Contents/Info.plist"
cp Fixtures/Dispatch.rtf "$APP/Contents/Resources/Dispatch.rtf"
codesign --force --sign - --identifier ai.typesafe.demo.MenuLens "$APP"
if [[ "${1:-}" == "--build-only" ]]; then
  printf 'Built %s\n' "$APP"
  exit 0
fi
exec "$APP/Contents/MacOS/MenuLens" "$@"
