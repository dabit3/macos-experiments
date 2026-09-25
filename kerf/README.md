# Kerf

![Kerf screenshot](screenshots/kerf.jpg)

A native macOS fabrication sketchbook for precise laser-cut objects. A warm ivory
sheet, blue engineering vectors, amber selection dimensions and a charcoal
inspector put the material at the centre of the workspace. All geometry and files
stay local. SwiftUI supplies the desktop controls; AppKit renders the editable
canvas and procedural material previews.

## Requirements and launch

- macOS 14 or newer, Apple Silicon or Intel.
- Xcode with Swift 6 (developed and tested with Xcode 26.6 / Swift 6.3.3 on
  macOS 26.5.2, Apple Silicon). Select its command-line tools.
- No package dependencies, project generator, account or signing certificate.

From this directory:

```sh
./scripts/check.sh    # native formatter lint, warnings-as-errors build, logic tests
./scripts/build.sh    # release executable → dist/Kerf.app, generated icon, ad-hoc signature
./scripts/run.sh      # launch the macOS .app
```

The Swift package can also be opened directly in Xcode. `dist/Kerf.app` is a local
macOS application, not a notarized App Store release. Distributing to another Mac
may require allowing the application in Privacy & Security. Rebuilding from
source is the reproducible path. The build script uses only Apple's native tools.

## Start with a finished sheet

The first launch includes a 360 × 240 mm birch sheet containing an alpine coaster
with an engraved mountain motif, a utility panel with an inset and index path,
a blank coaster and a studio tile. The art is original vector geometry, fully
editable. The material selector offers birch plywood or frosted acrylic.
Material preview uses procedural local rendering and retains editable vectors.

## Controls

- **Select:** click a part or its row in the object list. Drag to move.
- **Resize:** drag the filled amber bottom-right handle. Other corner markers
  indicate the selection bounds. Circles keep their aspect ratio.
- **Rectangle / Circle tools:** drag on the sheet to create a shape. Tools return
  to Select after drawing. Circle diameter follows horizontal drag distance.
- **Polyline:** click vertices, then Return or double-click to finish. Escape
  cancels an unfinished shape. New paths default to the engraving layer.
- **Dimensions:** enter millimetres in X, Y, Width/Height or Diameter and press
  Return or leave the field. Invalid, non-finite and out-of-range values are
  rejected. Width/height limits are 0.1–2000 mm; sheets are 20–2000 mm.
- **Grid:** toggle 5 mm snapping. With snapping off, dragging rounds to 0.1 mm.
  Numeric entry always preserves the entered dimension.
- **Arrow keys:** with canvas focus, nudge 5 mm (1 mm without snapping).
  Shift-arrow nudges 10 mm.
- **Duplicate:** Command-D or inspector button. Copies are offset 12 mm so any
  cut overlap is immediately visible. Duplication affects the selected object.
- **Delete:** Delete with canvas focus, the Part menu, or inspector trash.
- **Find free position:** searches the sheet in 5 mm increments, with at least
  5 mm clearance from other cut parts; moves only the selected object. It reports
  failure without changing the design if no position fits.
- **Layers:** Cut or Engrave in the inspector. Engraving may intentionally overlay
  a cut shape.
- **View:** Draft/Material toggles rendering, ± changes zoom and the percentage
  button fits the sheet. Scroll/trackpad pans the sheet.
- **Undo / Redo:** Command-Z / Shift-Command-Z or bottom-left buttons. Geometry
  drags are one undo step. Restoring the sample and opening files are undoable.
- **Save / Open:** Command-S / Command-O and top-right native file dialogs.
- **SVG:** top-right Export SVG or Shift-Command-E.

## Persistence and export

Changes autosave atomically to
`~/Library/Application Support/Kerf/Autosave.kerf` and restore on relaunch.
Explicit Save creates an editable JSON `.kerf` document at the selected path.
Open validates the entire document before replacing the current design.
Corrupt autosave recovery loads the sample and reports the error.
Undo history is in-memory and bounded to 100 snapshots.

SVG export writes to the path selected in the native save dialog. It uses physical
`width` / `height` in **mm**, a matching millimetre `viewBox`, editable native
`rect`, `circle` and `polyline` elements, and separate `cut` / `engrave` groups.
Red strokes represent cut paths; blue strokes represent engraving paths.
Stroke width is 0.1 mm for vector visibility, not a machine power setting.

Export is blocked while cut overlaps or sheet-bound violations remain.
Preflight includes the enabled kerf compensation. Engraving outside the sheet is
also flagged. SVGs remain generic vectors: configure laser speed, power, focus
and cut order in the target fabrication software.

### Kerf model and boundaries

- All dimensions in the editor are nominal finished sizes.
- Optional **outside compensation** offsets rectangles outward by half the kerf
  and increases circle radius by half the kerf. Their centres stay unchanged.
- Example: a nominal 90 mm circle with 0.2 mm kerf exports radius 45.1 mm.
- Engraving and open polylines remain on their centreline.
- This V1 treats all closed cuts as exterior silhouettes. Interior holes,
  boolean paths, rounded rectangles, arbitrary polygon offsets, grouping,
  rotation and automatic whole-sheet nesting are not implemented.
- Circle/circle and rectangle/circle overlap checks use geometric distances.
  Rectangle intersections use bounds. Polylines conservatively use bounding
  boxes; this may flag empty space within an open path.
- “Find free position” is deterministic grid placement, not an optimized
  industrial nesting solver. Engravings are independent objects and are not
  moved automatically with a parent silhouette.
- The 3 mm material labels and plywood/acrylic appearances are visual presets,
  not mechanical simulation or a calibration claim.

## Verification

`./scripts/check.sh` runs Apple's `swift format lint --strict`, compiles with
warnings as errors, and executes Swift Testing cases for document round-tripping,
geometry validation, circle and rectangle collision math, kerf-aware bounds,
engraving exemptions, exact physical SVG coordinates/escaping, polyline hit
testing and history branching/limits.

Suggested native UI demo:

1. Resize the Alpine coaster from 86 to 90 mm; inspect the dimension callout.
2. Select Blank coaster, duplicate it, observe the overlap warning, then use
   Find free position and verify the warning clears.
3. Draw a rectangle and a multi-vertex engraving path; move and resize using
   the canvas and edit dimensions. Exercise Cut/Engrave and undo/delete.
4. Switch material preview and acrylic/birch presets.
5. Save a `.kerf`, make an edit, reopen it, and verify dimensions. Quit and
   relaunch to verify autosave.
6. Export SVG and parse it as XML; verify millimetre sheet units and circle/
   rectangle coordinates. Enable compensation and check the offset separately.

The final session artifacts include a native UI recording, uncropped screenshots,
a command/UI test report, an exported SVG and a zipped local macOS `.app`.
