#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/artifacts/demo-documents"
cp "$ROOT"/Fixtures/*.txt "$ROOT/artifacts/demo-documents/"
open -a TextEdit "$ROOT"/artifacts/demo-documents/*.txt
printf 'Opened four synthetic TextEdit documents. In ShareStage choose “Select TextEdit demo windows”.\n'
