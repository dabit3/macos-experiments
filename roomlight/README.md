# Roomlight

![Roomlight screenshot](screenshots/roomlight.jpg)

A native, landscape-first iPad interior studio: an architectural plan beside a softly lit, procedural miniature. Arrange a room, explore oak/walnut/limestone and chalk/clay/sage, and take away a real PDF.

## Prerequisites

- macOS with Xcode 26.6 (verified), Command Line Tools selected with `xcode-select`.
- An installed iOS Simulator runtime. Built against iOS 26.5; deployment target iPadOS 17.
- An **iPad** Simulator. No cloud account, signing certificate, camera, Apple Pencil or third-party dependencies.
- The committed Xcode project needs no generator. Swift Package Manager is used only for standalone model tests.

## Build and run

From this directory:

```sh
./scripts/build.sh
xcrun simctl list devices available
./scripts/run.sh <your-iPad-Simulator-UUID>
```

Or open `Roomlight.xcodeproj`, select the `Roomlight` scheme and an iPad Simulator, then Run.
The app supports both landscape orientations and is full-screen by design. Rotate the Simulator through **Device → Rotate Left/Right** if needed.

Simulator app output: `build/Build/Products/Debug-iphonesimulator/Roomlight.app`.
This is a Simulator-only build, not a signed installable iPad/App Store release.

## Use the studio

- **Furniture:** tap one of eight locally drawn pieces to place it at the centre. Drag it in the plan. Repeated pieces start offset.
- **Selection:** tap any piece; the inspector displays its nominal width/depth, quarter-turn rotation and centre coordinates. Rotate 90° or delete it.
- **Snap:** toggle between a 10 cm grid and free placement. Rotated footprints remain inside room bounds.
- **Materials:** change the floor and walls; both plan and SceneKit preview reflect the same room state.
- **Room size:** tap the dimensions under the title. Width and depth step by 0.5 m from 3–10 m. Shrinking a room constrains pieces inside it.
- **Plan / Studio / 3D:** inspect a large plan, synchronized side-by-side views, or a larger perspective.
- **Camera:** orbit left/right in 22.5° increments, zoom in/out, or reset to the composed view.
- **Undo:** undo edits, placements, moves, deletes, room switches and material changes (up to 60 ordinary edits; session history is not persisted). Command-Z also works.
- **Save:** name the current room. **Rooms** reopens saved rooms, restores the bundled study or starts an empty room. Starting empty requires confirmation and can be undone.
- **Export plan:** creates an A4 landscape PDF with the current plan, metre dimensions, material specification and counted furniture schedule. The preview supports native sharing.

### Sample content

“Sunday in Copenhagen” opens on first launch: linen Arc sofa, bouclé lounge chair, walnut Pebble table, fluted oak sideboard, woven rug, fiddle leaf plant and paper lantern. The eighth available piece is an oak Gather dining table. Every object is editable. Furniture, plan artwork, floor grain and room geometry are all generated locally with native drawing and SceneKit.

## Persistence and exports

Current edits and named rooms are stored atomically in the app's Documents directory as `roomlight-rooms.json`. Relaunch restores the active room. Named saves are snapshots and change only when Save is used again for that room.

`Roomlight-plan.pdf` is written to Documents on every export (the previous export is replaced). Use **Share PDF** in the preview to copy it elsewhere.

To retrieve the actual exported files from Simulator:

```sh
CONTAINER="$(xcrun simctl get_app_container <your-iPad-Simulator-UUID> com.roomlight.studio data)"
ls "$CONTAINER/Documents"
```

Invalid room geometry is sanitized on read. An unreadable JSON file displays an error and is preserved until the next edit writes the recovered room. Save/export failures display an alert.

## Checks

```sh
./scripts/check.sh
```

Runs the Xcode-bundled `swift-format lint --strict`, five meaningful Swift Testing model tests, and a native Simulator build/typecheck. To format intentionally edited Swift source:

```sh
xcrun swift-format format --in-place --recursive App Sources Tests scripts/generate-icon.swift Package.swift
```

Tests cover quarter-turn bounds, grid snapping, invalid dimensions/coordinates, all eight footprints in a minimum room, atomic JSON round-trip, named-save replacement and corrupt input. UI verification must additionally exercise native drag placement, materials, view switching, undo, save/reopen, relaunch and real PDF export.

An Xcode build phase draws the original architectural app icon with AppKit into the built app. Only the generator source is tracked; no prebuilt images or binaries are required.

## Modeling limits

- This is a concept layout tool, not CAD, construction documentation, a structural model or a lighting simulation.
- Room dimensions and furniture footprints are in metres; the plan is fitted to the display/PDF rather than printed at a guaranteed architectural scale.
- Rectangular rooms only, with fixed illustrative north-side glazing and an entry threshold. Openings are decorative and are not editable. The SceneKit room uses two 1.55 m cutaway walls so the contents stay visible.
- Furniture may overlap intentionally (for example, a table on a rug). There is no collision solver, walking-clearance validator or door-clearance enforcement.
- Shapes and materials are procedural approximations, not manufacturer assets. Daylight is a fixed artistic light rig. SceneKit is deprecated by Apple but remains available in the verified SDK.
- Room state and named saves persist locally; undo history and camera position reset on launch. There is no cloud synchronization, room import, texture upload or AR mode.
- The PDF plan is a high-resolution raster drawing inside a PDF with native text, not an editable vector CAD file.
