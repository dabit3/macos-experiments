#!/usr/bin/env bash
# One-shot: install prerequisites, start the Dart server, build and launch the
# native macOS client. Idempotent; safe to rerun.
#
#   bash scripts/run-mac.sh            # server + macOS build + launch
#   bash scripts/run-mac.sh --no-launch
#   bash scripts/run-mac.sh --ios      # also build the iOS Simulator target
#   bash scripts/run-mac.sh --doctor   # check prerequisites only
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
port="${VH_PORT:-8787}"
derived="${VH_DERIVED_DATA:-$root/apple/DerivedDataMac}"
logs="$root/.native-tests"
mkdir -p "$logs"

launch=1
ios=0
doctor=0
for arg in "$@"; do
  case "$arg" in
    --no-launch) launch=0 ;;
    --ios) ios=1 ;;
    --doctor) doctor=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

step() { printf '\n==> %s\n' "$*"; }

step "Xcode"
xcodebuild -version | sed -n 1p
if [[ "${DEVELOPER_DIR:-}" == "" && ! -d /Applications/Xcode.app ]]; then
  echo "Xcode.app not found; install Xcode and select it with xcode-select" >&2
  exit 1
fi

step "Metal toolchain"
if ! xcrun -f metal >/dev/null 2>&1; then
  echo "Metal toolchain missing; downloading (about 700 MB, retry on failure)"
  for _ in 1 2 3; do
    if xcodebuild -downloadComponent MetalToolchain; then break; fi
    sleep 10
  done
  xcrun -f metal >/dev/null
fi
echo "metal: $(xcrun -f metal)"

step "Dart"
if ! command -v dart >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew install dart-sdk
  else
    echo "dart not found and Homebrew unavailable; install Dart 3.9+" >&2
    exit 1
  fi
fi
dart --version

step "iOS Simulator destination"
if xcodebuild -project "$root/apple/VoxelHearth.xcodeproj" -scheme VoxelHearth-iOS \
  -showdestinations 2>/dev/null | grep -q 'platform:iOS Simulator'; then
  ios_ok=1
  echo "eligible iOS Simulator destination found"
else
  ios_ok=0
  echo "no eligible iOS Simulator destination for this Xcode."
  echo "Xcode requires the Simulator runtime build it shipped with; a runtime"
  echo "with the same marketing version but another build is reported as"
  echo "'iOS X is not installed'. Fix with: xcodebuild -downloadPlatform iOS"
fi

if [[ "$doctor" == 1 ]]; then
  exit 0
fi

step "Server dependencies"
(cd "$root/server" && dart pub get)

step "Server on port $port"
if curl --silent --fail "http://127.0.0.1:$port/health" >/dev/null; then
  echo "server already healthy"
else
  (cd "$root/server" && exec dart run bin/server.dart --host 0.0.0.0 --port "$port" \
    --save-dir data --seed 424242) >"$logs/server.log" 2>&1 &
  echo $! >"$logs/server.pid"
  for _ in {1..200}; do
    if curl --silent --fail "http://127.0.0.1:$port/health" >/dev/null; then break; fi
    sleep 0.1
  done
  curl --silent --fail "http://127.0.0.1:$port/health" >/dev/null || {
    cat "$logs/server.log"; exit 1; }
  echo "server started (pid $(cat "$logs/server.pid"), log $logs/server.log)"
fi

step "macOS build"
xcodebuild -project "$root/apple/VoxelHearth.xcodeproj" -scheme VoxelHearth-macOS \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath "$derived" \
  CODE_SIGNING_ALLOWED=NO build -quiet
app="$derived/Build/Products/Debug/VoxelHearth.app"
echo "built $app"

if [[ "$ios" == 1 ]]; then
  step "iOS Simulator build"
  if [[ "$ios_ok" != 1 ]]; then
    echo "skipping: run 'xcodebuild -downloadPlatform iOS' first" >&2
    exit 1
  fi
  xcodebuild -project "$root/apple/VoxelHearth.xcodeproj" -scheme VoxelHearth-iOS \
    -configuration Debug -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$root/apple/DerivedDataiOS" CODE_SIGNING_ALLOWED=NO build -quiet
  echo "built $root/apple/DerivedDataiOS/Build/Products/Debug-iphonesimulator/VoxelHearth.app"
fi

if [[ "$launch" == 1 ]]; then
  step "Launch"
  open -n "$app" --env VH_SERVER="ws://127.0.0.1:$port/ws" \
    --env VH_NAME="${VH_NAME:-Devin}" --env VH_CREATE="${VH_CREATE:-1}"
  echo "launched; click the viewport to capture the pointer, Escape releases it"
fi
