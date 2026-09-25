#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcrun swift-format lint --strict --recursive "$ROOT/Sources" "$ROOT/Tests" \
  "$ROOT/Package.swift" "$ROOT/scripts/RenderAudio.swift"
swift test --package-path "$ROOT"
mkdir -p "$ROOT/build/audio"
swiftc "$ROOT/Sources/Core.swift" "$ROOT/scripts/RenderAudio.swift" -o "$ROOT/build/render-audio"
"$ROOT/build/render-audio" "$ROOT/build/audio"
