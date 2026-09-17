# Lumen Drift

![Lumen Drift screenshot](screenshots/lumen-drift.jpg)

A native portrait iPhone arcade game about finding a clean line through a luminous canyon. A SwiftUI cockpit surrounds a procedural SpriteKit world: faceted indigo cliffs, an eclipsed moon, cyan flight rails, a hovering craft and coral obstacles. Everything runs offline.

## Requirements

- macOS with Xcode 26.x and an installed iOS Simulator runtime.
- Verified with Xcode 26.6, Swift 6.3.3 and iOS 26.5.
- No package manager, generator, account, signing credentials or network service required.
- The checked-in Xcode project targets iPhone, portrait, iOS 17+.

## Build and run

From this directory:

```sh
bash Scripts/check.sh
bash Scripts/build.sh
xcrun simctl list devices available
bash Scripts/run.sh <your-iPhone-Simulator-UUID>
```

Or open `LumenDrift.xcodeproj`, choose the `LumenDrift` scheme and an iPhone Simulator, and Run. The built app is `build/Build/Products/Debug-iphonesimulator/LumenDrift.app`. It is a Simulator app, not a signed device/App Store release.

## Controls and demo

1. Choose **Practice flight** for the playable flight-school introduction, then **Enter practice**.
2. Each practice wave gives twelve seconds of approach time. The guide identifies the hazard lane and the energy lane. Tap **LEFT**, **CENTER**, **RIGHT**, or swipe horizontally to shift one lane.
3. The first wave has a center hazard and left energy. Move left to collect it. The next has a left hazard and right energy; deliberately move right.
4. **Pause** freezes the simulation. Resume continues the same run. Restart clears the current flight; returning to the hangar saves the achieved score.
5. Two shields absorb two impacts; a third ends the run. To test failure, deliberately choose the coral lane. **Fly again** starts a clean run.
6. Return to the hangar or relaunch after game over to see the locally saved best score.
7. **Start endless** launches the faster, randomly seeded game. It accelerates gradually to a bounded maximum.

## Mechanics

- One hazard and one energy cell per wave; their lanes are always different.
- Energy is worth 100 × multiplier. Passing in the lane immediately beside a hazard earns 35 × multiplier and advances the combo.
- Every two consecutive near misses raises the multiplier, capped at 4×. A distant pass or impact breaks the chain. Collection uses the multiplier after the near-miss evaluation.
- Distance adds one point per meter. Practice travels at 7 m/s; endless starts at 20 m/s and caps at 33 m/s.
- Practice uses a repeating six-wave lesson, with twelve-second approach and eleven-second spacing. Endless starts with 4.8-second approach and 2.9-second spacing; at maximum speed, waves remain more than 1.7 seconds apart.
- Collision and collection resolve when a wave reaches the craft's line. Lane selection is discrete, with a short visual steering animation.
- Backgrounding automatically pauses. A paused or ended run does not progress.

## Persistence and recovery

Best scores are separate for practice and endless. Records, total flights and energy are stored as versioned Codable data in the app's `UserDefaults` container (`lumen-drift.records.v1`). A completed flight or return to the hangar saves the score. Restart discards the unfinished flight. Corrupt/missing records load as a new profile.

An in-progress flight does **not** resume after process termination. Existing saved records remain. There is no destructive profile reset in the UI; restart is the gameplay recovery path. Uninstalling the app clears its records.

## Artwork

The world, craft, hazards and energy cells are original local vector geometry rendered by SpriteKit. No downloaded art or emoji assets are used. The bundled icon is generated from `Scripts/GenerateIcon.swift`:

```sh
xcrun swift Scripts/GenerateIcon.swift LumenDrift/Assets.xcassets/AppIcon.appiconset/Icon.png
```

## Checks

`Scripts/check.sh` runs Xcode's `swift-format lint --strict` and compiles the Foundation-only engine with warnings treated as errors. Its executable tests cover lane boundaries, real scoring, collection, shields and game over, combo growth/reset, pause/resume, invalid clock input, restart, seeded procedural fairness over hundreds of waves, frame-rate independence, persistence and corrupted-save recovery.

Native UI testing must additionally exercise steering, deliberate collection/avoidance, pause/resume, failure/restart and best-score persistence after relaunch. Build and logic checks alone are not UI evidence.

## Scope and limitations

- This is a stylized lane arcade simulation, not physically accurate vehicle dynamics. The perspective is projected 2D vector art, not a 3D physics engine.
- Near misses mean an adjacent-lane pass at the crossing plane; there is no analog grazing-distance calculation.
- No sound/music, online leaderboard, purchases, login, camera or physical hardware requirements. Haptics are available on supported hardware; Simulator does not reproduce them.
- Fixed portrait composition; Dynamic Type scaling and a fully nonvisual gameplay mode are not implemented. Menu/steering controls have accessibility labels and identifiers.
- No user-content export is needed for this game. Build artifacts live in `build/`; recordings/screenshots/reports are delivered as session attachments and are not committed.
