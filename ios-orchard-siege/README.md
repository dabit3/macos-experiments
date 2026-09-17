# Orchard Siege

![Orchard Siege screenshot](screenshots/ios-orchard-siege.jpg)

A native landscape iOS slingshot game. Original illustrated orchard, expressive fruit, six authored rigid-body forts, local best scores and an eighteen-star trail. Built with SwiftUI, SpriteKit, Core Graphics and AVAudioEngine; no external assets, network, accounts or packages.

## Build and run

Requires macOS, Xcode 16+ with an iOS Simulator runtime, and XcodeGen (`brew install xcodegen`). Minimum deployment target: iOS 17.

```sh
cd ios-orchard-siege
xcodegen generate
xcodebuild -project OrchardSiege.xcodeproj -scheme OrchardSiege \
  -sdk iphonesimulator -configuration Debug -derivedDataPath build build CODE_SIGNING_ALLOWED=NO
```

Open the generated project in Xcode, choose an iPhone Simulator, and Run. The project, Info.plist and build directory are generated and ignored. `project.yml` is the source of truth.

## Checks

```sh
xcrun swift-format lint --strict --recursive Sources Tests Scripts
xcodebuild -project OrchardSiege.xcodeproj -scheme OrchardSiege \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build test CODE_SIGNING_ALLOWED=NO
```

Replace the destination with an installed simulator. Deterministic tests cover elastic limits, scoring, stars, bounded shot resolution, authored level bounds, and material/projectile variety.

Regenerate the original app icon with:

```sh
swift Scripts/generate-icon.swift Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Controls and rules

- Tap **Let’s play**, or the grid button to select an unlocked fort.
- Touch the fruit in the slingshot, drag left and down, adjust the dotted trajectory, then release. Shorter pulls produce gentler shots. Release near the sling to cancel.
- Apples fly true; pears are heavier. While a purple plum is in flight, tap the playfield or **Burst now** for one radial shockwave.
- Clear every green garden pest before using all fruit. Impacts damage real rigid bodies; glass is fragile, wood is moderate, and stone is heavy.
- Each pest earns 1,000 points. Wood/glass/stone earn 250/150/400. Every unused fruit adds 1,500 on a victory.
- Three stars require fewer shots than the fort’s par (one shot in forts 1–4; two shots in forts 5–6). Par earns two stars; any other victory earns one.
- Pause, resume, retry and the local garden trail are always available. Leaving the app pauses gameplay. Sound is optional; silent-mode audio is respected. Nonessential effects respect Reduce Motion.
- Shots advance after settling, with a nine-second maximum flight window to prevent stuck rounds.

## V1 boundaries

Six intentionally authored forts, one local campaign and no online leaderboard. Physics outcomes can vary slightly between devices. Touch gameplay is visual; menus have accessibility labels but the physics field does not offer a nonvisual play mode. Landscape iPhone is the primary design target; iPad also runs the native game. Device signing, TestFlight and App Store submission are outside this project.
