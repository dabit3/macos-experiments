#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
swift build -c release >&2
BIN="$(swift build -c release --show-bin-path)"
APP="$ROOT/.build/PastePilot.app"
FORM="$APP/Contents/Resources/VendorForm.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$FORM/Contents/MacOS"
cp "$BIN/PastePilot" "$APP/Contents/MacOS/PastePilot"
cp "$BIN/VendorForm" "$FORM/Contents/MacOS/VendorForm"
cp "$ROOT/Fixtures/vendor-brief.txt" "$APP/Contents/Resources/vendor-brief.txt"
cp "$ROOT/scripts/PastePilot.plist" "$APP/Contents/Info.plist"
cp "$ROOT/scripts/VendorForm.plist" "$FORM/Contents/Info.plist"
codesign --force --sign - --identifier ai.typesafe.demo.VendorForm "$FORM" >&2
codesign --force --sign - --identifier ai.typesafe.demo.PastePilot "$APP" >&2
if [[ "${1:-}" == "--build-only" ]]; then
  printf '%s\n' "$APP"
  exit 0
fi
exec "$APP/Contents/MacOS/PastePilot" "$@"
