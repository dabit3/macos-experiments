# Lucid Lanes

![Lucid Lanes screenshot](screenshots/lucid-lanes.jpg)

A native iPhone precision-bowling game in an impossible art-deco hotel. A native
SceneKit stage renders sculpted porcelain pins, marbled bowling balls, polished
terrazzo, brass trim and dimensional peach archways with physical lighting.
SwiftUI provides the hotel-key room directory, score display and shareable receipt.
A deterministic fixed-substep simulation handles curve, chrome banks,
moving archways, gutters and pin-to-pin impacts. No dependencies or network calls.

## Build and run

Requires macOS with Xcode 16 or later and an installed iOS runtime. Built with
Xcode 26.6 / iOS 26.5. The checked-in Xcode project and shared `LucidLanes` scheme
are ready to open; no generator is needed for a normal build.

```sh
cd lucid-lanes
xcrun simctl list devices available
# Substitute one of your available iPhone simulator UUIDs:
DEVICE="<simulator UUID>"
xcodebuild -project LucidLanes.xcodeproj -scheme LucidLanes \
  -configuration Debug -sdk iphonesimulator \
  -destination "id=$DEVICE" -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project LucidLanes.xcodeproj -scheme LucidLanes \
  -configuration Release -sdk iphonesimulator \
  -destination "id=$DEVICE" -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcrun simctl boot "$DEVICE" # skip if already booted
open -a Simulator
xcrun simctl install "$DEVICE" build/Build/Products/Debug-iphonesimulator/LucidLanes.app
xcrun simctl launch "$DEVICE" com.dabit.lucidlanes
```

To regenerate the project after adding files, install XcodeGen (`brew install
xcodegen`) and run `xcodegen generate`. `project.yml` is the project source.
To regenerate the opaque 1024px vector icon, run
`swift Scripts/GenerateIcon.swift` from this directory.

## Checks

```sh
xcrun swift-format lint --strict --recursive Sources Tests Scripts
xcodebuild -project LucidLanes.xcodeproj -scheme LucidLanes \
  -configuration Debug -destination "id=$DEVICE" \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
```

The builds perform Swift typechecking. Unit tests cover standard scoring,
last-frame bonuses/rack resets, invalid pin counts, deterministic collision
outcomes, moving openings, curve, bumpers, gutters and medal thresholds.

## Play

- Drag upward on the lane to bowl. Horizontal displacement aims; drag length
  sets power. The luminous dotted guide previews the opening line.
- Set the curve slider **before** release. Each roll keeps that one curve.
- The crosshair beside the slider resets curve precisely to straight.
- The arrow button offers a no-drag bowl, with the current aim and power.
  VoiceOver users can adjust the playfield's aim with increment/decrement.
- A match has three standard bowling frames: two rolls per frame, strike and
  spare bonuses, with bonus rolls in the last frame. Maximum score: **90**.
- Bronze unlocks the next room. Eight rooms introduce fixed and moving arches,
  chrome bank shots and unprotected gutters. Thresholds are visible in play.
- Practice uses the same three-frame loop without changing challenge progress.
- Pause offers resume, immediate restart and lobby. Leaving the app pauses play.
- Results include replay, next room, native image/text sharing and local best.
- Sound, haptics and welcome lesson live in Room service (settings).

## Scope and limitations

Portrait iPhone, iOS 17+. Best scores, unlocks, tutorial and settings persist on
this device using UserDefaults. An interrupted match pauses while resident;
relaunch returns to the lobby. There is no cloud save or daily/online mode.
Reduced Motion removes ball trails/celebratory particles and shortens settling.
Physics is intentionally stylized, not a competition bowling simulator.
Audio and haptics need physical-device validation. Simulator builds are unsigned;
App Store signing/submission is outside this project.
