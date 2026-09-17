# Skyline Pulse

![Skyline Pulse screenshot](screenshots/skyline-pulse.jpg)

A native **iPad landscape** rhythm score battle inspired by the perspective highway and broad touch slider of Chunithm. Original character **Aria**, two original electronic tracks, 16 touch segments, red taps, gold sustained notes, cyan moving slides, green upward air gestures, per-tick timing/combo/accuracy, real two-player WebSocket rooms and mutual rematches.

The tablet choice preserves the wide two-hand slider and gestures without shrinking sixteen touch segments beside the character/HUD. This is SwiftUI + SpriteKit + AVFoundation, not a web view. Reference research and the explicit adaptation boundaries are in [REFERENCE.md](Docs/REFERENCE.md). No arcade assets, music or ROMs are bundled.

## Build

Validated environment: macOS with Xcode 26.6 / iOS 26.5 simulator runtime, Node, npm, ffmpeg. Minimum app deployment iPadOS 17. No Apple developer account is needed for simulator builds.

```sh
cd skyline-pulse
cd Server && npm ci && cd ..
make lint
make build
make test                    # includes a real-time ~54s two-socket match
make server                  # ws://127.0.0.1:8769, LAN bind 0.0.0.0
```

The Xcode project is committed, so XcodeGen is not needed to build. To regenerate after changing `project.yml`: `brew install xcodegen` (used 2.46.0), then `xcodegen generate`. Swift formatting/lint is Xcode's supported `swift format` command; no SwiftLint dependency.

Open `SkylinePulse.xcodeproj`, select `SkylinePulse`, select an iPad simulator, Run.

## Two devices

Boot two distinct iPad simulators via Xcode/Simulator or CLI:

```sh
xcrun simctl list devices available
xcrun simctl create "Pulse Aria" "iPad mini (A17 Pro)" com.apple.CoreSimulator.SimRuntime.iOS-26-5
xcrun simctl create "Pulse Nova" "iPad mini (A17 Pro)" com.apple.CoreSimulator.SimRuntime.iOS-26-5
# Substitute the returned UDIDs:
xcrun simctl boot "$ARIA_DEVICE"
xcrun simctl boot "$NOVA_DEVICE"
open -a Simulator
xcrun simctl install "$ARIA_DEVICE" .build/Build/Products/Debug-iphonesimulator/SkylinePulse.app
xcrun simctl install "$NOVA_DEVICE" .build/Build/Products/Debug-iphonesimulator/SkylinePulse.app
xcrun simctl launch "$ARIA_DEVICE" games.skylinepulse.arcade
xcrun simctl launch "$NOVA_DEVICE" games.skylinepulse.arcade
```

Both simulators access the same Mac server with `ws://127.0.0.1:8769`. Real iPads use the Mac's LAN IP (editable in the app); allow local-network permission. Use guest names, create a room on one iPad, enter its displayed six-character code on the other, select the song on the host, then **READY TO FLY** on both. Music starts at the shared countdown. There are no fake rivals or account requirements.

## Controls

- **Tap:** touch any segment beneath the red note when it reaches the gold line.
- **Hold:** keep a finger down in the gold ribbon. Each half-beat tick is scored; release loses ticks and reholding recovers.
- **Slide:** maintain contact while following the cyan ribbon horizontally.
- **Air:** start on the slider and swipe upward at least 9% of screen height within half a second as the green chevron reaches the line.
- Multiple fingers and chords are supported.
- **HOW TO PLAY** provides the controls and ±150ms timing adjustment.
- Music runs to its actual outcome. Results compare both players, detailed judgments and max combo. Both select **REMATCH** for a new shared round. **RECONNECT** preserves the in-memory guest identity. **LEAVE ROOM** returns to selection.

## Repeatable native automation

For an **external computer-use test with autoplay disabled on both devices**, use
[the runnable harness and setup instructions](Tools/computer-use/README.md).
It clicks and types into both Simulator windows, then sends genuine macOS mouse
down/drag/up events through the apps' native touch callbacks. The single shared
cursor alternates players and intentionally skips overlapping notes. The bundle
includes strict gameplay assertions, calibrated window configuration, real audio
capture, synchronized video validation and cleanup commands.

```sh
make computer-use-check
make computer-use-build
```

Follow the harness README to supply your two device IDs and desktop geometry,
then run `prepare.py`, `run.py`, `assertions.py` and `validate-media.py`.
The strict validator exits nonzero when selected note probes fail; successful
driver completion alone is not an all-green test result.

### In-app input driver

Launch arguments control a **visibly labeled input driver**, never scores or judgment injection:

```sh
xcrun simctl launch "$ARIA_DEVICE" games.skylinepulse.arcade \
  --name ARIA --server ws://127.0.0.1:8769 --create --autoplay
# Read the actual room code from the app/server log, then:
xcrun simctl launch "$NOVA_DEVICE" games.skylinepulse.arcade \
  --name NOVA --server ws://127.0.0.1:8769 --room "$ROOM" --autoplay --driver-delay 0.06
```

Driver uses the same `Session.touch` → WebSocket path as SpriteKit's native `UITouch` callbacks, maintains holds, traverses slides and issues down/move/up for air. Each process gets a distinct UUID. Both automatically ready once in the initial lobby; rematch remains a real UI action. Driver delay produces actual lower timing judgments on the second player. It does not write scores, force song completion or synthesize network opponents. For manual verification, omit `--autoplay`; touch input always remains active.

Capture both simulator streams simultaneously using `simctl io … recordVideo`, or record the desktop with both full displays visible. The delivered evidence should include a complete match, common result, rematch/rejoin, native manual control check and logs from the same run. Build/test success alone is not visual evidence.

## Music and assets

`Tools/compose.mjs` composes deterministic PCM synthesis: four-chord progression, melodic motifs, stereo arpeggios, bass, kick/snare/hi-hat and echoes. Charts use authored four-phrase patterns aligned to BPM, not random falling blocks. `make music` recreates charts, compressed AAC music and the short synthesized touch sound with ffmpeg. Bundled compressed tracks are ready to play; generating music is not required to build. WAV intermediates are ignored.

- **Neon Ascent:** 128 BPM, 48.75 seconds, advanced.
- **Aurora Circuit:** 144 BPM, 50 seconds, expert with extra syncopation.
- `aria.png`: original generated anime illustration created for this game, used in the selection cards and gameplay side panel.

## Architecture and limits

See [PROTOCOL.md](Docs/PROTOCOL.md) for ordered input, server judgments, clocks, reconnect and room lifecycle. `Server/test.mjs` tests actual scoring consequences and room validation; `Server/battle.test.mjs` runs two real WebSocket clients through an entire chart/results/rematch. Native source is typechecked by `xcodebuild`; lint uses `swift format lint --strict`.

The physical arcade air sensors are adapted to upward touch gestures. Timing windows, score formula, music, illustration, selection and competitive room flow are original. No literal pixel parity is claimed. The original arcade software was not available for direct interaction/comparison. No persistent accounts, long-term leaderboards, licensed catalog, or cabinet progression system. Automatic reconnection works within the running app; restarting it loses the room token. LAN timing depends on network and device audio latency; the settings screen allows local input calibration. Backgrounding stops touch input; the shared round continues.
