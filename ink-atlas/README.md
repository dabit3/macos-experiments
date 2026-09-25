# Ink Atlas

![Ink Atlas screenshot](screenshots/ink-atlas.jpg)

A native, landscape-first iPad sketchbook for thinking in space. Warm dotted paper,
quiet colors, editorial typography and a floating toolbox turn loose thoughts into
connected, editable diagrams. SwiftUI provides the interface; a touch-driven UIKit
canvas renders real vector objects and ink. Everything works offline.

## Requirements

- macOS with Xcode 26.6 and its command-line tools selected
- iOS 26.5 Simulator runtime and an iPad Simulator (tested on iPad Pro 13-inch M5)
- Apple Silicon for the supplied Simulator build; build from source for another host
- No package downloads, project generator, account, Pencil or signing credentials

The source has an iPadOS 18 deployment target. This demo is tested on iPadOS 26.5;
older OS versions and physical devices are not part of the validated release.

## Build and run

Run from this directory:

```sh
./scripts/build.sh
./scripts/run.sh
```

The run script selects an available iPad Pro 13-inch Simulator. To select a different
local iPad, find its UUID and pass it explicitly:

```sh
xcrun simctl list devices available
./scripts/run.sh YOUR_IPAD_UUID
```

The project is already generated: open `InkAtlas.xcodeproj` in Xcode and choose the
`InkAtlas` scheme and an iPad Simulator. The build output is
`build/Build/Products/Debug-iphonesimulator/InkAtlas.app`.

Use Simulator's **Device → Rotate Left/Right** if its window initially opens in
portrait. The app supports both landscape orientations and intentionally requires
a full-screen iPad workspace. In narrower windows the inspector collapses and
selection actions appear along the canvas edge.

The `.app` ZIP supplied with the demo is **Simulator-only**, unsigned for distribution,
and is not an installable physical-iPad or App Store release.

## The first page

**The quiet city** is a fully editable urban-design concept map, with four colored
cards, a central elliptical idea, bound arrows, editorial text and freehand ink.
**A weekend away** is a second, smaller travel-planning board. All content is created
locally from original editable fixtures in `Core/Board.swift`.

## Controls

| Tool / control | Behavior |
| --- | --- |
| Select | Tap an object, then drag to move it. Pull the larger lower-right handle to resize. |
| Draw | Press and drag with mouse, finger or Pencil. Palette and stroke-width controls apply to new strokes. |
| Card / Ellipse | Tap to place a default-sized shape, or drag to create a custom size. |
| Text | Tap the paper and edit the new text block in the native editor. |
| Connect | Tap a source object, then a destination; a directional arrow binds to both boundaries. Tap empty paper to cancel. |
| Hand | Drag to pan. Pinch, or use the bottom − / + controls to zoom. |
| Fit | Recenter and fit all objects, including objects moved outside the original page. |
| Edit words | Select an object, then use the inspector; double-tapping also opens the editor. |
| Palette | Changes a selected object's color, otherwise sets the drawing/creation color. |
| Delete / Disconnect | Remove an object and its arrows, or remove only its attached arrows. Undo restores them. |
| Undo / Redo | Restore drawing, geometry, connections, colors, words, title and clear-canvas changes. |
| Board title | Rename the current board. Blank titles are ignored. |
| All boards | Switch between saved boards or create an empty one. |
| Duplicate board | Create an independent copy of the current board. |
| Clear canvas | Confirmation required; Undo recovers the board. |
| Export | Generate PDF or SVG, then use the native Share control to send it to Files or another app. |

With the canvas focused, hardware keyboards support **⌘Z**, **⇧⌘Z** and **Delete**.
Mouse drawing in Simulator does not require simulated Pencil input.

## Persistence and recovery

The app atomically saves each finished edit, board switch and scene deactivation to
`Documents/InkAtlas-library.json` in its sandbox. It reopens the last selected board.
Selection, viewport and undo/redo history are transient; the drawing itself persists.
Each board has a separate in-session history capped at 80 snapshots.

Malformed libraries are copied to a timestamped recovery file before editable sample
boards are loaded. If that backup fails, saving is paused to protect the original and
the app explains how to export the current work. Save/export failures produce an alert.
Empty text cannot be committed; long fields are bounded and clipped to the object's
frame until the user enlarges it.

## Exports

- **PDF:** one content-sized page, native Core Graphics paths and text; includes all
  objects regardless of the current pan/zoom. It excludes selection handles and tools.
- **SVG:** editable vector shapes, ink polylines, bound-arrow geometry and escaped XML
  text. The view box includes negative coordinates and an outer paper margin.
- Both formats use actual board state, and are written atomically to
  `Documents/Exports/<board>-<timestamp>.<pdf|svg>`.
- File sharing is enabled: Files → On My iPad → Ink Atlas → Exports. The export sheet
  also offers the native share sheet.

For inspecting Simulator files:

```sh
xcrun simctl get_app_container YOUR_IPAD_UUID com.inkatlas.demo data
```

## Checks

```sh
./scripts/check.sh
./scripts/build.sh
```

`check.sh` runs the Xcode-bundled `swift-format` strict lint, validates both plist
files, and runs the Swift Package XCTest suite on native macOS. No third-party
linter is required. To format a deliberate source edit:

```sh
xcrun swift-format format --in-place --recursive App Core Tests Package.swift
```

The tests cover rectangular/elliptical edge anchors, connected-object movement and
resizing, deletion with undo, redo invalidation, stroke normalization, degenerate
strokes, duplicate/self connections, atomic library serialization and validation,
reverse-drag geometry, XML escaping and SVG content bounds.

### Native UI acceptance scenario

1. Inspect the sample board and open the guide.
2. Create a board, rename it, draw with the mouse, and add a card, ellipse and text.
3. Edit words and colors. Try an empty title and cancel the edit.
4. Connect the card to the ellipse; move and resize the connected object.
5. Delete and Undo/Redo; verify the drawing and bound arrows return correctly.
6. Pan, zoom and Fit. Switch boards and reopen the created board.
7. Terminate/relaunch the app and verify the last board and edits persist.
8. Generate both formats, open the share sheet, and validate exported files.
9. Leave the app on a composed, finished board and capture full-screen screenshots.

The session's separate test report and annotated recording document the actual
executed revision, results and artifacts; this checklist is not a claim of execution.

## Deliberate V1 boundaries

- Single selection; no multi-object grouping, layers, collaboration or cloud sync.
- Ink is a vector polyline with fixed stroke width. Pencil pressure, tilt, handwriting
  recognition and palm rejection are not modeled; finger/mouse use is first-class.
- Arrows are straight directional connections, attached to rectangle/ellipse
  boundaries. They do not route around intervening objects.
- Freehand strokes use rectangular selection bounds; selecting overlapping marks
  favors the most recently placed object.
- Text is editable and wraps within object bounds. Font metrics in third-party SVG
  viewers may differ from iPadOS; SVG wrapping uses a documented approximate
  character-width layout. PDF uses native typography.
- An entire board exports onto one page. This is not a paginated document editor.
- Board deletion and cloud backup are intentionally omitted. Use duplication, clear
  with undo, and exports to manage the local collection.
- VoiceOver labels describe the controls and canvas state; the spatial drawing
  surface does not yet expose per-object accessibility navigation.
