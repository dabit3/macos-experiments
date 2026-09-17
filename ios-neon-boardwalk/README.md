# Neon Boardwalk

![Neon Boardwalk screenshot](screenshots/ios-neon-boardwalk.jpg)

A native, offline three-lane skate runner for iPhone. Original procedural SceneKit
art puts a glowing arcade strip on one side of a coastal boardwalk and sunset,
water and palm silhouettes on the other. SwiftUI supplies the title, HUD, guide,
pause and results screens. No web views, accounts, backend or third-party assets.

## Build and run

Requires macOS, Xcode 15+ with an iOS Simulator runtime, and XcodeGen 2.46.0
(`brew install xcodegen`). The app supports iOS 17+, iPhone portrait.

```sh
cd ios-neon-boardwalk
xcodegen generate
xcodebuild -project NeonBoardwalk.xcodeproj -scheme NeonBoardwalk \
  -sdk iphonesimulator -configuration Debug \
  -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO build
open NeonBoardwalk.xcodeproj
```

In Xcode choose an available iPhone simulator and Run. No development team or
signing credentials are needed for Simulator. The generated Xcode project is
ignored; `project.yml` is its reproducible source.

## Play

Tap **Let’s ride**. Swipe horizontally to change lanes, up to jump amber barriers,
and down to duck pink overhead signs. Tall arcade carts must be dodged.
Four large tap controls offer the same actions. Hardware arrow keys also work;
Space toggles pause. Jump and slide have visible durations; jumping again in
midair cannot extend a jump. Coins count once. A turquoise shield lasts ten seconds
or absorbs one collision, whichever comes first.

The initial stretch introduces a barrier, an overhead sign, then a shield.
Subsequent obstacle rows always leave at least one unobstructed lane. Speed
increases from 12 to a maximum 23 metres/second, with at least 32 metres between
rows. Distance and collected coins appear on the results screen; local best
distance, lifetime coins, run count and sound preference persist in UserDefaults.
Retry begins immediately. Backgrounding pauses the game and requires an explicit
resume. Nonessential skater bobbing respects Reduce Motion.

## Checks

```sh
swift test
xcrun swift-format lint --strict --recursive Sources Tests Scripts Package.swift
```

Tests cover collision rules, actual introductory jump/slide traversal, shield
pickup/consumption, lane interpolation and bounds, pause/input gating, jump
duration, deterministic generation, state serialization, invalid time deltas,
bounded entity counts, and long normal-rules traversal across twenty random seeds.

To regenerate the original icon:

```sh
swift Scripts/GenerateIcon.swift Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Scope

V1 has one endless coast with increasingly demanding obstacle combinations.
District names mark distance milestones within that continuous route. All art is
generated locally from native geometry; short sound effects are synthesized in
memory. Simulator does not reproduce physical-device haptics. No global leaderboard,
in-app purchases, online sharing or App Store submission is included.
