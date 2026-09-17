# Buttonwood Adventure

![Buttonwood Adventure screenshot](screenshots/ios-buttonwood-adventure.jpg)

A native, landscape iOS platformer about a tiny explorer finding a way home through
a clockwork woodland. Built with SwiftUI, SpriteKit, UIKit and synthesized local
audio. Original vector artwork; no network, account, external assets or paid services.

## Build and run

Requirements: macOS, Xcode 16 or newer, Swift 6, XcodeGen 2.44 or newer.
Validated toolchain and Simulator devices are listed in the PR testing evidence.

```sh
cd ios-buttonwood-adventure
brew install xcodegen
xcodegen generate
xcodebuild -project Buttonwood.xcodeproj -scheme Buttonwood \
  -configuration Debug -sdk iphonesimulator \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

Open the generated project in Xcode, select an iPhone Simulator and Run.
The app supports landscape left/right on iPhone and iPad, with iOS 17 minimum.
For a physical device, select your own signing team in Xcode.

## Check

```sh
swift test
xcrun swift-format lint --strict --recursive Sources Tests Scripts UITests
```

The deterministic core tests cover variable jumping, coyote time, no double jump,
stomp versus damage, shield consumption, moving-platform carrying, checkpoint
respawn without collectible farming, terminal states and authored level gaps.

## Play

- **Run:** hold the left or right arrow.
- **Jump:** tap for a short hop; hold for a high leap. Run and jump simultaneously.
- **Keyboard:** arrows or A/D to run, Space/W/up to jump, Escape to pause.
- Stomp beetles from above. Side contact costs a heart; an acorn guard absorbs one hit.
- Gold buttons add 50 points; beetles add 125; acorns add 100; checkpoints add 150.
- Light a lantern to respawn there. Three lost hearts end the attempt.
- Reach the brass door to complete the chapter. A time bonus rewards efficient runs.
- Earn stars by finishing, gathering at least half the buttons, and keeping all three hearts.
- Each completed chapter opens the next of three distinct trails.
- Scores, stars, most buttons, fastest completion and sound preference persist locally.
- Pause, backgrounding and interruptions stop gameplay and clear held inputs.
- The results share button uses native iOS sharing with your actual achieved result.

## Implementation

The Foundation-only game simulation uses fixed 120 Hz steps, swept one-way landing
checks, a 120 ms coyote window and 140 ms jump buffer. Levels are hand-authored and
include horizontal moving platforms, beetle patrols and increasingly demanding gaps.
SpriteKit draws the forest, layered parallax, explorer, platforms and effects.
SwiftUI provides menus, touch controls and safe-area-aware HUD.

All art is generated from original native vector geometry. To regenerate the icon:

```sh
swift Scripts/MakeIcon.swift Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Scope

This is an original three-chapter V1, not a full reproduction of any commercial game.
No online leaderboard or cloud sync is included. Progress is local to the installation.
Simulator haptics and hardware-keyboard delivery depend on the host configuration.
Reduced Motion disables nonessential particles and ambient motion.
App Store submission and physical-device testing are outside this delivery.
