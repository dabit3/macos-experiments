#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -d "$ROOT/.build/Margin.app" ]]; then
  "$ROOT/scripts/build.sh"
fi
open "$ROOT/.build/Margin.app"
