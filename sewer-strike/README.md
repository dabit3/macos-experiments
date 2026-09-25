# Sewer Strike

![Sewer Strike screenshot](screenshots/sewer-strike.jpg)

A native landscape **iPhone/iPad** cooperative 3D belt-scrolling beat-'em-up.
Four original masked reptilian heroes fight through a neon backstreet, sewer
conduit and reactor arena. Two to four real guests share enemy waves and a boss.
No login or Apple developer account is needed for local simulator builds.

## Build and run

Verified toolchain: macOS, Xcode 26.6 / iOS 26.5 simulator SDK, Swift 5 mode,
XcodeGen 2.46.0, Node 24. Native deployment target is iOS 17.

```sh
cd sewer-strike
# If absent: brew install xcodegen
xcodegen generate
xcodebuild -project SewerStrike.xcodeproj -scheme SewerStrike \
  -configuration Debug -sdk iphonesimulator -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
cd Server
npm ci
npm start                      # ws://0.0.0.0:8767
```

Open `SewerStrike.xcodeproj` in Xcode, choose **SewerStrike**, and run on an
iPhone simulator. Display name: **Sewer Strike**.
Bundle: `ai.devin.sewerstrike.ios`.

The default `ws://127.0.0.1:8767` works for iOS simulators on the server's Mac.
For physical devices, enter `ws://YOUR_MAC_LAN_IP:8767` on both devices and allow
local network access. Device signing is outside the simulator setup.
The server binds all local interfaces; do not expose the unauthenticated guest
service to the public Internet. It is deliberately an ephemeral LAN game server.

## Two-device play

1. Boot **two different** simulator UUIDs from `xcrun simctl list devices available`.
2. Install the same build on each:
   `xcrun simctl install DEVICE_UUID build/Build/Products/Debug-iphonesimulator/SewerStrike.app`.
3. Launch each: `xcrun simctl launch DEVICE_UUID ai.devin.sewerstrike.ios`.
4. On the first device, select Riptide, enter a name, choose **Host Room**.
5. On the second, select a different hero, enter the same server address and
   room code, then **Join**. Both names appear in the team HUD.
6. Both press **Ready Up**. Cooperate through three sectors, advance together
   through cleared gates, defeat Iron Maw, and both vote **Rematch**.

## Controls and combat

- Hold the four movement arrows: horizontal travel and vertical lane changes.
- **Strike**: directional melee. Chain three attacks within 1.05s for a heavier
  third hit and knockback. Attacks require the same lane and weapon reach.
- **Jump**: physical arc; avoid ground slams while high enough. Air strikes hit
  harder. A red ground ring previews the boss's targeted impact.
- **Power**: 50 charge for an invincible area strike. Successful ordinary hits
  refill charge. Distinct heroes have different damage, range, cooldown and speed.
- Stay within revive range of a downed teammate for 2.5s; the ring shows progress.
  If someone is still alive, downed players also recover after 18s. All connected
  heroes down simultaneously means a shared defeat.
- Triangular power slices restore 35 health; cleared sector transitions restore
  20. Slices disappear authoritatively when consumed.
- Pause icon opens a menu without pausing other players. Sound toggle, help,
  same-hero reconnect and leaving are functional.

| Hero | Weapon | Style |
|---|---|---|
| Riptide | Twin sabers | balanced damage and mobility |
| Cinder | Chain batons | fastest attacks and movement |
| Circuit | Volt staff | longest reach and widest special |
| Fang | Twin prongs | shortest reach, heaviest ordinary strike |

## Architecture

SwiftUI owns lobby, four-slot team HUD, touch input and results. SceneKit renders
an original procedural 3D stage, rigged heroes, enemies, weapon poses, jumping,
knockback, rings, neon pipework, healing slices and comic impact effects. Render
poses interpolate 30 Hz state snapshots; the SwiftUI HUD refreshes at 10 Hz.
Decorative SceneKit nodes are excluded from the accessibility hierarchy while
all native controls remain accessible. Native `AVAudioPlayer` plays a looping
original 128 BPM electro-funk track plus generated jump/hit/power/heal/clear cues.
`Tools/make_audio.py` reproducibly authors the bundled WAVs without source samples.

Node + pinned `ws` implements a fixed 30 Hz authoritative simulation. Clients
send sequenced input only, never health, positions, score, damage or victory.
Rooms hold 2–4 unique heroes. Disconnected heroes remain reserved; a random
resume token reattaches the same server-assigned player ID and progress.
Inputs expire after 350ms, duplicate/reordered sequences are ignored, message
sizes and packet rates are bounded, stale rooms expire after ten minutes.
The server process is ephemeral: restarting it clears rooms and tokens.

See [PROTOCOL.md](PROTOCOL.md) for the actual wire format.
See [REFERENCES.md](REFERENCES.md) for observed screenshot traits, source URLs
and the explicit distinction between observed and authored/inferred mechanics.

## Quality checks

```sh
cd sewer-strike
swift format lint --recursive App Tests --strict
xcodebuild -project SewerStrike.xcodeproj -scheme SewerStrike \
  -configuration Release -sdk iphonesimulator -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
cd Server
npm ci
npm run lint
npm test
npm audit --omit=dev
```

Apple's toolchain `swift format lint --strict` is the supported Swift lint command.
Tests cover ordering, normalization, stale input, directional/lane hit detection,
combo finishers, weapon differences, meter, jump immunity, healing/revive, gates,
shared result/rematch, disconnect and real WebSocket resume/identity. An additional
input-only playthrough test clears all waves and the boss with two cooperating
drivers; it never edits health, scores or match outcomes.

## Reproducible native automation

The app accepts the following launch arguments:

```sh
# After booting and installing on two separate devices:
xcrun simctl launch FIRST_UUID ai.devin.sewerstrike.ios \
  -server ws://127.0.0.1:8767 -room STRIKE -guest Alpha -hero 0 \
  -connect -create -autoReady -autoplay -autoRematch
xcrun simctl launch SECOND_UUID ai.devin.sewerstrike.ios \
  -server ws://127.0.0.1:8767 -room STRIKE -guest Bravo -hero 2 \
  -connect -autoReady -autoplay -autoRematch
```

The explicitly labeled **AUTO** input driver reads the same snapshots a human
sees, approaches enemies, sends movement/jump/attack/power through the same client
input queue and socket as touch controls, helps fallen teammates, heals and
advances. No server test mode exists. **Take Control** disables the driver for
touch testing. `-autoRematch` votes once, five seconds after the first clear.
Use a fresh room code or restart the server between recordings.

`-testMode` exposes input diagnostics without enabling autoplay.
Each installed app writes `Documents/session.jsonl` with sent action provenance
and authoritative snapshots once per second. Locate it using:

```sh
xcrun simctl get_app_container DEVICE_UUID ai.devin.sewerstrike.ios data
curl http://127.0.0.1:8767/rooms/STRIKE
```

The room endpoint is a read-only snapshot (no resume tokens). Run
`Tools/assert_match.mjs` against it to collect the same match's assertions.
Record both device streams concurrently with `simctl io UUID recordVideo`.
Only compose simultaneously recorded streams; do not splice unrelated runs.

The `SewerStrikeUITests` target includes a touch-path test. It creates room TOUCH
as Riptide. Launch another native device as Circuit joining TOUCH with
`-connect -autoReady -autoplay` while the test waits. Then run:

```sh
xcodebuild -project SewerStrike.xcodeproj -scheme SewerStrike \
  -destination 'platform=iOS Simulator,id=FIRST_UUID' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO \
  -only-testing:SewerStrikeUITests/ManualControlsTests test
```

It holds movement arrows, taps jump/strike/power, checks server-accepted action
counters and reconnects the same hero.

### Recording actual game audio on a macOS VM

Establish a host audio endpoint **before booting the simulators**. The verified
VM setup used BlackHole 2ch 0.7.1:

```sh
system_profiler SPAudioDataType
brew install --cask blackhole-2ch
# Only if installed but still absent, and noninteractive sudo is authorized:
sudo -n killall coreaudiod
system_profiler SPAudioDataType
```

Confirm BlackHole is the default input and output at 48 kHz stereo. Restart
simulators that booted before the endpoint existed; they may retain stale
CoreAudio state. Grant the recorder's legitimate microphone permission when
prompted. Do not restart CoreAudio during a capture.

`simctl recordVideo` does not capture audio. Capture actual BlackHole input
concurrently with both native streams. In this VM, FFmpeg AVFoundation audio
capture dropped samples even with a larger buffer; a native `AVAudioEngine`
input-node tap wrote contiguous PCM instead. Record each callback's
`AVAudioTime.hostTime`, `sampleTime`, frame count and sample rate. Verify adjacent
sample continuity, decoded frame count and write errors before using the audio.
Keep a common host-clock video reference for alignment; independently check
native Sound OFF/ON transitions against PCM silence/restoration. Use one peer's
gameplay audio and mute the other through its native menu to avoid doubled music.
Never replace live capture with bundled music or fill missing capture with a
generated soundtrack.

The included recorder explicitly closes its `AVAudioFile` after stopping the tap
and compares successful callback frames with the finalized file's frame count.
From the game directory, after building the app:

```sh
swift format lint --strict Tools/record_loopback.swift
swiftc Tools/record_loopback.swift -o build/record-loopback -framework AVFoundation
build/record-loopback "$PWD/build/live-audio" 420
# To stop early, from another terminal:
touch "$PWD/build/live-audio.stop"
```

Use a new output prefix for each capture. The recorder writes the actual PCM to
`<prefix>.caf` and callback timestamps, `writtenFrames`, `fileFrames` and errors
to `<prefix>-timing.json`. It exits unsuccessfully for empty audio, write errors
or mismatched frame counts. Independently decode the CAF with FFmpeg and compare
its PCM length too: callback continuity alone cannot detect incomplete file
finalization. The timed and stop-file shutdown paths both passed this comparison.
This frame check does not by itself establish audible content or A/V alignment.

The [live-audio report](https://app.devin.ai/attachments/1889f0c3-51a4-4909-b453-34c7d89154ac/runtime-report.md)
and [machine evidence bundle](https://app.devin.ai/attachments/2bd10608-bbfb-437c-8b68-4f9f8ef2f737/runtime-evidence.zip)
preserve the tested recorder source, commands, timestamps, assertions and rejected
capture attempts. This run captured 166.4 seconds of contiguous 48 kHz stereo,
verified native mute/unmute, and recorded a shared clear and rematch. Sampled
peer presentation skew reached 405 ms; selected early-to-late relative drift was
zero, but continuous late absolute synchronization and physical-speaker latency
were not established.

## Known gaps / scope

This is an original reference-inspired approximation, not the licensed arcade
software. No claim of exact visual, stage, timing, physics or content parity.
The original 2017/2018 reference has additional stages, vehicles/surfing, voiced
characters and production assets not reproduced here. This authored campaign
has three connected sectors, three regular enemy classes and one boss.
The UI is optimized for landscape iPhone; iPad is supported by layout but requires
separate visual verification. No accounts, Internet relay, persistent campaign,
spectators, controller support or cross-server reconnect are provided.
The guest LAN protocol is not designed for hostile public hosting.
Required native two-device evidence is reported separately from build/test success.
