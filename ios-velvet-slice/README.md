# Velvet Slice

![Velvet Slice screenshot](screenshots/ios-velvet-slice.jpg)

A native, offline iPhone fruit-slicing arcade. SwiftUI frames a SpriteKit playfield in a classic 8-bit console style: a limited bright palette, procedurally rasterised pixel-art citrus, kiwi, dragonfruit and bombs (28x32 grids scaled with nearest-neighbour sampling), stepped animations, and the open-licensed Press Start 2P pixel font (`Resources/Fonts/OFL.txt`). All sounds are synthesized locally. No accounts, network, ads, runtime dependencies or third-party game artwork.

## Build and run

Requires macOS, Xcode 16+ and an iOS Simulator (iOS 17+).

```sh
brew install xcodegen swiftformat
cd ios-velvet-slice
xcodegen generate
xcodebuild -project VelvetSlice.xcodeproj -scheme VelvetSlice \
  -sdk iphonesimulator -configuration Debug \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
open VelvetSlice.xcodeproj
```

Select an iPhone Simulator and Run. The checked-in Xcode project is generated from `project.yml`; regenerate with XcodeGen after changing target configuration. Device installation requires your own signing team; Simulator does not.

```sh
swift test
swiftformat Sources Tests Scripts Package.swift --lint
# Recreate the original app icon:
swift Scripts/GenerateIcon.swift Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Controls and rules

- **Play arcade:** three-second ready countdown, then a 60-second run.
- Drag through fruit to slice. Each fruit is worth **10 points**.
- Slice **3+ fruit within 0.48 seconds in one gesture** for **5 bonus points per fruit**. Lift your finger to bank the combo, or continue into a fresh combo window.
- Missing fruit costs **2 points**; scores never go below zero.
- Red-ringed bombs cost **25 points**. Three bombs end the arcade run.
- **Practice:** unlimited time, no bombs, no miss penalty. Use Pause → Finish run to bank your result.
- Pause freezes gameplay and its clock. Resume, restart or finish from that menu. App interruptions automatically pause; returning requires an explicit resume.
- The SND button persists the sound preference. Best arcade and practice results are kept separately on this device with UserDefaults.

## Verification

`swift test` exercises swept-segment hit detection, combo scoring, miss/bomb penalties, round termination, practice behavior and safe opening waves. iOS compilation type-checks the native UI, graphics and audio.

UI acceptance: title and onboarding, countdown, multiple real swipe slices and combo, bomb avoidance and penalties, three-bomb ending, timed completion, replay, practice finish, pause/background/resume, sound setting, persistent best after relaunch and compact iPhone layout.

## Design and constraints

Original V1 inspired by the fruit-slicing genre and the look of 8-bit console games, not a reproduction of any commercial game or its assets. Portrait iPhone only. Reduced Motion suppresses button scaling and reduces particles; fruit motion remains necessary gameplay. VoiceOver labels identify controls and the playfield, but the real-time swipe game is visual and is not fully nonvisually playable. Audio/haptics depend on device capabilities. No global leaderboard or cloud sync. Scores remain local; uninstalling removes them. App Store signing, submission, physical-device performance and store compliance review are outside this experiment.
