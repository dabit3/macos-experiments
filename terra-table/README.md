# Terra Table

![Terra Table screenshot](screenshots/terra-table.jpg)

A native, landscape-first iPad sculpting studio. Shape moss-covered islands, carve passages,
soften ridges and raise turquoise water around a live 3D diorama. SwiftUI provides the
workspace; SceneKit renders an actual editable 81 × 81 heightfield, with calculated normals,
height/slope colors, shadows and contour shading. All sample artwork is generated locally
from the same deterministic terrain engine. No network, accounts or third-party packages.

## Prerequisites

- Native macOS with full Xcode 26.6 (verified with Swift 6.3.3).
- An installed iPad Simulator runtime; tested runtime: iOS 26.5.
- Deployment minimum: iPadOS 17. This project targets iPad only and supports both landscape
  orientations. No Pencil, camera, physical device, paid developer account or signing needed
  for the Simulator build.

## Build and run

From this directory:

```sh
./Scripts/build.sh
xcrun simctl list devices available
./Scripts/run.sh <your-iPad-Simulator-UDID>
```

Or open `TerraTable.xcodeproj`, choose the TerraTable scheme and an iPad Simulator, and Run.
The checked-in project needs no generator. Build output:
`build/Build/Products/Release-iphonesimulator/TerraTable.app`.
Any supplied app zip is **Simulator-only**, not an installable iPhone/iPad or App Store release.

## Controls and complete demo

1. The bundled **Alpine island** opens ready to edit. **Caldera** and **Archipelago** are other
   deterministic starting points. Loading a preset is undoable.
2. Select **Raise** and drag directly on land or underwater terrain. Tap for a small dab.
   Set **Radius** (0.35–2.5 scene units) and **Strength** (10–100%) to control the brush.
3. Select **Carve**, drag across a ridge to make a valley, then use **Smooth** to soften it.
4. Move **Waterline** to submerge low ground. The readouts show dry-area percentage and summit.
5. Select **Orbit** and drag horizontally to rotate or vertically to tilt. Pinch or use + / −
   for zoom. The viewfinder button restores the studio camera.
6. Switch between **Natural** and **Contours**. Contours use 50 illustrative metre intervals.
7. **Undo** / **Redo** restore whole strokes, water adjustments, presets and reopened snapshots.
   Up to 30 transactions are retained in memory. Starting a new edit clears redo history.
8. **Save** (also Command-S) stores a snapshot. **My landscapes** reopens any saved snapshot.
9. **Export** creates a real OBJ triangle mesh or a PNG from the current rendered scene.
   **Share or Save to Files** opens the native share workflow.
10. Terminate and relaunch: the current terrain and waterline restore automatically.

The field guide in the sidebar also documents these controls. Brush selection and viewport
are session preferences; terrain, waterline and saved snapshots survive relaunch.

## Persistence and exports

The app's Documents folder contains:

- `Current.terra`: atomically saved JSON after each stroke and every water value change.
- `Library.json`: saved snapshots with UUIDs and timestamps.
- `Exports/TerraTable.obj`: last exported terrain surface, 6,561 vertices / 12,800 triangles.
- `Exports/TerraTable.png`: last exported view, without the surrounding controls.

The folder appears under **On My iPad → Terra Table** in Files. Each format overwrites its
previous export; share/copy it to keep more versions. For Simulator inspection:

```sh
DATA="$(xcrun simctl get_app_container <UDID> ai.devin.terratable data)"
ls "$DATA/Documents"
```

Saved JSON is validated before use. Invalid files show a recoverable alert and are not
deleted on read failure. Undo history is not persisted. Presets and reopened snapshots
replace the active terrain but remain undoable.

## Checks

```sh
./Scripts/check.sh
./Scripts/build.sh
```

`check.sh` uses the formatter bundled with Xcode as a strict native lint check, validates
the property lists, and runs the terrain and studio-model Swift Testing suites. They check deterministic
presets, brush support and clamping, smoothing, invalid inputs, undo/redo branching and
capacity, serialization, mesh topology, monotonic inundation, and current/snapshot persistence
under differing slider callback orders. The native app build also
typechecks all SwiftUI, UIKit and SceneKit integration.

To apply formatting intentionally:

```sh
xcrun swift-format format --in-place --recursive App Sources Tests Package.swift
```

UI acceptance requires native computer input in an iPad Simulator: sculpt, carve, smooth,
flood, orbit, zoom, toggle contours, undo/redo, save/reopen, both exports, and relaunch.
Recordings/screenshots and an executed test report are delivered as session attachments,
not committed source assets.

## Modeling limitations

- A bounded heightfield cannot form caves, overhangs or vertical walls. Heights are clamped.
- Water is a horizontal plane, not a fluid simulation. Every basin below the level fills,
  including disconnected basins. There is no erosion or drainage solver.
- Metres in the UI are illustrative units (`height × 1000`), while mesh vertical coordinates
  use `height × 3` in a 10 × 10 studio world. This vertical exaggeration is intentional.
- OBJ contains the terrain surface only; no water, presentation plinth, colors or materials.
  It is an open surface, not a watertight manufacturing solid.
- Sculpting affects samples along the pointer path with quadratic falloff. Repeated strokes
  build up terrain; this is not a pressure-sensitive or physically timed brush.
- SceneKit is used from the iPadOS SDK and is deprecated in newer Apple SDKs; it remains
  functional for this bounded offline demo.
