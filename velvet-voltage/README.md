# Velvet Voltage

![Velvet Voltage screenshot](screenshots/velvet-voltage.jpg)

A native SwiftUI + SpriteKit designer pinball machine. Three balls, three ordered
districts, one miniature city to power. No third-party runtime dependencies,
accounts, network requests, signing credentials, or purchases.

## Build and run

Requires Xcode 26.6 (tested) and an iOS Simulator runtime. Open
`VelvetVoltage.xcodeproj`, choose the shared **VelvetVoltage** scheme and an iPhone
simulator, then Run. The checked-in project is ready to use.

To regenerate the project after editing `project.yml`, install XcodeGen
(`brew install xcodegen`) then run `xcodegen generate` in this directory.

```sh
xcrun simctl list devices available
xcodebuild -project VelvetVoltage.xcodeproj -scheme VelvetVoltage \
  -configuration Debug -sdk iphonesimulator -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project VelvetVoltage.xcodeproj -scheme VelvetVoltage \
  -configuration Release -sdk iphonesimulator -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
# Replace SIMULATOR_UUID with an available iPhone from simctl list.
xcodebuild -project VelvetVoltage.xcodeproj -scheme VelvetVoltage \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
xcrun swift-format lint --strict --recursive Sources Tests Tools
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/VelvetVoltage.app
xcrun simctl launch booted com.nader.velvetvoltage
```

`Tools/MakeIcon.swift` generates the bespoke icon using AppKit:
`swift Tools/MakeIcon.swift Sources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.

## House rules

- Pull down anywhere on the table and let go to launch; a quick tap fires at full power.
- The whole left half of the table is the left flipper, the right half is the right flipper.
  Hold to keep a flipper raised; both sides work at once.
- First game only: a short in-play coach tells you when to flip.
- The cyan bumper is your next district: Arcade → Spire → Riviera. Each ordered hit
  lights more of the city; a circuit lights it all.
- Any bumper pays 100 × multiplier. Ordered hits add 250 ×.
- A circuit adds 1,500 ×, lights the city, and raises the multiplier (maximum 5×).
- A ball below the flippers drains. Three drains end the game.
- Circuit progress survives drains. Retry starts a fresh three-ball game.
- Best score saves immediately; finished-game and circuit totals save at results.
- The native share sheet sends a rendered score poster and honest result text.

## Implementation and limitations

The Art Deco cabinet pairs an original generated architectural mural with native
layered brass hardware, enamel inlays, reflective flippers and a chrome ball.
The same bundled artwork anchors the icon and collectible result poster.
A native dot-matrix score display and illuminated target rings keep live game
information separate from the printed playfield. Artwork loads locally; no
generation or download occurs at runtime.

The table uses a bounded fixed-substep circle/segment collision solver with
gravity, restitution, bumper impulses, friction, capped speed, and touch-driven
flipper impulses; SpriteKit renders the table, ball trail and neon particles.
Score and geometry tests are in `Tests/VoltageTests.swift`.

Portrait iPhone layout uses safe areas and scales the table without cropping.
Reduce Motion removes ball trails and sparks. Buttons have accessibility labels
and identifiers; real-time visual pinball still requires visual tracking and
timing. Backgrounding pauses an active game. A terminated app returns home while
preserving records and preferences; an in-progress ball is not restored.

Audio uses short synthesized tones. Haptics and real-device audio require
physical-device verification; simulator evidence does not validate them.
No daily challenge or multiball is included in this V1.
