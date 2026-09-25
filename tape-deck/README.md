# Tape Deck

![Tape Deck screenshot](screenshots/tape-deck.jpg)

A native, fully offline pocket groove instrument for iPhone. Bone-white hardware,
charcoal pads, amber signal meters and an original animated cassette make a
four-voice drum sequencer feel like a little physical machine.

## Run

Requires macOS with Xcode 26.6 (verified), with an iOS simulator runtime installed.
The deployment target is iOS 17. No external runtime dependencies, accounts,
backend, credentials or music samples are required.

Open `TapeDeck.xcodeproj`, select the shared **TapeDeck** scheme and an iPhone,
then Run. The checked-in Xcode project is ready to open.

To regenerate the project:

```sh
brew install xcodegen # verified with 2.46.0
xcodegen generate
```

Run these commands from this directory, substituting an available simulator ID:

```sh
xcrun simctl list devices available
xcodebuild -project TapeDeck.xcodeproj -scheme TapeDeck \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  -derivedDataPath "$HOME/tape-deck-build" CODE_SIGNING_ALLOWED=NO build
xcodebuild -project TapeDeck.xcodeproj -scheme TapeDeck \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  -derivedDataPath "$HOME/tape-deck-build" CODE_SIGNING_ALLOWED=NO test
xcrun swift-format lint --strict --recursive Sources Tests Scripts
```

Original icon generation, if needed:

```sh
swift Scripts/GenerateIcon.swift Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Controls

- **Play / Stop** starts at step 1 and loops one bar of 16 sixteenth notes.
- Select **Kick, Snare, Hat or Clap**, then toggle pads. Each row is one beat,
  read left to right. Amber is on; charcoal is off; the red outline is the playhead.
- Tap either knob for live **60–180 BPM** tempo and **0–60%** swing.
  Swing alternates long and short sixteenths while preserving bar duration.
- **MUTE** silences the selected voice. **SOLO** isolates it. Multiple solos are
  supported; mute takes precedence. Each track shows its hit count or mix state;
  **HELD** means another track is soloed. The eraser clears one voice after confirmation.
- **Save** creates a named snapshot of all four voices, tempo, swing and mixer.
  The tape library includes four explicitly labeled original factory presets
  and your saved copies. **ON DECK** marks an exact match to the working pattern.
  Saved tapes can be loaded or deleted.
- **How to play** opens the field notes.

## Audio and data

Four original deterministic synthesized voices: pitch-envelope kick, tonal/noise
snare, high-pass noise hat and multi-burst clap. No copyrighted or bundled samples.
AVAudioEngine's source render callback advances the fractional-sample sequencer,
mixes voices and applies a soft limiter. The UI polls the actual render playhead
and audio peak; it does not drive audio timing. Sound uses the media playback
category (including when the iPhone's silent switch is on).

The working pattern saves automatically to an atomic JSON file in the app's
Application Support directory. Named tapes are independent snapshots. Playback
never auto-starts on launch. Backgrounding the app, audio interruptions and removal
of the current output stop playback. Data is local to this app installation.
Uninstalling the app removes it.

## Accessibility

Labeled step, track, transport and parameter controls; native adjustable sliders;
Dynamic Type UI text; scrollable content; Reduce Motion freezes reel movement.
Sound and motion are supplementary to persistent visual step and transport state.

## Scope and limitations

- One bar, four voices; no bass, recording/import/export, MIDI, background playback
  or multi-pattern arrangements in this V1.
- The audio callback takes a short lock once per buffer to snapshot controls and
  publish metering. It is sample-count driven but not claimed to be a hard real-time
  or professional low-latency engine.
- Audio output is stereo dual-mono. Headphone, Bluetooth latency, physical-device
  performance and production signing require device validation.
- The app is iPhone portrait only. Simulator validation does not constitute
  App Store approval.

## Tests

XCTest covers swing/bar timing, malformed data and parameter bounds, mute/solo
precedence, archive round-trip and snapshot independence, corrupt archive handling,
deterministic audible synthesized samples, rendered transport/step boundaries,
and atomic parameter reset publication/persistence.
