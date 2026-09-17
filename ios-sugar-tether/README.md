# Sugar Tether

![Sugar Tether screenshot](screenshots/ios-sugar-tether.jpg)

A native iPhone physics puzzle about silk, candy, and Pip, an original mint felt creature.
Eight handcrafted puzzles introduce cutting, multiple tethers, pendulum timing, air puffs,
bubbles, and moving thorns. Built with SwiftUI, Canvas, UIKit haptics, and original synthesized
audio. No web view, accounts, network services, or third-party assets.

## Build and run

Requires macOS, Xcode 16 or newer, and XcodeGen (`brew install xcodegen`).
The checked-in `project.yml` is the source of truth; generated Xcode metadata is ignored.

```sh
cd ios-sugar-tether
xcodegen generate
xcodebuild -project SugarTether.xcodeproj -scheme SugarTether \
  -sdk iphonesimulator -configuration Debug -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
```

Open `SugarTether.xcodeproj` in Xcode and run on an iPhone Simulator.
Minimum iOS: 17.0. Portrait iPhone layout. Bundle identifier:
`studio.pocketconfections.sugartether`. No signing needed for Simulator.
Physical-device builds require choosing your own team and enabling signing.

## Controls and progression

- Tap **Let’s play** to begin. Swipe across a silk thread to cut it.
- Each puzzle waits while you read. Tap the board to start the swing, or swipe to start and cut.
- A continuous swipe can cut multiple threads.
- Let the candy swing to collect stars, then time the release toward Pip.
- **PUFF** adds a rightward/upward impulse; it recharges in 0.8 seconds.
- A bubble lifts the candy. Tap the bubble itself to pop it.
- Avoid pink thorns. A lost pearl gets an immediate retry.
- Pause freezes the simulation. Leaving the foreground pauses automatically.
- Earn up to three stars per puzzle. Feeding Pip unlocks the next puzzle even with
  fewer stars; replay open puzzles to improve your locally saved best.
- The speaker control on the title screen and pause card mutes original sound effects.
- Results show earned stars and genuine local bests; there is no global leaderboard.

Progress and sound preference use UserDefaults, survive relaunches, and require no login.
Deleting the app removes its saves.

## Checks

```sh
bash Scripts/check.sh
```

Uses Xcode's `swift-format` linter, Swift Testing deterministic gameplay tests, and a real
iOS Simulator compilation. The test target shares the exact physics source used by the app.
Tests exercise segment intersection, rope constraints, all eight three-star solutions using
cut/pop/puff inputs, moving hazards, progression serialization, and frame-time clamping.
The fixed 120 Hz simulation makes behavior independent of rendering frame rate.

Regenerate the original icon with `swift Scripts/GenerateIcon.swift` from this directory.
The icon is an opaque 1024 px PNG. All illustration is authored vector art with paper/felt
grain, stitched edges, silk highlights, and glass candy stripes.

## V1 scope

Eight compact authored puzzles, one creature, local-only progress, original sound and
haptics. No ads, purchases, analytics, cloud saves, or commercial reference assets.
Reduced Motion disables decorative button and particle travel; essential physics remains visible.
Controls require visual spatial interaction; VoiceOver labels cover navigation and status,
but the puzzle canvas is not a nonvisual gameplay mode. iPad and landscape are not targets.
Simulator haptics do not establish physical-device haptic quality. Store submission,
distribution signing, and physical-device performance validation are outside this V1.
