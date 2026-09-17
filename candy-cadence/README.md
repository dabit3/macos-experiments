# Candy Cadence

![Candy Cadence screenshot](screenshots/candy-cadence.jpg)

A native landscape **iPad** rhythm game with nine staggered candy buttons,
original animated vector mascots, two original instrumental songs, authored charts,
and real two-player WebSocket competition. Distinct application identifier:
`ai.candycadence.game`. No Apple account is needed for simulator builds.

The iPad target preserves large two-row controls, simultaneous chords, the central
note highway and both dancers. This is a playable reference-inspired game, not an
emulation. See [reference observations and provenance](Research/REFERENCE.md).

## Build and run

Verified toolchain: macOS, Xcode 26.6, iOS 26.5 simulators, Node 22+, XcodeGen 2.46.
The generated Xcode project is committed, so XcodeGen is needed only after changing
`project.yml`. All commands below run from `candy-cadence/`.

```sh
npm --prefix Server ci
npm --prefix Server start
# A separate terminal:
xcodebuild -project CandyCadence.xcodeproj -scheme CandyCadence \
  -sdk iphonesimulator -configuration Debug -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
bash Scripts/verify-bundle.sh build/Build/Products/Debug-iphonesimulator/CandyCadence.app
```

Open `CandyCadence.xcodeproj` in Xcode, select an iPad simulator, then Run.
The bundle check validates the actual packaged catalog, music, tap sounds, and
app identity; a compiler build alone does not establish that resources are present.
Server default: `ws://127.0.0.1:8789`. For physical iPads, run the server on a Mac
on the same Wi-Fi and enter `ws://<Mac-LAN-IP>:8789` in each app. Local-network
permission is required. Physical devices require ordinary Apple signing.
`HOST` and `PORT` override server binding. There is no public deployment.

## Two simulators

For live audio capture on a macOS VM without an output device, install BlackHole
**before booting the simulators**:

```sh
brew install --cask blackhole-2ch
system_profiler SPAudioDataType
# If the installed device is still absent, restart CoreAudio once:
sudo -n killall coreaudiod
system_profiler SPAudioDataType
ffmpeg -hide_banner -f avfoundation -list_devices true -i ""
```

BlackHole 2ch 0.7.1 was verified here as the default input/output at 48 kHz.
The normal CoreAudio restart activated it without a host reboot. Do not use
`launchctl kickstart` for this service: macOS rejected it under SIP. If activation
requires a password or still fails, coordinate a host restart instead of changing
system protections. Device-list mode may exit nonzero after printing its list.
Restart any simulator that booted before a working host audio endpoint existed.
Confirm BlackHole appears in both device listings before proceeding. A device
listing alone does not verify game playback; capture and inspect the live signal.

For continuous loopback, use an `AVAudioEngine.inputNode` tap writing CAF and log
each buffer's `hostTime`, `sampleTime`, frame offset and frame count. Combined
ffmpeg AVFoundation capture dropped audio packets on this VM. Record desktop video
separately with original input PTS, then align the common interval using host
timestamps. Finalize `AVAudioFile` before exit and compare decoded frames with
callback totals; distinguish a truncated EOF from interior gaps.

The [audio test report](https://app.devin.ai/attachments/0b002cd6-e974-40ea-a7a5-ab20371dd017/report.md)
and [reproduction scripts and logs](https://app.devin.ai/attachments/a43e66f1-f8a0-4c80-b3b0-805fe5078ddf/candy-audio-evidence.tar.gz)
document the Debug `13cae2b` two-iPad acceptance run, native tap feedback, per-peer
mute isolation, waveform/clock checks and the timestamp-aligned video. Its CAF had
zero interior gaps and a 6.67 ms silent EOF discrepancy after all outcomes; the
delivered interval excludes that tail. The analysis environment used Python 3.9
with numpy 2.0.2, scipy 1.13.1, av 15.1.0 and Pillow 11.3.0.

List devices with `xcrun simctl list devices available`. Use **two different UUIDs**:

```sh
export IPAD_A='<first iPad UUID>'
export IPAD_B='<second iPad UUID>'
xcrun simctl boot "$IPAD_A"
xcrun simctl boot "$IPAD_B"
open -a Simulator
xcrun simctl bootstatus "$IPAD_A" -b
xcrun simctl bootstatus "$IPAD_B" -b
xcrun simctl install "$IPAD_A" build/Build/Products/Debug-iphonesimulator/CandyCadence.app
xcrun simctl install "$IPAD_B" build/Build/Products/Debug-iphonesimulator/CandyCadence.app
xcrun simctl launch "$IPAD_A" ai.candycadence.game
xcrun simctl launch "$IPAD_B" ai.candycadence.game
```

In A, enter a guest name and **Create a room**. In B, enter another name, copy A's
six-character room code and **Join the party**. The host selects a song. Both tap
Ready. A four-second common countdown precedes the song's one-bar musical count-in.
Use Simulator's Window menus to display both complete devices side by side.

### Repeatable automated input

The opt-in automated driver is visibly labeled, including on the results. It reads
the bundled authored chart and invokes **the same `GameClient.hit` method and
WebSocket input protocol as each native touch button**. It cannot set score,
health, groove or outcomes. Host aims at +8 ms; guest at +62 ms and intentionally
omits every seventeenth note. These are two real native peers, not fake opponents.

```sh
xcrun simctl launch "$IPAD_A" ai.candycadence.game --name Mallow --create --auto
# Read the room in A or the server's JSON "joined" line.
xcrun simctl launch "$IPAD_B" ai.candycadence.game --name Fizzy --room ABC123 --auto
```

Alternatively use URL hooks while the app is running:

```sh
xcrun simctl openurl "$IPAD_A" 'candycadence://connect?name=Mallow&create=1&auto=1'
xcrun simctl openurl "$IPAD_B" 'candycadence://connect?name=Fizzy&room=ABC123&auto=1'
xcrun simctl openurl "$IPAD_A" 'candycadence://rematch'
xcrun simctl openurl "$IPAD_B" 'candycadence://reconnect'
```

`server=ws%3A%2F%2F127.0.0.1%3A8789` is an optional URL parameter. Omitting `auto=1`
uses manual touch. Ready and rematch hooks only send their normal lobby commands.
There is deliberately no score-setting or victory-forcing endpoint.

Each app logs input origin, peer identity, phase, common audio start and results to
its sandbox `Documents/telemetry.jsonl` (tab-separated event payloads). During
playback, `audio_clock` also samples the actual `AVAudioPlayer.currentTime`,
server/start timestamps, playback state and volume once per second. The server
emits JSON events to stdout. Capture the same match, not separate solo runs:

```sh
xcrun simctl io "$IPAD_A" recordVideo --codec=h264 left.mov &
LEFT_PID=$!
xcrun simctl io "$IPAD_B" recordVideo --codec=h264 right.mov &
RIGHT_PID=$!
# Let the lobby, song and shared results run; then:
kill -INT "$LEFT_PID" "$RIGHT_PID"
# Align concurrent capture start timestamps, preserve both complete displays,
# then hstack with ffmpeg. simctl recording itself does not capture audio.
```

Use a real system-audio recorder when available; disclose silent screen captures.
Always inspect/ffprobe recordings. Never count a build or solo run as multiplayer
evidence. Manual button targets expose accessibility IDs `lane-1` … `lane-9`.

## Controls and game rules

- White/yellow/green/blue/red/blue/green/yellow/white, left to right.
- Lower row: 1, 3, 5, 7, 9. Upper row: 2, 4, 6, 8.
- Hit a note's lane when its pop face reaches the horizontal white line.
- Simultaneous notes require chords; every lane carries authored notes.
- SWEET/COOL ±45 ms: 100%; GREAT ±90 ms: 80%; GOOD ±140 ms: 50%;
  BAD ±180 ms: 10%. Notes expire as MISS after 240 ms (network grace).
- Maximum score is 1,000,000. GOOD or better builds combo and +1.5 groove;
  BAD/MISS resets combo and loses 5 groove. Groove starts at 30, clamps to 0–100.
  At least 70% at song end clears; 100% is FEVER. Higher score wins the contest.
- Menu adjusts music volume and ±100 ms input calibration. The shared song is not
  paused by menus. Rematch returns both players to song selection with scores reset.

## Audio, art and charts

`Scripts/compose.py` is a deterministic standard-library synthesizer. It authors
melody, chord stabs, bass, kick, snare and hats, then renders signed 16-bit WAVs.
Each track has a count-in and 24 four-beat bars with repeating/answering note
phrases, lighter verse sections, sweeps and chorus chords. There are 184 notes per
chart, on eighth-beat positions. Nine quiet pitched tap sounds provide feedback.

`Sugar Rush Parade`: 120 BPM / 52 s / level 6.
`Soda Galaxy`: 138 BPM / 45.478 s / level 8.

All game illustrations are original vector artwork in `CandyScene.swift`, rendered
at native resolution with animated heads/bodies/arms, pop faces, hit sparkles and
button squashes. No extracted reference assets, fonts or music are shipped.

## Architecture and protocol

See [PROTOCOL.md](PROTOCOL.md). Node with pinned `ws` owns rooms, notes, scoring,
misses, readiness and outcomes. SwiftUI owns navigation; SpriteKit renders the
musical timeline; nine independent UIKit `touchDown` buttons permit chords.
`URLSessionWebSocketTask` transports JSON. Native AVAudioPlayer schedules the same
bundled track on each device against a measured server clock.

## Checks

```sh
npm --prefix Server run check
npm --prefix Server test
npm --prefix Server audit
xcrun swift-format lint --strict --recursive App
xcodebuild -project CandyCadence.xcodeproj -scheme CandyCadence \
  -sdk iphonesimulator -configuration Release -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
bash Scripts/verify-bundle.sh build/Build/Products/Release-iphonesimulator/CandyCadence.app
# Regenerate original assets, or project configuration:
python3 Scripts/compose.py
xcodegen generate
```

Tests cover judgment boundaries, simultaneous chords, duplicate inputs, missed-note
accounting, chart/music beat alignment, room limits, host selection, independent
peer IDs, synchronized starts, shared scores/results, reconnect and rematch.

## Known limits

- Archival reference screenshots inform art direction; the original arcade is
  inaccessible. No literal pixel parity, original song/chart parity or identical
  arcade timing is claimed.
- Two original songs, not the reference's licensed catalog or modes.
- LAN guest play, two peers per room, in-memory state. Disconnected seats remain
  reserved; both-offline rooms expire after two minutes. No server-restart recovery.
- Reconnect token lives in the app process; process termination requires a new
  room. An ordinary socket disconnect preserves identity and all match progress.
- Server time validation allows 220 ms packet/clock skew; this is local friendly
  competition rather than hardened ranked anti-cheat. Unencrypted `ws` is intended
  for trusted LAN use; configure TLS before internet exposure.
- Hardware audio output latency and Bluetooth calibration vary. BlackHole provides
  real simulator loopback for waveform and timing checks; it does not establish
  physical speaker, Bluetooth or iPad output latency. Earlier silent recordings
  were captured before the virtual audio endpoint was installed.
- iPad landscape only. Full VoiceOver rhythm gameplay and physical-device touch/
  audio latency are not asserted by simulator evidence.
