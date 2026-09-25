# Trailhead

![Trailhead screenshot](screenshots/trailhead.jpg)

A native iPhone field guide for the day you want to spend outside. Forest-green typography, limestone paper, original vector contour artwork and burnt-orange trails make a compact, offline expedition planner.

**These are illustrative trail studies, not real hiking directions.** Coordinates and elevations are authored numeric fixtures located near three broad geographic regions; they are not surveyed routes. Decorative contours, water features and labels are not derived from elevation data. Never use this app or its exports for navigation.

## Prerequisites

- Native macOS with Xcode 26 or newer, selected with `xcode-select`.
- An installed iOS Simulator runtime and an available **iPhone** Simulator.
- Swift 6, `swift-format`, `simctl`, and `xcodebuild` come with Xcode.
- `rg` (ripgrep) is used only by the optional Simulator launch helper.
- No package manager, remote API, credentials, signing account or project generator.

Developed with macOS 26.5.2, Xcode 26.6 (17F113), and iOS 26.5. Deployment target: iOS 17+. The checked-in project opens directly in Xcode. This V1 supports portrait iPhone layouts; it does not claim a tablet layout.

## Build, check and run

From this directory:

```sh
./scripts/check.sh
./scripts/build.sh
xcrun simctl list devices available
./scripts/run.sh YOUR_IPHONE_SIMULATOR_UUID
```

`build.sh` produces `build/Build/Products/Debug-iphonesimulator/Trailhead.app`. This is an unsigned **Simulator-only** app, not an installable physical-iPhone or App Store release. Alternatively select the Trailhead scheme and an iPhone Simulator in Xcode, then Run.

`check.sh` runs strict Apple `swift-format` lint, plist/project syntax checks, and a dependency-free Swift model test executable with Swift 6 and warnings as errors. The Xcode project also enables complete concurrency checking and treats Swift warnings as errors. To reformat:

```sh
xcrun swift-format format --in-place --recursive Trailhead Tests scripts
```

## Demo and controls

1. Open **Routes** and choose Granite Loop, Juniper Ridge or Mirror Lake.
2. Drag the map to pan. Pinch or use **+ / −** to zoom between 1× and 3×. The scope button recenters and resets zoom.
3. Drag the elevation silhouette or its slider. The selected distance and interpolated elevation update alongside the orange map marker.
4. Tap **Add stop**, name the moment, then add it. Stops are sorted by route distance. Tap a stop to jump to it; its × removes it.
5. Open **Gear**, tap rows to pack/unpack, add your own items, or remove items with −.
6. The pencil beside the route title renames the expedition. The trip name appears above the save button and in the saved journal/PDF.
7. **Save expedition** snapshots the current route’s trip. Saving the same draft updates that snapshot. Open **Saved**, then tap a trip to restore its saved checklist and stops.
8. The undo arrow restores the previous mutation (one level, in this running session). The reset arrow asks for confirmation before replacing the draft with a fresh plan; saved trips remain available.
9. The export button writes a real multi-page itinerary PDF and opens a native PDFKit preview. Scroll pages, tap **Share itinerary PDF** for the system share sheet, or **Done** to return.
10. Force-quit/relaunch: the selected route, drafts and saved expeditions persist. Map camera, scrub position, active tab and undo history are intentionally transient.

All edits to drafts are saved automatically; the explicit save action creates a named journal snapshot. Creating a fresh draft via reset allows another saved expedition for the same route. The footer distinguishes the current saved snapshot from an edited draft.

## Sample content and calculations

Fixtures are bundled in `Trailhead/TrailModel.swift`:

- **Granite Loop / High Sierra Study:** pine forest, granite basin, a climb and descent.
- **Juniper Ridge / Red Rock Study:** more ascent and longer switchbacks.
- **Mirror Lake / Alpine Study:** a gentler, shorter loop.

Each fixture contains latitude, longitude and elevation for every vertex, with an explicitly closed loop. Initial trip content includes a trailhead waypoint and six editable packing essentials.

The bundled icon is original AppKit vector artwork. Regenerate its asset catalog with `xcrun swift scripts/generate-icon.swift` on macOS; normal builds use the checked-in asset and do not run a generator.

Distances use the haversine formula with a 6,371 km spherical Earth radius. Ascent sums positive vertex elevation differences. Scrubbing interpolates linearly within the segment containing the selected cumulative distance. Moving time estimates **distance / 4 km/h + ascent / 600 m/h**. It excludes breaks, terrain, weather, altitude effects and descent difficulty.

The map projects longitude using the region’s middle latitude so route proportions remain coherent. Contours sample a hand-composed synthetic height field with marching triangles, independent from the route’s elevation profile. They are nonintersecting vector artwork, not real elevation data. No location permission or live position is requested.

## Storage and exports

- App sandbox `Documents/trailhead-trips.json`: versioned, atomically written trip archive.
- `Documents/Itineraries/Trailhead-<route>-<trip-id>.pdf`: real itinerary exports, replaced when exporting the same trip again.
- iOS Files → On My iPhone → Trailhead exposes documents via native file sharing.
- Each PDF contains route artwork, distance/ascent/time, sorted stops with coordinates/elevation, packing state and the modeling caveats. Long content paginates.
- If an unreadable/unsupported archive is encountered, the app reports it and tries to retain a timestamped recovery copy before starting a new journal.

Find the Simulator sandbox without hardcoding its location:

```sh
xcrun simctl get_app_container YOUR_IPHONE_SIMULATOR_UUID com.trailhead.fieldguide data
```

## Verification

The model executable covers reference geodesic distance, symmetry/zero distance, ascent vs. descent, moving-time math, cumulative-distance interpolation and clamping, three valid loop fixtures, waypoint ordering/input validation, gear validation, save deduplication, file roundtrips and rejection of corrupt/unknown-route archives.

UI acceptance: choose routes, pan/zoom/recenter, scrub to move marker, reject an empty stop, add/delete/undo a stop, toggle/add gear, save, change draft and reopen the snapshot, relaunch to verify disk persistence, reset/cancel or undo, and export/share a real PDF. UI validation must be performed through native Simulator input and screenshot inspection; shell tests alone are insufficient.

## V1 boundaries

Offline, single-device planner only. No GPS navigation, map tiles, real trail conditions, weather, elevation service, cloud sync, routing engine, GPX import, physical hardware or Pencil dependency. No permission prompts are necessary. VoiceOver labels and native slider semantics are supplied, but a complete assistive-technology certification is outside this demo.
