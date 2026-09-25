# Groovebox / GB—01

![Groovebox / GB—01 screenshot](screenshots/groovebox.jpg)

A native pocket rhythm instrument for iPhone. Graphite panels, warm markings, colored
drum voices and a sample-clock sequencer turn the screen into a small electronic
instrument. No accounts, internet, sound downloads or external packages.

## Prerequisites

- Native macOS with Xcode 26.6 and its command-line tools selected.
- An installed iOS Simulator runtime (developed with iOS 26.5).
- An iPhone Simulator; the app targets iOS 17+, portrait, iPhone only.
- Swift and `swift-format` are included in Xcode. No project generator required.
- A working host audio output route is required for live Simulator playback.

## Build and run

From this directory:

```sh
./scripts/build.sh
./scripts/run.sh
# Or select an available iPhone:
xcrun simctl list devices available
./scripts/run.sh YOUR_IPHONE_SIMULATOR_UUID
```

Open `Groovebox.xcodeproj` in Xcode to build interactively. The scripts use the
committed project and do not require signing. The output is
`build/Build/Products/Release-iphonesimulator/Groovebox.app`.
This is a **Simulator-only** build, not an installable signed iPhone release.

### Audio on a macOS VM

Check `system_profiler SPAudioDataType` for an active default output. On a VM
without audio hardware, the official Homebrew `blackhole-2ch` cask provides a
virtual loopback route (version 0.7.1 was verified):

```sh
brew install --cask blackhole-2ch
sudo -n killall coreaudiod
system_profiler SPAudioDataType
```

After installing the driver, fully shut down and reboot the Simulator before
launching the app. An app-only relaunch can retain the invalid old route and
return AVFAudio error -10851. During first route initialization the Simulator
also produced an AVFAudio abort; refreshing the bridge restored live playback.
Grant SimulatorTrampoline's native microphone permission if prompted.
BlackHole permits actual PCM capture but does not provide a physical speaker;
offline WAV rendering does not require any host audio device.

## Play

- **Live pads:** audition Kick, Snare, Hi-hat and Clap. Each is synthesized locally.
  Pads work while stopped or playing. They do not record into the sequence.
- **Tracks:** tap a colored track tab; its miniature strip shows the entire part.
  Tap the 16 numbered steps to enable or disable hits.
- **Transport:** Play loops one 4/4 bar; Stop immediately clears active voices.
  Playback stops when the app leaves the foreground or audio is interrupted.
- **Tempo:** minus/plus change 50–200 BPM in one-BPM increments.
- **Mixer:** the slider button opens swing (0–50%) and master volume (0–100%).
  Swing delays every second sixteenth without changing the pair/bar duration.
- **Mute / Solo:** affect sequence triggers, including exported audio. Solo is
  exclusive; muted tracks stay muted even if soloed. Existing drum tails finish.
  Live pads deliberately bypass track mute and solo for auditioning.
- **Patterns:** save a named snapshot, load a saved take or a factory preset.
  Swipe a saved row to delete it. Blank names are disabled; names are limited
  to 40 characters. The working pattern and library autosave on every edit.
- **Undo:** the last 50 pattern edits/loads/clears in this launch are reversible.
  Save-bank deletions are permanent; deleting a snapshot leaves the working
  pattern intact. Clear asks for confirmation and can be undone.
- **WAV:** renders the current audible pattern into a real WAV, then opens the
  native iOS share sheet. Save to Files or share with an available destination.
- **Waveform emblem:** opens the instrument guide.

The initial **Midnight circuit** preset is a syncopated 112 BPM beat.
**Four on the floor** (124 BPM) and **Broken satellites** (92 BPM) provide editable
starting points. Presets are local procedural data; artwork is drawn in SwiftUI.

## Audio architecture

`DrumSynth` generates deterministic, attack/release-shaped PCM: a pitch-dropping
sine kick, noise/tone snare, high-frequency metallic hat and three-burst clap.
`RenderMachine` advances on actual audio samples, not UI timers. An
`AVAudioSourceNode` supplies stereo 48 kHz PCM (identical left/right), and the
system converts to the hardware route if needed. Changes apply at the next
render buffer. Tempo/swing changes preserve the current step's fractional phase.
The UI polls the engine's step at 30 Hz; it never schedules notes.

A bounded four-voice mixer retriggers a voice instead of stacking that same drum
indefinitely. Summed audio uses a soft `tanh` limiter and master gain. The same
renderer produces exports, so sequencing/mute/swing behavior is shared.

## Persistence and exports

App Documents contains:

- `groovebox-library.json`: current pattern, tempo, swing, master, mutes/solo and
  saved named snapshots, written atomically.
- `Groovebox-loop.wav`: latest UI export, overwritten on subsequent exports.
- `groovebox-library-recovery.json`: a best-effort copy if a corrupt library was
  found. The app shows an error and loads the factory pattern.

WAV exports contain exactly **two bars plus 0.55 seconds of release tail**, 48 kHz,
16-bit PCM, mono. At 112 BPM this is 232,114 frames / 4.835708 seconds.
The extra tail is intentional; trim it in a DAW for a precisely loopable region.
File sharing and opening Documents in Files are enabled.

For Simulator access:

```sh
xcrun simctl get_app_container booted ai.devin.demo.groovebox data
```

## Checks

```sh
./scripts/check.sh
./scripts/build.sh
```

`check.sh` runs strict native Swift formatting, meaningful SwiftPM/XCTest core
tests, and compiles a standalone renderer that writes the preset and four one-shot
WAVs to `build/audio/`. Tests cover deterministic audible voices, headroom,
sample-clock looping, swing conservation, phase-preserving tempo changes,
mute/solo, stop/pad behavior, silence, exact WAV header/duration, pattern
validation and JSON persistence/corruption. `xcodebuild` typechecks the native UI
and AVAudioEngine adapter. No repository-level hooks or dependencies are required.

UI acceptance: audition all pads; construct a beat with numbered buttons; play,
change BPM and swing, mute/solo a part; name/save/load a pattern; clear/undo;
export a WAV; stop and relaunch to verify persistence. Use the actual native
Simulator controls and retain full-screen captures and an annotated recording.

## V1 boundaries

One bar, four fixed synthesized voices, one kit, no velocity, MIDI, microphone,
live step recording, per-track effects, song chaining or background playback.
The design is portrait-first and scrolls on smaller iPhones/larger text settings.
This is a deterministic electronic synthesis model, not a physical drum model.
Audio state uses a short lock per render buffer: appropriate for this small demo,
but a production low-latency instrument should use a lock-free command queue and
be profiled on physical hardware. Simulator timing/output latency and sound routing
depend on the host; no physical-device latency or App Store distribution claim.
Undo history is session-local; working patterns and snapshots survive relaunch.
