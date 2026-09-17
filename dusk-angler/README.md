# Dusk Angler

![Dusk Angler screenshot](screenshots/dusk-angler.jpg)

A native SwiftUI fishing game for iPhone. Follow fish silhouettes across a painted
sunset lake, meet the bite, and balance the line through a short tension duel.
No backend, external accounts, dependencies, or signing credentials are required.

## Build and run

Requirements: macOS, Xcode 26 or later, an iOS Simulator runtime. The checked-in
Xcode project and shared `DuskAngler` scheme work directly:

```sh
cd dusk-angler
xcodebuild -project DuskAngler.xcodeproj -scheme DuskAngler \
  -configuration Debug -sdk iphonesimulator -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project DuskAngler.xcodeproj -scheme DuskAngler \
  -configuration Release -sdk iphonesimulator -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO build
xcrun simctl list devices available
# Substitute a booted iPhone UUID below.
xcrun simctl install <UUID> DerivedData/Build/Products/Debug-iphonesimulator/DuskAngler.app
xcrun simctl launch <UUID> com.naderdabit.duskangler
```

Open the Xcode project to run interactively. `project.yml` is the source for the
project: if changing targets/settings, install XcodeGen (`brew install xcodegen`)
and run `xcodegen generate`. App deployment target is iOS 17; portrait iPhone.

## Checks

```sh
xcrun swift-format lint --strict --recursive DuskAngler DuskAnglerTests
xcodebuild -project DuskAngler.xcodeproj -scheme DuskAngler \
  -destination 'platform=iOS Simulator,id=<UUID>' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
```

Builds typecheck Swift. Tests cover target geometry, terminal states, achievable
catches for every species, line failure, slack, surge warning, persistence, bait
spending and pause timing.

## Play

- Tap a fish silhouette to aim; tapping empty water changes the cast position.
  Cast within the visible reticle's reach of a fish.
- Wait about 1.5 seconds, then tap **HOOK** in the 2.5-second bite window.
- **Hold the circular reel**, release to soften the line. Its radial scale and
  numeric readout show tension; brass warnings announce approaching surges.
  Surges begin at 4.5 seconds in a 7-second behavior cycle.
- Bring the landed meter to 100%. Reaching 100% tension snaps; five seconds below
  10% tension loses the fish; each duel has a 45-second limit.
- Each catch earns a length, score, and 1 glow bait (2 for rare fish). Spend two
  bait to attract a rare fish to the selected target. Rare silhouettes can
  always be targeted without bait.
- Catch three fish to open Violet Reach and its Glassfin char. The journal
  retains the latest 100 catches; lifetime count and best score remain.
- Share exports a native illustrated catch image and text through the iOS share
  sheet. Everything is saved locally with UserDefaults.

Pause freezes gameplay. Backgrounding automatically pauses an active cast or
duel. Relaunch returns to shore with saved catches and settings. Reduce Motion
disables fish oscillation, reel rotation, press scaling and the arrival spring. VoiceOver users can target fish
buttons and activate Reel to toggle reeling. Sound/haptics can be disabled.

## Art and limitations

Original generated gouache lake and four natural-history fish illustrations;
custom SwiftUI instrument dial, sunset seal, measurement ruler and water ripples.
The interface uses native Avenir Next typography with specimen names in
Baskerville. No font downloads or runtime asset services are required.
Locally synthesized soft sound effects. The fish and
scientific names are fictional. No daily or online modes, purchases, or analytics.
Violet Reach shares the lake composition with a blue-hour treatment.

Simulator builds need no signing. Physical-device audio, haptics and device-level
accessibility require separate validation. There is no App Store submission.
