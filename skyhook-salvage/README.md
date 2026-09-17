# Skyhook Salvage

![Skyhook Salvage screenshot](screenshots/skyhook-salvage.jpg)

A native SwiftUI / Canvas iPhone game about rescuing whimsical cargo with a swinging
crane and balancing it on a tiny brass airship. No services, accounts or third-party
runtime dependencies.

## Build and run

Requires macOS and Xcode with an iOS simulator runtime (validated with Xcode 26.6,
iOS 26.5). Open `SkyhookSalvage.xcodeproj` and choose the shared **SkyhookSalvage**
scheme and an iPhone simulator. Signing is disabled for these simulator builds.

From this directory:

```sh
xcodebuild -project SkyhookSalvage.xcodeproj -scheme SkyhookSalvage \
  -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/Debug CODE_SIGNING_ALLOWED=NO build
xcodebuild -project SkyhookSalvage.xcodeproj -scheme SkyhookSalvage \
  -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/Release CODE_SIGNING_ALLOWED=NO build
xcrun simctl list devices available
# Replace DEVICE_UUID with your booted iPhone simulator:
xcrun simctl install DEVICE_UUID build/Debug/Build/Products/Debug-iphonesimulator/SkyhookSalvage.app
xcrun simctl launch DEVICE_UUID com.skyhooksalvage.game
```

The checked-in project needs no generator to build. After editing `project.yml`,
regenerate with XcodeGen (validated with 2.46.0): `brew install xcodegen && xcodegen generate`.
The maritime illustrations and sprites are bundled native assets. Source artwork
is in `scripts/Artwork`; no image generation or network calls run in the app.
Regenerate the image sets and opaque app icon with:

```sh
swift scripts/PrepareArtwork.swift
swift scripts/GenerateIcon.swift
```

The first script isolates the six illustrated sprites from the source atlas.
The interface uses a shared native sans-serif type scale, cool harbor-gray surfaces
and a custom adjustable brass crane-trim dial. Cargo previews introduce each contract;
start and replay actions stay within reach above the safe area. The same cargo
artwork appears in play, onboarding and shared manifests.

## Play

1. Begin a contract; catch the object on the **left dock** by tapping **Drop hook**
   as the hook crosses it.
2. After the automatic hoist, **Release cargo** over the ship's deck or the previous
   treasure. The dashed line includes the small sideways drift caused by the swing.
3. Use the crane-trim slider or arrow buttons to offset the crane left and right.
   Keep the ship's deck bubble near the middle. Heavier objects exert more torque.
4. Deliver the manifest before the clock expires. Three missed lifts, an expired
   contract, or excessive off-center weight ends the run. Retry immediately.

Successful contracts unlock two harder routes. Points reward cargo weight,
placement precision and time remaining on completed contracts. Best score and
route unlocks persist locally. Practice has no clock or missed-lift limit and
does not change records; an unstable ship still ends a practice run.

The pause menu supports resume, restart and returning home. Backgrounding pauses
the game. Settings control generated sound cues and haptics. Results create a
native share sheet with a rendered cargo manifest/tower image and score text.

## Checks

```sh
swift format lint --strict --recursive Sources Tests scripts
xcodebuild -project SkyhookSalvage.xcodeproj -scheme SkyhookSalvage \
  -configuration Debug -destination 'platform=iOS Simulator,id=DEVICE_UUID' \
  -parallel-testing-enabled NO -derivedDataPath build/Tests CODE_SIGNING_ALLOWED=NO test
```

Tests cover catch windows, stack support, weighted balance, scoring precision,
contract completion/unlocks/persistence, missed-lift failure and retry, pause and
timeout, practice rules, trim bounds, landing-guide agreement and repeated inputs. Debug and Release builds
also typecheck the native UI and game.

## Reliability and limitations

See [QA.md](QA.md) for native test results, three visual review passes and evidence.

- Physics is a deterministic, bounded pendulum/drop model, rather than an unstable
  rigid-body simulation. Landings require at least 34% support overlap; ship tilt
  uses the weighted cargo center of mass plus the ship's ballast.
- Portrait iPhone presentation. System Reduce Motion disables ambient drift,
  propeller and impact wobble; essential hook movement remains visible.
- Interactive elements have accessibility labels and identifiers. Canvas artwork
  has descriptive labels. This timing game is visually driven and is not claimed
  to offer equivalent nonvisual play.
- Progress uses local UserDefaults; active runs are paused in background but not
  restored after process termination. No cloud sync, daily challenge or online
  leaderboard is implied.
- Simulator audio/haptic code is exercised, but physical feel, speaker behavior
  and device performance need physical-iPhone validation.
- No signing credentials or App Store upload are included.
