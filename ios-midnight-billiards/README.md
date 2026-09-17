# Midnight Billiards

![Midnight Billiards screenshot](screenshots/ios-midnight-billiards.jpg)

A native, offline iOS billiards room, built with SwiftUI Canvas, custom fixed-substep physics, and
original procedural artwork and synthesized audio. Landscape gives the table enough space for
precise touch aiming. iOS 17 or later; iPhone and iPad.

## Build and run

Requires Xcode 26.x (validated with 26.6), its iOS Simulator runtime, and XcodeGen 2.46.0.
There are no app package dependencies, accounts, network calls, ads, or signing requirements
for Simulator builds.

```sh
brew install xcodegen
cd ios-midnight-billiards
xcodegen generate
xcodebuild -project MidnightBilliards.xcodeproj -scheme MidnightBilliards \
  -sdk iphonesimulator -configuration Debug -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO build
open MidnightBilliards.xcodeproj
```

Choose an iPhone Simulator and Run in Xcode. Or, after choosing and booting a device:

```sh
xcrun simctl install booted DerivedData/Build/Products/Debug-iphonesimulator/MidnightBilliards.app
xcrun simctl launch booted com.midnightclub.MidnightBilliards
```

`project.yml` is the project source of truth. The Xcode project and Info.plist are generated
and ignored, along with build output. The original app icon is checked in; regenerate it with
`swift Scripts/GenerateIcon.swift`.

## Controls

- Choose **The house table** for eight-ball against Avery, or **Against the clock** for a
  three-minute solo challenge.
- Tap or drag the felt to aim. White dashes predict cue-ball contact; the gold segment predicts
  the target direction or a single cushion bounce. Guides do not account for later collisions.
- Set **Power**, optionally refine aim in quarter-degree steps, then **Take shot**.
- The cue-ball control cycles **Center / Follow / Draw**. Spin affects cue momentum after its
  first collision and lightly affects cushion response.
- After a shot, the cue points toward a suggested geometric angle. It does not shoot for you
  or guarantee a pot; adjust direction and power.
- When given ball in hand, tap clear felt to place the cue and confirm. Break fouls restrict
  placement behind the marked head string.
- Tap a pocket to call the eight when your group is clear. The chosen pocket has a gold ring.
- Pause offers resume, rules, fresh rack, and return to the club. Backgrounding pauses play;
  returning never silently resumes the clock. Sound toggles on the title and table screens.

## Modes and house rules

**Eight-ball:** the break needs an object pot or four object balls to rails. The table stays open
after the break; the first group potted on a later legal shot becomes yours (first ball decides
if both groups fall). A legal pot of your group retains your turn. Hit your group first,
then any ball must reach a rail or pocket. Fouls and scratches give ball in hand. Clear
your group and pot the eight in the called pocket to win. An early eight, wrong pocket, or
scratch with the eight loses. An eight on the break is respotted.

This V1 deliberately uses accessible house rules: only the eight requires a called pocket,
no push-outs/safety declarations/three-foul rule, no match series, and no tournament referee UI.
Avery evaluates clear cue-to-ghost-ball and object-to-pocket routes, favors lower cut angles,
chooses power by distance, places the cue after fouls, and falls back to a contact shot when
blocked. This is a local opponent, not a remote player.

**Solo challenge:** each object ball earns 100 points times the consecutive successful-shot
streak, capped at 5×. A missed pot resets the streak. A scratch resets it and subtracts
50 points (floor zero); object balls potted on a scratch count toward balls potted but earn
no points. Clearing all fifteen grants 500 points and another rack. The shot already in motion
when the three-minute clock reaches zero is allowed to settle. Best score, match wins, sound
preference, and lifetime pots persist locally with UserDefaults. An unfinished match is preserved
while backgrounded but is not restored after process termination.

## Checks

Run from this directory:

```sh
xcrun swift-format lint --strict --recursive Sources Tests Scripts Package.swift
swift test
xcodegen generate
xcodebuild -project MidnightBilliards.xcodeproj -scheme MidnightBilliards \
  -sdk iphonesimulator -configuration Debug -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

SwiftPM tests compile the same engine files used by the app. Tests exercise collisions and
momentum transfer, cushion energy loss, pockets, non-overlapping rack geometry, break interaction
and settling, placement, group assignment, legal misses, wrong first contact, no-rail fouls,
scratches, early/called/wrong-pocket eight, challenge streaks/penalties/clock, aiming and an
AI-selected shot executed through actual physics.

Native Simulator UI evidence and visual iteration notes are linked from the PR. Build/test
success alone is not a claim of App Store submission readiness.

## Scope

No third-party visual assets or commercial branding are included. The model is a responsive
2D approximation: no jumping, masse, cloth wear, full rigid-body 3D spin, online multiplayer,
or professional tournament-rule parity. Sound uses the ambient audio session and respects
the device silent switch; haptics require supported physical hardware. iPad layouts share
the landscape design. Reduced Motion disables nonessential overlay transitions.
