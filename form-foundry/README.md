# Form Foundry

![Form Foundry screenshot](screenshots/form-foundry.jpg)

A native, landscape-first iPad studio for small product forms. A porcelain workplane,
fine grid, shaded materials and a live dimensioned profile keep the object at the center.
Built with SwiftUI and SceneKit. Entirely offline; no packages, accounts or signing needed
for the Simulator build.

## Prerequisites

- Native macOS with Xcode 26.6 and its command-line tools selected.
- An installed iPad Simulator runtime (verified with iOS 26.5).
- Deployment target iPadOS 18.0. The app uses the full screen in either landscape orientation.
- All commands below run from `form-foundry`.

## Build and run

```sh
./Scripts/build.sh
xcrun simctl list devices available
./Scripts/run.sh YOUR_IPAD_SIMULATOR_UDID
```

Alternatively open `FormFoundry.xcodeproj`, select the FormFoundry scheme and an iPad
Simulator, then Run. No project generator is required. The build output is
`DerivedData/Build/Products/Debug-iphonesimulator/FormFoundry.app`.
This unsigned **Simulator-only** artifact is not an installable physical-iPad or App Store release.

## Controls and features

- **Rectangle / Ellipse:** immediately create an extruded profile. Equal ellipse axes make a circle.
- **Width / Depth / Extrude:** type a millimeter value and press Return, or use the `−` / `+`
  buttons. The profile drawing, shaded geometry, dimensions and summed volume update together.
- **Selection:** tap a solid on the canvas or choose its assembly row.
- **Position:** X and Z move on the workplane, Lift sets the bottom elevation, Rotate turns
  around the vertical Y axis in degrees. Position snapping rounds edited coordinates to 5 mm;
  dimensions remain freely editable. Turn snapping off for arbitrary coordinates.
- **Materials:** porcelain, graphite, vermilion, sage and sand. Duplicate and Delete act on selection.
- **Camera:** drag to orbit, pinch or `+` / `−` to zoom. Studio, Top, Front and Right restore
  orthographic views. The viewfinder resets the camera. Explicit view/zoom buttons restore
  the chosen view direction after a free orbit.
- **Undo / Redo:** up to 100 modeling states, including deletion, reset and opening projects.
  Hardware keyboard shortcuts: Command-Z / Shift-Command-Z. History is session-local.
- **New:** empty workplane or restore the bundled desk organizer, both undoable.
- **Projects:** named snapshots in the on-device library. Saving the same name replaces that
  snapshot. Project naming and open operations are undoable. Working changes auto-save atomically.
- **Export OBJ:** writes the real triangulated mesh, reports actual vertex/triangle counts and
  opens a native share action. All primitives are separate closed shells in one file.

The initial editable sample is a seven-part desk organizer: foundation, back wall, two
side walls, divider, front lip and a circular rest. It is built from exactly the same
primitives and meshes as user-created models. There are no placeholder renderings.

## Persistence and exports

Inside the app's Documents directory:

- `Workspace.json`: latest workspace, restored on launch.
- `Projects/*.json`: named snapshots, accessible through the Projects library.
- `Exports/FormFoundry.obj`: latest OBJ export, overwritten on each export.

Files exposes these in **On My iPad → Form Foundry**. Export also supports the system share
sheet. To copy artifacts from Simulator:

```sh
CONTAINER="$(xcrun simctl get_app_container YOUR_IPAD_SIMULATOR_UDID com.nativecollection.formfoundry data)"
ls "$CONTAINER/Documents"
```

## Verification

```sh
./Scripts/check.sh
./Scripts/build.sh
```

`check.sh` runs Apple's bundled `swift-format` in strict lint mode, validates plist/project
syntax, compiles the platform-independent model with warnings as errors and executes its
logic tests. No external lint installation is needed. To format source:

```sh
xcrun swift-format format --in-place --recursive Sources Tests
```

Tests verify primitive topology, edge manifoldness, outward triangle winding, mesh versus
analytic volumes, transformed vertices, dimension propagation, JSON round trips, invalid
dimensions/duplicate IDs/non-finite transforms, undo/redo branching and OBJ global indexing.

Native UI acceptance path: create and dimension multiple solids; orbit and switch views;
move/rotate/material/duplicate/delete; undo/redo; save and reopen a named project; relaunch
and verify restoration; reject an out-of-range dimension; export and inspect an actual OBJ.
The session delivers the executed test report and final annotated Simulator recording.

## Modeling limits

- Primitive modeling, **no Boolean unions, holes, fillets, constraints or freehand sketching**.
  Profiles are parameterized rectangles and ellipses, not arbitrary CAD sketches.
- A 64-sided polygon approximates each ellipse. The same triangles are rendered and exported.
- OBJ uses millimeters with Y up. Each solid is closed; intersecting parts remain intersecting
  shells, not a fused printable manifold. Use another mesh/CAD tool to union parts if needed.
- The displayed volume is the sum of analytic primitive volumes; overlaps are counted twice.
- Dimensions: 1–500 mm; X/Z: −500–500 mm; elevation: 0–500 mm; rotation: −360–360°.
  Maximum 100 solids per project. Ground-level geometry is allowed; negative elevation is not.
- Material colors are a studio visualization. This V1 exports geometry only, without MTL.
- Project library reads its own saved JSON files; there is no arbitrary external CAD importer.
- Persistence errors and invalid model values produce alerts. A corrupt workspace falls back
  to the bundled sample with an alert; saved project snapshots remain available.
