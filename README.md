# macos-experiments

A collection of apps and games built with Devin.

Open a project folder and follow its README for setup and usage.

## Native Apple game migrations

These seven games replace all seven Flutter UI clients present at
`f58c20454ae9a930bf72e2eae4d574445a829c4f`. Each has a separate native macOS 14+
target and a universal iOS 17+ target for iPhone and iPad (device families 1,2).
Their Dart server/core packages remain authoritative multiplayer backends.
Other web apps and preexisting native projects in this collection are outside
this migration; follow their own READMEs.

| Game / setup | Xcode project | macOS scheme | iPhone / iPad scheme |
| --- | --- | --- | --- |
| [Brickfolk](brickfolk/README.md) | [Brickfolk.xcodeproj](brickfolk/apple/Brickfolk.xcodeproj) | `Brickfolk-macOS` | `Brickfolk-iOS` |
| [Gambit Court](gambit-court/README.md) | [GambitCourt.xcodeproj](gambit-court/apple/GambitCourt.xcodeproj) | `GambitCourt-macOS` | `GambitCourt-iOS` |
| [Lastfort](lastfort/README.md) | [Lastfort.xcodeproj](lastfort/apple/Lastfort.xcodeproj) | `Lastfort-macOS` | `Lastfort-iOS` |
| [Nitro Tots](nitro-tots/README.md) | [NitroTots.xcodeproj](nitro-tots/apple/NitroTots.xcodeproj) | `NitroTots-macOS` | `NitroTots-iOS` |
| [Panic Pantry](panic-pantry/README.md) | [PanicPantry.xcodeproj](panic-pantry/apple/PanicPantry.xcodeproj) | `PanicPantry-macOS` | `PanicPantry-iOS` |
| [Swapmate](swapmate/README.md) | [Swapmate.xcodeproj](swapmate/apple/Swapmate.xcodeproj) | `Swapmate-macOS` | `Swapmate-iOS` |
| [VoxelHearth](voxelhearth/README.md) | [VoxelHearth.xcodeproj](voxelhearth/apple/VoxelHearth.xcodeproj) | `VoxelHearth-macOS` | `VoxelHearth-iOS` |

### Build

Use macOS with full Xcode and the iOS Simulator SDK installed; VoxelHearth also
requires Xcode's Metal toolchain (`xcodebuild -downloadComponent MetalToolchain`
if missing). If automatic Metal lookup fails, use the build version reported by
`xcodebuild -showComponent MetalToolchain -json` with `-buildVersion` (verified
with `17F109` on Xcode 26.6). Projects are checked in; XcodeGen **2.46.0** is only
needed after editing an app's `apple/project.yml`.

From the repository root, build all fourteen targets, or select games:

```sh
bash validate-native-apps.sh build
bash validate-native-apps.sh build brickfolk swapmate
```

The script uses these commands for each row (example: Brickfolk):

```sh
xcodebuild -project brickfolk/apple/Brickfolk.xcodeproj \
  -scheme Brickfolk-macOS -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath brickfolk/apple/build/native/macOS CODE_SIGNING_ALLOWED=NO build
xcodebuild -project brickfolk/apple/Brickfolk.xcodeproj \
  -scheme Brickfolk-iOS -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath brickfolk/apple/build/native/iOS CODE_SIGNING_ALLOWED=NO build
```

Open an app's project in Xcode to run it. Choose its macOS or iOS scheme and an
iPhone/iPad simulator. Start its Dart server using the linked app README.
Physical devices need your signing team, local-network permission, and the
server computer's LAN address instead of `localhost`.

### Tests and lint

Install standalone Dart **3.13.4**, and put `dart` on `PATH` (or set `DART` to its
absolute executable path). Lint also uses Xcode's `swift-format` and
[SwiftFormat](https://github.com/nicklockwood/SwiftFormat) **0.63.0** for Gambit
Court. The integrated builds use Xcode **26.6**. No Flutter SDK is required.

```sh
bash validate-native-apps.sh lint
bash validate-native-apps.sh test
bash validate-native-apps.sh all panic-pantry nitro-tots
```

The selector accepts only the seven table entries and stops on a failing check.
Tests run retained Dart suites, native model/protocol tests, isolated real
WebSocket server integrations, Nitro Tots client regressions and VoxelHearth
client XCTest. VoxelHearth has no standalone Dart server test directory.
Individual app READMEs document fixture regeneration and test-port overrides.
Run integrations sequentially: several harnesses use port 18787 by default.

Unsigned builds and headless protocol tests do not establish UI or visual
parity. Interactive macOS/iPhone/iPad play, accessibility, signed Keychain and
upgrade behavior, physical-device networking/performance, and distribution
signing still require validation. Archived Flutter tests, screenshots and
reports are historical evidence only.

### Native experiments

- `otter-flap/` — native iOS Flappy Bird-style game starring a procedurally-drawn otter (SwiftUI + SpriteKit). See `otter-flap/README.md`.
