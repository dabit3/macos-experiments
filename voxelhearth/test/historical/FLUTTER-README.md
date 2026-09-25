# Voxelhearth

An original multiplayer voxel sandbox. One Dart/Flutter codebase produces four
real clients — **web**, **iOS**, **Android** and **macOS** — that all connect to
a dedicated authoritative Dart server and play in the same world together.
A cross-platform automated match (`test/multiplayer-e2e.sh`) starts the server,
launches every client, drives them through a scripted match and proves they
all observe byte-identical world state, chat history and results.

Voxelhearth is a clone-this reproduction of the *publicly documented* design of
a well-known commercial voxel sandbox. The source title was never run or
purchased for this work; only public wiki/design documentation was used, and
every asset, name, texture, creature and recipe here is original. The four
Voxelhearth clients are held to *normalized visual parity with each other*
(web is the visual baseline), never to literal pixel parity with the source.
See `.devin/clone-this/voxelhearth/` for the run manifest and evidence.

## What is in the game

* **World** — deterministic, seeded, chunked (16×16×64) terrain that streams
  endlessly around the player: five biomes (plains, forest, desert, tundra,
  mountains), height/erosion noise, carved caves, Oakheart and Frostpine
  trees, coal/iron/gold/ember ores by depth, water, sand, gravel, clay, snow.
* **Movement** — first-person walk, sprint, sneak, jump, swim (with air
  meter), auto step-up, creative fly.
* **Blocks** — break with tool-tier and hardness based speeds, place on any
  face, 30+ original block types (torches, lanterns, glass, bricks, wool,
  cactus, emberbloom flowers…).
* **Inventory & crafting** — 36 slots with a 9-slot hotbar, tap-to-move slots, a
  hand 2×2 grid and a Workbench 3×3 grid with 28 real shaped/shapeless
  recipes (planks, sticks, workbench, kiln, chest, torches, lantern, bed, all
  wooden/stone/iron/ember picks, axes, shovels and swords, glass, bricks, stew…).
* **Kiln** — smelting loop with input / fuel / output slots (raw iron → ingot,
  sand → glass, clay → brick, raw chop → cooked chop…), fuel burns in ticks.
* **Survival** — health, hunger with regeneration/starvation, fall and
  drowning damage, food, death and respawn at your bed.
* **Day/night** — 24 000-tick day with sky and block lighting, torches and
  lanterns light caves, fog, dawn/dusk tint.
* **Creatures** — passive Mossbacks by day (drop chops), hostile Hollows and
  Cinderlings at night. All original.
* **Beds** set spawn and skip the night; **chests** persist per world.
* **Modes** — survival or creative per room; pause / settings sheet with
  look sensitivity, FOV, render quality (auto-scales to hold 60 fps), touch
  controls, system/dark/light theme.
* **Persistence** — the server saves each world's edits, chests, kilns and
  player inventories to `--save-dir` and restores them on restart.
* **Multiplayer** — rooms with 5-letter join codes, lobby → match → results
  flow, ready states, host controls, server-side bots to fill a room, other
  players rendered with name tags, synchronized block edits, chat, per-player
  inventories, reconnection with the same identity (a dropped host keeps the
  role for 30 s so a quick rejoin keeps control).
* **Arcade presentation** — original floating-island title artwork, a bold
  Outfit wordmark, drifting embers, navy/teal surfaces and honey-gold primary
  actions. Buttons have pressed, hover, keyboard-focus and disabled states,
  sound and haptic feedback. Lobby player cards, celebration particles and
  ranked results carry the same visual language. Menus respect reduced
  motion and compact landscape phone layouts. The gameplay GUI retains its
  integer 2–4× grid, Pixelify Sans labels, 18×18 item slots, warm ivory
  inventory panels and 182×22 hotbar. Gold block outlines and a circular
  break-progress meter give direct feedback over teal skies and water.
  Outfit and Pixelify Sans are licensed under the OFL; bundled license files
  are in `app/assets/fonts/`. Title key art was generated specifically for
  Voxelhearth; it is promotional illustration, not a gameplay screenshot.
* **Feedback** — original procedurally generated sound cues (UI, dig, place,
  break, craft, eat, hurt, chat, match start/end; `tools/gen_audio.py`),
  haptics on touch platforms, both toggleable in settings.
* **Rendering** — a single full-screen fragment shader ray-marches a packed
  128×64×128 voxel window (block id + sky light + block light per texel) with
  an original procedurally generated 16×16 tile atlas, smooth per-voxel
  lighting, ambient occlusion, cutout plants, translucent water/glass,
  entities, block selection outline and break cracks. Because the world is
  sampled per pixel there is no per-chunk mesh to rebuild, so edits appear
  instantly on every platform.

## Layout

```
voxelhearth/
├── packages/voxelhearth_core   shared rules: worldgen, blocks, recipes, physics,
│                               simulation, protocol, hashes (pure Dart)
├── server/                     authoritative Dart shelf + WebSocket server
├── app/                        Flutter client (web, ios, android, macos)
├── test/                       e2e harness (Node + Playwright + simctl + adb)
├── PROTOCOL.md                 JSON-over-WebSocket protocol
└── .devin/clone-this/          clone-this manifest and evidence
```

## Requirements

* Flutter 3.47+ / Dart 3.13+ (`brew install --cask flutter`)
* Xcode 26 with an iOS Simulator (for iOS) and the macOS desktop toolchain
* Android SDK with `platform-tools`, `emulator` and an AVD (for Android)
* Node 20+ (for the automated test)

## Run the server

```sh
cd voxelhearth/server
dart pub get
dart run bin/server.dart --port 8787 --save-dir saves --web-root ../app/build/web
```

Options: `--host`, `--port`, `--save-dir`, `--web-root` (serves the built web
client at `/`), `--seed`, `--director-key`, `--test-mode` (deterministic room
codes/tokens, cheats and the director channel used by automation).
`GET /health` returns `ok`.

## Run the clients

All clients default to `ws://localhost:8787/ws` (Android emulator:
`ws://10.0.2.2:8787/ws`); the server can be changed on the home screen.

```sh
cd voxelhearth/app && flutter pub get

# Web (dev)
flutter run -d chrome
# Web (release) — then open http://localhost:8787 from the server above
flutter build web --release

# iOS Simulator
open -a Simulator && flutter run -d iPhone

# Android emulator
$ANDROID_SDK_ROOT/emulator/emulator -avd <name> &
flutter run -d emulator-5554

# macOS (native window)
flutter run -d macos
```

Launch overrides for automation (`VH_SERVER`, `VH_NAME`, `VH_JOIN`,
`VH_CREATE`, `VH_TEST`) are read from `?query` params on web, process
environment on macOS, `-VH_KEY value` launch arguments on the iOS Simulator
and `--es VH_KEY value` intent extras on Android.

### Controls

| | Desktop / web | Touch (iOS, Android) |
|---|---|---|
| Move / look | WASD + mouse (click to capture) | left joystick / drag right side |
| Jump / sneak / sprint | Space / Shift / Ctrl or Cmd | jump, sneak & sprint buttons |
| Break / place | left / right mouse (hold to dig) | stationary hold / Place button |
| Hotbar | 1-9, scroll | tap slot |
| Inventory / chat / pause | E / T / Esc | HUD buttons |
| Drop / toggle fly (creative) | Q / F | HUD buttons |

## Automated four-platform multiplayer test

```sh
cd voxelhearth/test && npm ci && npx playwright install chromium
cd .. && ./test/multiplayer-e2e.sh                     # web,ios,android,macos
VH_PLATFORMS=web,ios,macos ./test/multiplayer-e2e.sh   # subset
VH_SKIP_BUILD=1 ./test/multiplayer-e2e.sh              # reuse existing builds
```

The script builds the selected clients, boots the iOS Simulator and the
Android emulator, starts a fresh `--test-mode --seed 1234` server, then runs
`test/multiplayer-e2e.mjs`, which:

1. launches Chromium (Playwright, with video), the iOS app (`xcrun simctl`),
   the Android app (`adb`) and the macOS app, each in test mode;
2. has web create room `HEARTH` and every other client join it, verifies the
   lobby roster, and starts the match with the director channel;
3. probes the terrain in front of the host and picks one shared row of cells;
   each client places a block on the lower row (verified on the server), then
   each client breaks the block above it with a stone pick;
4. every client sends a chat line;
5. the web client (the host) severs its socket and must rejoin the same
   room and player via its session token while the match keeps running;
6. asks the server and every client for `worldHash`, `chatHash` and the
   region hash of the structure and asserts they are all identical, and that
   the structure matches the expected placements/breaks exactly;
7. ends the match and asserts the results screen (scores, placed/broken
   counts, world/chat fingerprints) is identical on every client and matches
   a fresh authoritative server query after the final match message;
8. captures `home`, `lobby`, `gameplay`, `structure`, `chat` and `results`
   screenshots per platform and composes the per-platform frame captures into
   `four-way-recording.mp4` (plus the raw Playwright `web-recording.webm`);
9. cuts an **edited review video** (`review-video.mp4`) from the same frames:
   the run's chapter markers (lobby, gameplay, structure, breaking & chat,
   reconnect, verification, results, visual fixtures) become title/chapter
   cards, side-by-side web | iOS footage with platform labels, captions, a
   chapter timeline and a closing check summary. The editor is
   `test/tools/review-video.mjs` (`node review-video.mjs script.json out.mp4`;
   Playwright renders the Outfit/teal/gold overlays, FFmpeg composites them), driven
   by the `review-script.json` the e2e writes next to it.

Output lands in
`.devin/clone-this/voxelhearth/evidence/tests/e2e-<timestamp>/` with
`report.md`, `report.json`, `e2e.log`, `server.log`, per-platform logs, the
screenshots, the raw recording and the edited review video. PNG/MP4 files are
git-ignored and attached to the PR instead.

### Latest evidence

The arcade redesign's builds, multiplayer checks, UI reports, screenshots
and programmatically edited review videos are indexed in
`.devin/clone-this/voxelhearth/evidence/tests/checks/arcade-summary.md`.
The scripted test drives real web and iOS clients in one room in parallel;
the separate computer-use recording exercises their actual controls.
Neither recording is a promotional mockup of gameplay.

The evidence index distinguishes current arcade verification from historical
design passes. Scripted runs record shared world/chat fingerprints, structure
regions, final scoreboards, reconnect results and the platforms that actually
participated. The Android APK builds, but the Android
emulator on the build machine could not reach `sys.boot_completed` (nested
virtualization — `HVF error: HV_UNSUPPORTED`, software rendering never
finished booting), so Android has **not** been exercised in the live match.
The harness fully supports it (`VH_PLATFORMS=web,ios,android,macos`) on a host
with a working emulator. This is recorded as an external blocker in
`.devin/clone-this/voxelhearth/state.json`.

The separate **real-UI (computer-use) pass** drives Chrome and the iPhone 17
Simulator through actual menus, HUD and touch controls without the director
channel. Its reports, screenshots, markers and edited video are linked from
the evidence index. Earlier recordings remain historical evidence. The
arcade regression fixes include stable iOS chat focus and draft retention
when the keyboard opens, compact lobby rules, and correctly sized buttons.
Simulator captures use its recorded landscape orientation so screenshots and
review footage remain upright in either landscape direction.

The run also records a **visual matrix**: every client renders identical
fixture data for the lobby, results and home screens; the web capture is the
baseline and the native macOS window (pinned to the same 1280×800 logical
viewport with `VH_WINDOW`) must match it structurally — every text/icon node
at the same position and size within 2 logical px, and a zero-pixel diff of
the normalized layout maps. Raw screenshot diffs are recorded but not
asserted (font rasterization differs between Skia-on-Chromium and Impeller-
on-Metal). The iPhone capture is a different responsive layout family and is
recorded, not compared. The `nodes.json`, layout maps and diffs are in the
run's `visual/` folder.

**Frame rate on the build machine:** the measured in-match FPS on this
virtualized, software-rendered macOS host ranged ~20–33 (Chromium), ~21–60
(iOS Simulator) and ~35–58 (native macOS) across runs, varying with host load.
Render quality auto-scales, but a steady 60 fps on every platform has **not**
been demonstrated on this host; it needs a machine with a hardware GPU.
Recorded honestly as an open item rather than claimed.

**iOS Simulator flakiness:** one run failed because the Simulator's
`SimMetalHost` process crashed (`XPC_ERROR_CONNECTION_INTERRUPTED`) before the
app drew its first frame. `xcrun simctl shutdown <udid> && xcrun simctl boot
<udid>` recovered it and the next run passed; crash reports are kept under
`evidence/tests/ios-simulator-metal-crash/`.

## Development checks

```sh
cd packages/voxelhearth_core && dart format --set-exit-if-changed . && dart analyze && dart test
cd ../../server && dart analyze
cd ../app && dart format --set-exit-if-changed lib test && flutter analyze && flutter test
flutter build web --release && flutter build macos --debug \
  && flutter build ios --simulator --debug && flutter build apk --debug
python3 ../tools/gen_icons.py   # regenerate the original app icon set for every target
python3 ../tools/gen_audio.py   # regenerate the original sound cues in app/assets/audio
```

## Intentional deviations from the reference design

* Fixed 64-block world height and a 128×64×128 render window (ray-marched
  shader instead of greedy-meshed chunk geometry — same visual result, no
  mesh rebuild latency, and it keeps the four platforms pixel-consistent).
* A 5-letter join-code room model with lobby → match → results and a score
  (placed + broken + crafted×3 + kills×5) so the sandbox has a match that can
  be verified end-to-end; free play (`durationTicks = 0`) is still available.
* Original block/item/creature names and art; three creature types instead of
  a bestiary; one tree per biome family.
* No redstone-style logic, enchanting, dimensions or villages.
