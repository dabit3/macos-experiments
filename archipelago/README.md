# Archipelago

![Archipelago screenshot](screenshots/archipelago.jpg)

A native, landscape-first iPad logistics game. Connect five hand-drawn isometric
islands, assign four distinct ferries, and bring the distant lighthouse to life.
SwiftUI and Canvas render all artwork locally: turquoise water, fields, windmill,
woodland, quarry, terracotta villages, docks, route overlays, and vessels.
No network, paid service, account, project generator, or third-party dependency.

## Prerequisites and build

- macOS with full Xcode selected (`xcode-select -p`)
- Tested with Xcode 26.6 (17F113), Swift 6.3.3, macOS 26.5.2
- iOS deployment target 17.0; an installed iPad Simulator runtime is required to run
- Tested runtime: iOS 26.5. iPad only, landscape in either direction.
- No signing credentials for Simulator builds. The supplied artifact is **Simulator-only**.

From this directory:

```sh
bash scripts/check.sh
bash scripts/build.sh
xcrun simctl list devices available
bash scripts/run.sh <your-local-ipad-simulator-udid>
```

`Archipelago.xcodeproj` and its shared scheme are ready to open in Xcode.
The build script compiles for the generic iOS Simulator destination (arm64 and x86_64),
placing the app at `build/Build/Products/Debug-iphonesimulator/Archipelago.app`.
The run script boots, installs, and launches on the supplied device. Rotate the
Simulator to landscape if necessary using Device → Orientation.

## The first chapter

The opening sea is paused. There is no failure timer or forced tutorial.

1. Tap **New route**. Choose **Sunfield → Port Azure**, then **Create route** (60 coins).
2. In the selected route inspector, assign **Marigold** (12 crates, 1× speed).
3. Create **Pinehaven → Port Azure** and assign **Juniper** (18 crates, 0.85× speed).
4. Press **Play**, then **4×**. Watch vessels load, arrive, and return. Select islands
   to see their real stocks. Every delivered crate earns 3 coins.
5. Select the Sunfield route, choose **Edit**, and change its destination to
   **Lantern Isle**. Cargo in transit returns to Sunfield before the new trip.
6. Deliver at least 36 total crates and 8 grain to Lantern Isle to complete the chapter.
   Its warning clears, the lighthouse beam lights up, and free play continues.
7. Pause, **Save**, change something, then **••• → Reload checkpoint** to recover it.

Other available connections: Pinehaven → Roserock and Roserock → Port Azure.
Swift is a fast 8-crate ferry (1.5×); Coral carries 14 crates at 1.1×.
Five distinct producer/destination connections are possible; four may have boats
simultaneously. Tapping an assigned boat unassigns it; boats cannot serve two routes.
Route removal refunds 20 coins. Duplicate routes and insufficient budget produce
explanatory errors without changing the simulation.

### Controls and persistence

- Tap an island for inventory, production/consumption rates, lifetime receipts, and
  supply warnings. A stock below four crates is underserved.
- Tap a route card for its ferry, current cargo/direction, edit, or removal.
- Play/pause and 1×/2×/4× change how quickly fixed simulation ticks execute.
- **Undo** restores the snapshot before the latest route/ferry edit or restart,
  including elapsed simulation time. It is a single-level undo, held in memory.
- Progress autosaves atomically every 24 simulated ticks and on edits, pause, and
  scene deactivation. Relaunch resumes the saved voyage paused; it does not simulate
  time spent outside the app.
- **Save** creates a separate checkpoint. Reload pauses and restores it. Restart
  keeps that checkpoint and can itself be undone.
- **••• → Export voyage JSON** creates a real, validated snapshot in
  `Documents/Archipelago/Archipelago-voyage.json`. It is available in the Files app
  under On My iPad → Archipelago → Archipelago. After export, the menu offers the
  native share sheet. Autosave and checkpoint are `voyage.json` and `checkpoint.json`
  in the same folder. V1 does not expose arbitrary save-file import.
- Corrupt/unsupported saves show an error. A failed checkpoint reload does not alter
  current state. On launch with an unreadable autosave the sample scenario remains.

For Simulator artifact collection:

```sh
xcrun simctl get_app_container <udid> com.nader.archipelago data
# Append /Documents/Archipelago/Archipelago-voyage.json to that result.
```

## Deterministic model

`Sources/Core/Simulation.swift` is shared by the native app and dependency-free
Swift Package tests. `Game.advance(steps:)` is the only time-advancing operation.
At 1×, one tick represents 0.25 simulated seconds. The fixed update order is:

1. Increment tick. Every 24 ticks, each producer adds two crates when stock is below
   72 (the threshold can reach 73). Every 96 ticks, each consumer uses at most one
   crate of every resource it needs, only when available.
2. Visit routes in creation order. At departure load `min(capacity, source stock)`.
3. Advance by `1 / max(24, mapDistance * 160) * boatSpeed` of a one-way journey.
4. At arrival, transfer all cargo to destination inventory, increment lifetime
   receipts and delivery totals, pay three coins per crate, and start an empty return.
   A trip takes the ceiling of its duration in ticks; no fractional carry-over.

There is no random input. For each resource:

```text
initial crates + produced crates = island inventory + aboard cargo + consumed crates
```

Loading, unloading, route editing, removing, and unassigning preserve that identity.
Save validation checks this ledger, route uniqueness, capacity, IDs, valid needs,
finite positions, ferry uniqueness, and supported schema version.

### Intentional modeling limits

This is a bounded, peaceful transport puzzle, not a market simulator. Shortages do
not kill residents or remove money; inventories have no receiving cap. Production
does not require inputs, and prices do not fluctuate. Ships follow decorative
curved lanes without collision/pathfinding; distance comes from normalized island
coordinates and is unaffected by screen size. All ferries are owned at launch.
UI timers may slow under system load, but tick outcomes remain deterministic.
No background catch-up, cloud sync, sound, procedural world, or hardware dependency.
The custom chart uses fixed readable label sizes; accessibility labels are provided
for islands, route cards and controls, but very large Dynamic Type is not a tailored layout.

## Verification

```sh
bash scripts/check.sh
# Includes native swift-format strict lint, swift test, project plist validation.
bash scripts/build.sh
# Includes Swift 6 compiler/type checking and the complete native iPad app link.
```

Six meaningful core tests exercise 5,000-step conservation, loading capacity,
arrival/return timing and rewards, cargo recovery on edit/removal, invalid input and
transactional budget errors, duplicate assignment, deterministic save round-trip,
goal completion, and corrupt save rejection. Native UI testing is performed in
Simulator through real clicking, with a separately attached annotated recording,
full screenshots, exported sample and test report. Generated media, app binaries,
DerivedData, local saves, and personal Xcode state are intentionally untracked.

To regenerate the bundled original icon (macOS AppKit, no design-tool dependency):

```sh
swift scripts/generate-icon.swift Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

To format after edits:

```sh
xcrun swift-format format --in-place --recursive Sources Tests Package.swift scripts/generate-icon.swift
```
