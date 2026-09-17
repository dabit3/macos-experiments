# Powderline

![Powderline screenshot](screenshots/ios-powderline.jpg)

A native, one-touch snowboarding odyssey for iPhone. SwiftUI draws an original
layered alpine world with continuous hills, drifting snow, a tiny scarf-wearing
rider, warm chalets and a dawn-to-apricot sky. A fixed-step Swift simulation runs
the jumps, backflips, landings, coins, rocks, ravines and chained trick scoring.

## Build and run

Requires macOS, Xcode 16 or newer (validated with Xcode 26.6), and XcodeGen.
The app supports iOS 17+ in portrait on iPhone. No dependencies, account,
network service or signing credentials are needed for Simulator.

```sh
cd ios-powderline
brew install xcodegen # if not already installed
xcodegen generate
xcodebuild -project Powderline.xcodeproj -scheme Powderline \
  -sdk iphonesimulator -configuration Debug \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

Open the generated `Powderline.xcodeproj`, select an iPhone Simulator and Run.
Generated Xcode metadata and build output are ignored. `project.yml` is the
source of truth. For a physical device, configure your own development team and
enable code signing in your local Xcode settings.

## Controls and loop

- **Begin the descent** starts an expedition immediately.
- **Tap** the playfield or bottom control to jump.
- **Hold** to rotate backward after a short jump grace period. Release once the
  board has come around (roughly 1.2 seconds from takeoff). Land with the board
  aligned to the hill. The bottom cue tells you when the board is level.
- Tap to clear rocks; coral flags mark ravines. Warnings appear before hazards.
- Collect gold coins (25 points). Each completed backflip awards 150 points,
  multiplied by a combo that grows up to 5× when landings are within 5.5 seconds.
  Distance also contributes one point per meter.
- **Pause** freezes the simulation; resume, view controls, toggle sound or end
  the ride. Backgrounding automatically pauses; returning never advances time.
- A crash ends the expedition and saves the local best score/distance. Retry
  immediately or share the real achieved result through the native share sheet.
- **Zen practice** is slower, automatically rescues falls, and never overwrites
  expedition records. Finish practice from the pause screen.

Best score, best distance, lifetime coins, ride count, flips and separate practice
distance persist locally in UserDefaults. Completed rides save once. In-progress
rides survive ordinary app backgrounding, but a terminated process returns to
the title. No global leaderboard is implied.

## Checks

```sh
swift format lint --strict --recursive Sources Tests Scripts Package.swift
swift test
```

Tests verify slope-relative landing tolerance, half-flip crashes, real combo
scoring and expiration, safe hazard spacing over 100 seeds, deterministic
simulation across frame rates, jump behavior, practice rescues and separate,
serializable records. The Swift package compiles the same rules used by iOS.

The icon and audio are original and reproducible using Apple frameworks:

```sh
swift Scripts/GenerateAssets.swift .
```

Sound uses a quiet looping wind bed and synthesized jump, coin, landing and crash
cues, respects silent mode, and can be disabled on the title or pause screens.
The game includes gentle haptics on supported devices. Reduce Motion disables
ambient snow motion and title camera drift; essential riding animation remains.

## V1 scope

An original game inspired by the one-touch endless snowboarding genre, not an
exact copy of any commercial level catalog or assets. V1 focuses on one polished
procedural expedition and a separate calm practice mode. There are no grind
rails, character unlocks, paid services, ads, purchases or online accounts.
Procedural terrain is continuous; speed increases gradually to a bounded cap.
Visuals are resolution independent. Best records live only on the current
installation. App Store submission and device distribution are outside scope.

Native Simulator review, iteration notes, screenshots and annotated computer-use
recordings are linked from the PR.
