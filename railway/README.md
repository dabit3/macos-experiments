# Railway — The Stillwater Line

![Railway — The Stillwater Line screenshot](screenshots/railway.jpg)

A native macOS miniature railway dispatch simulator. An original, procedurally drawn
forest diorama surrounds a working track graph: cream station buildings, layered
pine trees, timber sleepers, brass points and two moving passenger services.
All artwork is drawn locally with SwiftUI Canvas; the forest uses deterministic
irregular placement and the app icon is generated with AppKit during the build.
There are no downloaded assets,
network requests, external packages, accounts or hardware prerequisites.

## Build and run

Requirements: Apple Silicon Mac, macOS 14 or later, Xcode 26.6 command-line tools
(Swift 6.3.3, including `swift format`). Developed on macOS 26.5.2.
This is a reproducible Swift Package, so no project generator is required.
Open `Package.swift` in Xcode for source navigation, or run:

```sh
cd railway
./scripts/build.sh
./scripts/run.sh
```

The build creates `dist/Railway.app`, ad-hoc signed for local use. It is a native
macOS app, not a web view. This is not a notarized distribution or App Store release.
The supplied binary is arm64; Intel Macs require building from source with a
compatible Swift toolchain. A minimum 1120 × 780 window is supported; 1440 × 940
is the intended desktop presentation.

## Your first morning shift

1. The Fox (`R01`, red) starts at **Alder Grove**, bound for **Pine Summit**.
   Bluebird (`B02`, blue) starts at **Stillwater**, bound for **Alder Grove**.
   Destination pickers are editable before dispatch.
2. Dispatch both services, then choose **Run railway**. The Fox advances toward
   Block 01. Bluebird approaches the Stillwater STOP signal and holds.
3. Clear Stillwater's signal while The Fox owns Block 01. Bluebird continues to
   wait, now reporting **Block occupied by R01**. W1 and W2 are locked.
4. After The Fox arrives, change **W2** from Pine Summit to Stillwater.
   Bluebird enters the block and completes its delivery to Alder Grove.
5. Pause and **Save**, then **Reload** or quit and relaunch to inspect the state.
   The timetable includes actual simulated departure/arrival times.

The question-mark button opens the in-app field guide. **Space** toggles pause;
**⌘S** saves a checkpoint; **⌘O** reloads it. Speeds are 1×, 2× and 4×.
W1 chooses the direct main line or the longer forest loop before admission.
Switches are disabled while the conflict block is reserved. Signal buttons show
their current aspect; clicking toggles it. Signals stop approaching trains, not
trains already admitted into a reserved route.

The **…** menu exports the timetable, opens the guide, or starts a fresh shift.
Reset asks for confirmation and preserves the manual checkpoint, so **Reload**
provides recovery after a reset. Delivered services remain at their platforms;
start a new shift to run another pair.

## Persistence and exports

State is stored under `~/Library/Application Support/Railway/`:

- `autosave.json`: written on control changes, every two seconds during movement,
  and on ordinary application termination. Relaunch restores it paused.
- `checkpoint.json`: written only by **Save**. **Reload** validates it before
  replacing the current state and pauses for safe inspection.

Malformed or incompatible saved states produce a visible error and do not replace
the active shift. Autosave recovery failures start a fresh shift with an explanation.
Reset does not erase the checkpoint.

**Export timetable…** opens a native save panel for a real UTF-8 CSV. Choose any
destination; the default name is `Railway-timetable.csv`. Columns are service,
name, origin, destination, state, departure and arrival. Time fields contain
elapsed simulation minutes/seconds since the 08:00 shift start.

## Checks

```sh
./scripts/check.sh
```

This runs native `swift format lint --strict`, icon-script typechecking,
six Swift Testing tests, a release
build with compiler warnings treated as errors, and `plutil -lint`.

Tests cover every station pair and both branches, route continuity, signal
holds, occupied-block exclusion, switch locking, two-train delivery, destination
platform protection, pause, save round trips, invalid-save rejection, scenic
route selection, speed scaling and 2,400 simulation steps under changing controls.
No tests depend on network or UI state. Native UI interaction is tested separately
through the macOS app, including save/reload, relaunch and reset recovery.

## Model and deliberate limits

- The graph has three terminal stations, two switch locations and a forest loop.
  Trains move along the graph's sampled polylines at a constant 28 map units per
  simulation second. Rendered locomotives/coaches are decorative rigid consists;
  individual carriage wheel dynamics and acceleration are not simulated.
- **Block 01 is a conservative whole-junction reservation** including its exit
  approach. Only one train enters this conflict zone at a time. The reservation
  is released on arrival, preventing opposing routes and switch changes beneath
  a train. It deliberately favors safety and understandable dispatch over
  maximum throughput. Two trains can move on separate station approaches.
- Signals guard the final 18% of each inbound approach. A clear signal still
  requires the block, points alignment and destination approach/platform to be
  available. Rerouting via W1 is allowed before admission.
- W2 selects the eastern branch involved in the approach; east-to-east trips use
  the graph junction without modeling locomotive reversal or turnout geometry.
  This is a dispatch puzzle, not an engineering-grade railway simulator.
- A target platform occupied by another service stays blocked. Mutually blocked
  destinations may require Reset and choosing another itinerary; there is no
  automatic deadlock solver, arbitrary track editor or service cancellation.
- Simulation time advances only while running; pausing, closing the app or
  suspending the computer does not fast-forward it. A sudden forced kill may lose
  up to two seconds since the last autosave.
- The “1 : 240” compass caption is model-diorama styling, not a geospatial scale.

Every tracked file for this demo is contained in this directory.
