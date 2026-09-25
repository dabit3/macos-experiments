#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="${1:-all}"
if (($#)); then shift; fi
case "$mode" in
  all|build|test|lint) ;;
  *) echo "Usage: bash $0 [all|build|test|lint] [app ...]" >&2; exit 2 ;;
esac
if (($# == 0)); then
  set -- brickfolk gambit-court lastfort nitro-tots panic-pantry swapmate voxelhearth
fi
for app in "$@"; do
  case "$app" in
    brickfolk|gambit-court|lastfort|nitro-tots|panic-pantry|swapmate|voxelhearth) ;;
    *) echo "Unknown native migration: $app" >&2; exit 2 ;;
  esac
done

if [[ "$mode" != build ]]; then
  DART="$(command -v "${DART:-dart}")"
  export DART
  PATH="$(dirname "$DART"):$PATH"
  export PATH
fi

for app in "$@"; do
  (
    cd "$root/$app"
    package=apple
    case "$app" in
      brickfolk)
        scheme=Brickfolk
        dart_packages=(shared server)
        swift_sources=(apple/Sources apple/Tests apple/Package.swift)
        dart_tools=(server/tool/export_apple_content.dart)
        ;;
      gambit-court)
        scheme=GambitCourt
        dart_packages=(packages/gambit_court_core server)
        swift_sources=(apple/Sources apple/Tests apple/Package.swift)
        dart_tools=()
        ;;
      lastfort)
        scheme=Lastfort
        dart_packages=(core server)
        swift_sources=(apple/Sources apple/Tests apple/Tools apple/Package.swift)
        dart_tools=(apple/Tools/export_assets.dart)
        ;;
      nitro-tots)
        scheme=NitroTots
        package=apple/Core
        dart_packages=(packages/nitro_core packages/nitro_server)
        swift_sources=(apple/App apple/Core/Sources apple/Core/Tests tools/*.swift apple/Core/Package.swift)
        dart_tools=(tools/export_native.dart)
        ;;
      panic-pantry)
        scheme=PanicPantry
        dart_packages=(core server)
        swift_sources=(apple/Sources apple/Tests apple/Tools apple/Package.swift)
        dart_tools=(apple/Tools/export_levels.dart apple/Tools/export_fixtures.dart)
        ;;
      swapmate)
        scheme=Swapmate
        dart_packages=(packages/swapmate_core server)
        swift_sources=(apple/App apple/Sources apple/Tests apple/Package.swift)
        dart_tools=(test/generate-fixtures.dart)
        ;;
      voxelhearth)
        scheme=VoxelHearth
        package=apple/Core
        dart_packages=(packages/voxelhearth_core server)
        swift_sources=(apple/Sources apple/Tests apple/Core/Sources apple/Core/Tests apple/Core/Package.swift)
        dart_tools=(tools/atlas.dart tools/export_native.dart)
        ;;
    esac
    echo "=== $app: $mode ==="
    if [[ "$mode" == all || "$mode" == lint || "$mode" == test ]]; then
      for directory in "${dart_packages[@]}"; do
        (
          cd "$directory"
          if [[ -f pubspec.lock ]]; then
            "$DART" pub get --enforce-lockfile
          else
            "$DART" pub get
          fi
        )
      done
    fi
    if [[ "$mode" == all || "$mode" == lint ]]; then
      if [[ "$app" == gambit-court ]]; then
        (cd apple && swiftformat Sources Tests Package.swift --lint)
      else
        xcrun swift-format lint --strict --recursive "${swift_sources[@]}"
      fi
      for directory in "${dart_packages[@]}"; do
        (
          cd "$directory"
          "$DART" format --output=none --set-exit-if-changed .
          "$DART" analyze --fatal-infos
        )
      done
      if [[ "$app" != gambit-court ]]; then
        for source in "${dart_tools[@]}"; do
          "$DART" format --output=none --set-exit-if-changed "$source"
          "$DART" analyze --fatal-infos "$source"
        done
      fi
      bash -n test/multiplayer-e2e.sh
    fi
    if [[ "$mode" == all || "$mode" == test ]]; then
      for directory in "${dart_packages[@]}"; do
        if [[ -d "$directory/test" ]]; then
          (cd "$directory" && "$DART" test)
        else
          echo "$app/$directory: no standalone Dart test suite; covered by live integration below."
        fi
      done
      case "$app" in
        brickfolk|lastfort|nitro-tots) swift test --package-path "$package" ;;
      esac
      if [[ "$app" == nitro-tots ]]; then bash tools/test-native-client.sh; fi
      bash test/multiplayer-e2e.sh
      if [[ "$app" == voxelhearth ]]; then
        xcodebuild -project "apple/$scheme.xcodeproj" -scheme "$scheme-macOS" \
          -configuration Debug -destination 'platform=macOS' \
          -derivedDataPath apple/build/native/macOS CODE_SIGNING_ALLOWED=NO test
      fi
    fi
    if [[ "$mode" == all || "$mode" == build ]]; then
      xcodebuild -project "apple/$scheme.xcodeproj" -scheme "$scheme-macOS" \
        -configuration Debug -destination 'platform=macOS' \
        -derivedDataPath apple/build/native/macOS CODE_SIGNING_ALLOWED=NO build
      xcodebuild -project "apple/$scheme.xcodeproj" -scheme "$scheme-iOS" \
        -configuration Debug -sdk iphonesimulator \
        -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath apple/build/native/iOS CODE_SIGNING_ALLOWED=NO build
    fi
    echo "=== PASS: $app ($mode) ==="
  )
done
