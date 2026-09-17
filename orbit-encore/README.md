# Orbit Encore

![Orbit Encore screenshot](screenshots/orbit-encore.jpg)

A native **iPhone rhythm score battle**, inspired by maimai's eight-position
circular cabinet. Tap outward-moving rings, sustain holds, trace cyan star paths,
hit two-finger yellow pairs and weighted gold breaks. Both guests play authored
charts against a common song clock over real WebSockets.

**App:** Orbit Encore · **bundle:** `games.orbitencore.ios` · **server:** port `8788`

## Build and run

Tested toolchain: macOS, Xcode 26.6, iOS Simulator 26.5, XcodeGen 2.46.0,
SwiftLint 0.65.1, Node 22+. Minimum deployment target iOS 17; portrait iPhone.
No Apple developer account is needed for simulator builds.

```sh
cd orbit-encore
brew install xcodegen swiftlint  # if missing
npm --prefix server ci
./scripts/check.sh
```

The generated Xcode project is included; regeneration uses `xcodegen generate`.
Music and charts are committed, so neither generation nor an API key is required
to build. To regenerate the original PCM music and charts:

```sh
npm --prefix server run assets
```

Run the local authoritative server in a terminal:

```sh
npm --prefix server start
```

Run `build/Build/Products/Debug-iphonesimulator/OrbitEncore.app` using Xcode's
OrbitEncore scheme or install it with `simctl`:

```sh
xcrun simctl list devices available
xcrun simctl boot DEVICE_UDID
xcrun simctl bootstatus DEVICE_UDID -b
xcrun simctl install DEVICE_UDID build/Build/Products/Debug-iphonesimulator/OrbitEncore.app
xcrun simctl launch DEVICE_UDID games.orbitencore.ios
open -a Simulator
```

Repeat with a **different** iPhone simulator UDID. On the first phone enter a
guest name and create a stage. On the second enter another name and the displayed
six-character room code, then join. Select a track on the host and press Ready
on **both** phones. A five-second scheduled countdown starts the same track.
Use `ws://127.0.0.1:8788` for simulators on this Mac; on physical devices use the
Mac's LAN IP, such as `ws://192.168.1.10:8788`. The address is editable on the
connection screen. There is no public deployment or identity service.

## Music and controls

| Track | Tempo | Length | Chart |
|---|---|---|---|
| Sugar Satellite | 128 BPM | 46.88s | Advanced 5, 75 notes |
| Neon Perihelion | 150 BPM | 52.80s | Expert 8, 119 notes |

Both tracks are original deterministic synth arrangements with kick, snare,
offbeat hats, bass, changing chords and melodic arpeggios. A four-beat audible
count-in precedes chart events; the beat grids used by music/chart generation are
identical. `cosmic-bunny.png` is original generated art used in the live playfield,
song jackets, lobby and results. No external/reference audio or artwork is bundled.

- **Tap:** touch the corresponding rim target when the pink ring arrives.
- **Hold:** keep the same finger within its target until the tail arrives.
  Releasing more than 70ms early or leaving the lane misses.
- **Slide:** tap the star head, trace cyan checkpoints **in order**, then finish
  at the last target when the moving star reaches it. The final endpoint radius
  is 0.10 arena units; intermediate checkpoints allow 0.23.
- **Each:** yellow linked notes are simultaneous two-finger taps.
- **Break:** golden notes are worth five ordinary taps.
- **Results:** both players choose Encore to return to song selection; leave exits.
- **Help/settings:** functioning instruction sheet, music preview, volume, audio
  delay (−200…+200ms), copy room code and reconnect.

Timing windows are symmetric: Perfect ±50ms, Great ±105ms, Good ±160ms;
otherwise Miss. Weights: tap/each 1, hold 2, slide 3, break 5. Award factors are
1/.75/.4/0. Score is earned weight / chart total × 1,000,000; achievement is the
same ratio as a percentage, climbing throughout the song. Slide judgment is the
worse of head and tail. Misses reset combo. Ranking: SS ≥98%, S ≥90%, A ≥80%,
B ≥65%, otherwise C. These are this game's published rules, not a claim about
SEGA's exact timing/scoring internals.

## Architecture and tests

SwiftUI owns connect/lobby/game/results/help/settings screens. SpriteKit draws
the animated playfield at 60fps with real UIKit multitouch; native AVAudioPlayer
schedules PCM playback on the audio device clock. WebSocket snapshots run at
~30Hz. The Node server owns chart selection, readiness, start time, note state,
judgment, scores and results. See [PROTOCOL.md](docs/PROTOCOL.md).

`npm --prefix server test` includes timing-window boundaries, wrong lanes,
replayed inputs, invalid coordinates, early-release/moved holds, skipped slide
checkpoints, simultaneous notes, full authored chart scoring and an actual
two-WebSocket integration journey through room limits, common start, independent
scores, token-based same-player reconnect, shared results and rematch.

### Reproducible two-device automation

The app accepts these simulator launch arguments:

```sh
# First iPhone creates a real room:
xcrun simctl launch FIRST_UDID games.orbitencore.ios \
  --connect --name Nova --server ws://127.0.0.1:8788 --autoplay perfect --auto-ready
# Read the displayed room code (also in the local server's JSON join event).
xcrun simctl launch SECOND_UDID games.orbitencore.ios \
  --connect --name Lumi --room ROOM_CODE --server ws://127.0.0.1:8788 \
  --autoplay balanced --auto-ready
```

The **visible `AUTOMATED INPUT` banner** identifies the input driver. It moves
independent virtual fingers along chart targets/paths through the same
`OrbitScene.handleInput → GameClient.input → WebSocket → server input()` path as
UIKit touch events. It cannot set health, score or outcome. `perfect` aims near
the chart time; `balanced` intentionally aims 65ms later. There is no AI rival.
Without `--autoplay`, only real touches control the game. Manual controls can
also be exercised while a driver is running; they are logged separately.

Each simulator writes `Documents/telemetry.jsonl` with peer IDs, shared start,
audio scheduling, input source and per-second score/time snapshots:

```sh
xcrun simctl get_app_container FIRST_UDID games.orbitencore.ios data
```

Capture **both devices simultaneously** through the entire match, include the
results and an Encore/reconnect check, and retain telemetry plus server JSON
logs from the same run. `simctl io UDID recordVideo` records each stream; an
unspliced side-by-side ffmpeg composition is acceptable. Simulator video streams
do not themselves prove physical speaker latency. Final recording/report
attachments are delivered on the PR/session rather than committed as source.

## Reference and limits

[REFERENCE.md](docs/REFERENCE.md) records inspected official images, gameplay
descriptions, observations, inferences and the acceptance inventory.

Original cabinet software was not available. This is a reference-inspired
native adaptation, not a pixel-identical replica, and uses an original mascot,
music, chart catalog and title. Modern DX touch/EX types and commercial catalogs
are not included. App is portrait iPhone; iPad/physical-device validation is not
claimed. The local server stores rooms in memory and expires disconnected rooms
after two minutes; restarting it clears rooms. Guest rejoin tokens persist for
the running app session, not across app termination. Network timing compensates
small LAN delay; this is not an internet tournament anti-cheat system. Wired
audio is recommended; Bluetooth and physical output latency require calibration.
Audio delay is an app-session setting and takes effect on the next song.
