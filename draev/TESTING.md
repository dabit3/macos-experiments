# Draev — verification and reference report

## Reproduce from a clean checkout

Requires Node 22.12+ (validated with Node 24) and npm. No backend, Python, credentials, API keys, license, or CDN assets.

```sh
cd draev
npm ci
npm run lint
npm run typecheck
npm test
npm run build
npm run preview
```

Production preview listens on port 4173. The app is static and uses `base: './'`; `dist/` can also be served below a subdirectory. Do not run the repository's unrelated Python setup for this app.

## Deterministic fixture and reset

The sample comes from `src/fixture.ts`, uses no random inputs and has stable IDs. Restore it using **Manage → Reset sample → Restore sample** (undoable). Alternatively remove localStorage key `draev.drawing.v1` and reload. Undo/redo history is session-local, while geometry and layers auto-save to localStorage. The viewport and draft-in-progress intentionally reset on reload. Export a Project JSON before clearing browser data.

Use the default `A-SKETCH` layer for test geometry. Model coordinates are millimeters; X is right and Y is up. The SVG drawing flips Y only at rendering/export. Initial grid snap spacing is 100 mm. Relative input is `@dx,dy`. Invalid project imports must not replace the current drawing.

## Executable programmatic tests

`npm test` runs `src/model.test.ts` with Vitest. Coverage includes:

- Absolute, relative, negative and invalid coordinates; metric grid snap.
- LINE/RECTANGLE/CIRCLE construction, reversed rectangle corners, zero/invalid geometry.
- Movement of every fixture entity type; accurate bounds, fit and cursor-anchored zoom.
- Layer and geometry undo/redo, redo-branch invalidation and the 40-edit limit.
- Deterministic fixture, unique IDs, all six geometry types, complete JSON round-trip.
- Invalid schema, duplicated IDs, unknown layers, bad colors and malformed geometry.
- Escaped SVG text, visible-layer filtering and coordinate inversion.
- ASCII DXF header, units, layer visibility, closed polylines, arcs and text.

## Programmatic computer-use recording

`npm run test:computer` executes native mouse/keyboard inputs against foreground
Chrome and records the desktop. Read-only CDP observations assert the visible
properties and persisted state; independent parsers check real downloaded files.
See [setup and reproduction instructions](scripts/COMPUTER-USE.md) for the
Linux/X11, fullscreen/CDP, capture and compositor prerequisites. These tools are
needed only for this optional desktop test harness, not the app.

The 2026-09-15 run passed all seven stages: sample reset, exact rectangle,
property edits and undo/redo, MOVE/circle, planting visibility, SVG/DXF/JSON
exports and persisted reload. It tested production app revision `09baeb472`
at 1920×1080; no runtime exceptions, console errors or request-loading failures
were observed. Earlier resize, import and snapping coverage was not repeated.

The resulting 78.084-second VP9 WebM places every full app frame on the **left**
and the programmatic list of steps on the **right**, synchronized to timestamped
test and assertion events. The current step and actual pass/fail results update
as execution progresses. The step pane is disclosed postprocessed compositing.
No footage is cropped, cut or accelerated; no MP4 is delivered.
The step-list revision reuses the preserved real run and its event log; it does
not represent a new browser run.

## Browser golden path

1. At 1440×900, restore the sample. Confirm the complete residence and drafting chrome are visible: ribbon groups, document tab, UCS, view cube, command line, Properties and Layer Properties.
2. In the command line enter `RECTANGLE 12000,1900 16000,2900`. Confirm a blue sketch rectangle appears in the front terrace and Properties shows Width 4000, Height 1000.
3. Change **Width** to `4500` and **Position Y** to `2000`. Confirm the visible geometry changes. Undo then redo; inspect geometry values.
4. Click a blue grip and drag to move the rectangle with grid snap, or enter `MOVE 500,0`. Verify exact X displacement in Properties.
5. Enter `LINE 12000,1500 16000,1500`, then Enter to end. Enter `CIRCLE 18500,2500 600`. Verify their type and coordinates/radius in Properties. Also exercise a two-click mouse rectangle and cancel with Escape.
6. Hide `L-PLANT`, verify planting disappears, show it again. Change `A-SKETCH` color, then lock that layer and verify objects on it cannot be edited; unlock it.
7. Wheel zoom around the pool and pan with the navigation Pan tool. Use **Zoom extents** or the TOP cube to recover the complete drawing. Open **Layout1 · A-101**, confirm paper presentation, then return to Model.
8. Export SVG, DXF and Project JSON using **Output**. Inspect file contents: sketch geometry must be present at edited coordinates; SVG includes only visible layers; DXF includes the layer table and metric units; JSON includes full geometry and layer state.
9. Reload. Confirm geometry, colors and visibility persisted. Import the exported Project JSON and confirm the same geometry. Attempt a malformed JSON project and confirm current geometry remains.
10. At 1920×1080 and 1280×800, inspect default and changed-state layouts. Primary draft, command, layer, property and export controls must remain reachable. Inspect console and network for runtime errors.

The production browser run used this sequence; detailed performed steps, exported-file assertions and captures are included in the attached test report.

## Reference identity, source URLs and observations

The coherent visual reference is **Autodesk's official “Tour the AutoCAD UI” video**, embedded in the AutoCAD 2025 help. The video itself identifies **AutoCAD 2024**, so this is a 2024 desktop chrome reproduction, not a claim that it depicts native 2025 internals. Frames at 120 s and 220 s were inspected directly, together with the official Basics images.

- https://help.autodesk.com/cloudhelp/2025/ENU/AutoCAD-WhatsNew/files/GUID-B7040851-266C-48CB-9682-654F3A6B8086.htm
- https://help.autodesk.com/videos/84a711e0-a331-11ed-a98a-599257d1f9b8/video.webm
- https://help.autodesk.com/cloudhelp/2025/ENU/AutoCAD-GettingStarted/files/GUID-5B6347C1-B458-4336-AB2A-C16AF161B755.htm

Observed at the 1280×720 source frame: approximately 25 px title/quick-access band, 23 px tabs, 76 px ribbon including panel captions, 24 px document tabs; model space starts near Y=149. The bottom layout/status strip is about 26 px high. Large Draw icons are about 28 px; small Modify icons 14–16 px. Ribbon panels use square geometry, fine vertical separators, 10–12 px sans-serif labels and slate gray surfaces. Home groups appear in order Draw, Modify, Annotation, Layers, Block, Properties, Groups, Utilities, Clipboard, View. The active document tab is slanted. The model space is dark charcoal; the cube sits upper right, UCS lower left and command window near the bottom. Paper layouts use a gray surround and white sheet. The sample uses a docked command history instead of the source video's floating single-line window.

Draev adapts these proportions to a 29 px title, 27 px tab row, 100 px ribbon, 30 px document row, 75 px command region and 29 px bottom strip, preserving desktop density while keeping text and controls usable at the requested resolutions. The right palette is 245–285 px wide. The courtyard geometry is original synthetic work; Autodesk screenshots/video are reference evidence only and are not bundled in the running app. All icons are bundled Lucide vectors (ISC licensed); the D mark is original.

## Scope and parity boundaries

- A usable browser drafting V1, with original architectural vector geometry. No native AutoCAD license or executable was available. The inaccessible native application was not exercised; no native feature parity or zero-pixel-difference claim is made. The clone-this source/audit/convergence process was applied within the explicitly requested V1 scope; strict literal parity gates remain inapplicable/unverified.
- Supported editable primitives: line, rectangle, circle, arc, text, polyline. New creation tools: line, rectangle, circle and single-line text. Existing arc/polyline objects support translation, layer edits and deletion; arbitrary vertex/arc-angle editing is not exposed.
- Visible disabled controls (Arc creation, Polyline creation, Rotate, Mirror, Scale, Parametric, Collaborate, Express Tools) are explicitly outside V1. No fake result or timer backs these controls.
- No DWG import/export, ACIS solids, 3D, BIM, rendering engine, xrefs, blocks, plotting devices, parametric constraints, multiview 3D, dimensions with associative constraints, account login or collaboration.
- DXF is ASCII AC1015-style geometry with layer color/visibility, LINE, LWPOLYLINE, CIRCLE, ARC and TEXT. Hatch fills export as rectangle boundaries in DXF; SVG retains hatching. No claim of full DWG fidelity or external CAD round-trip certification.
- A-101 is a paper presentation of the same live drawing, not an independently scaled plot/viewport engine. The `1:100` labels identify the conceptual architectural sheet scale; the browser zoom is arbitrary.
- LocalStorage is the only automatic persistence. Storage failure is surfaced with an export-backup prompt. Project files are versioned/validated and limited to 6 MB, 10,000 entities and 100 layers.
- One selected object at a time. Grip drag translates an object; it does not stretch individual vertices. Undo/redo keeps 40 drawing revisions and resets after browser reload.
- Invalid numeric geometry inputs revert to their last valid value. This prevents zero/negative dimensions, but there is no inline explanation.
- Desktop first: tested target widths are 1280, 1440 and 1920. Below 1000 px the workspace maintains a desktop minimum width; no mobile CAD redesign is claimed.

## Results

2026-09-15, Node 24.19.0, npm 10.8.3:

- Clean `npm ci`: passed.
- `npm run lint`: passed, 0 warnings / 0 errors.
- `npm run typecheck`: passed.
- `npm test`: 13 tests passed, 1 test file.
- `npm run build`: passed; Vite 7.3.6 static production bundle.
- `npm audit`: 0 vulnerabilities.

Production browser testing passed: the deterministic 960-entity/11-layer sample, exact rectangle Width4500/Y2000 edits and MOVE to X12500, undo/redo, typed LINE/CIRCLE, mouse geometry, 100mm grid snap, horizontal Ortho, isolated endpoint object snap, layer filtering/visibility/color/lock, wheel zoom/pan/extents, A-101, Help, text insertion and palettes.

Actual exported files were inspected: SVG escaped text and visible-layer filtering, DXF metric units/geometry/layers, and JSON geometry/state. Exported JSON matched reloaded, imported and malformed-import-rejected state. Invalid input retained the previous geometry. Default and edited views were inspected at 1440×900, 1920×1080 and 1280×800. No observed runtime errors; console was empty and current assets returned HTTP 200. A complete historical HTTP-status archive was not retained.

The first run identified a resize issue: an already fitted view could clip bottom drawing labels after moving to a wider viewport. The viewport now recomputes extents on resize while fitted; manual pan/zoom remains manual until TOP/extents is used. The focused browser regression on `afd46513` passed the 1440→1920→1280→1440 sequence without TOP, palette hide/show, manual zoom/pan retention and TOP recovery. The 960-entity drawing remained unchanged; final console was empty. The original geometry/export/import run was on `ad411498`; unchanged flows were not repeated in the focused run. Reset/import fitted transitions were not separately retested.

Evidence: full uncropped PNGs, a 117.875-second annotated VP9 WebM golden path, a 23.167-second supplemental exact-snap WebM and a 44.625-second resize regression. The delivery recording combines these in sequence, preserving each full frame. Recording-tool input/coordinate misfires required retries, which are disclosed in the attached report. No MP4 is delivered.
