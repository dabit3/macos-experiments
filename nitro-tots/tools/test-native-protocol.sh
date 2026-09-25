#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/apple/.derived/protocol"
mkdir -p "$OUT"
swiftc -swift-version 5 -O \
  "$ROOT"/apple/Core/Sources/NitroCore/*.swift \
  "$ROOT/apple/App/Storage.swift" "$ROOT/apple/App/Connection.swift" \
  "$ROOT/apple/App/RaceSession.swift" "$ROOT/apple/App/AppModel.swift" "$ROOT/tools/ProtocolSmoke.swift" \
  -o "$OUT/nitro-protocol"
cp "$ROOT/apple/Core/Sources/NitroCore/Resources/catalog.json" "$OUT/catalog.json"
"$OUT/nitro-protocol"
