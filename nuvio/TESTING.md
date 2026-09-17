# Nuvio — reproducible verification

## Clean installation and checks

```sh
cd nuvio
npm ci
npm run lint
npm run typecheck
npm test
npm run build
npm run preview -- --port 4173
```

Open the preview port in the browser. No accounts, API keys, backend or network
assets are required. Vite uses `base: './'`, allowing a static subdirectory install.
Node 22.12+ is required; implementation checks use Node 24.19 / npm 10.8.

## Deterministic fixture

Use **File → Reset demo** to restore Forest House. Reset is undoable.
To reset across sessions without retaining undo history, clear the localStorage
key `nuvio.project.v1` and reload. Vegetation is seeded with 311 and per-tree seeds.
Default time is 16:30, season Summer, weather Clear, haze 18%.

## Programmatic tests

`tests/model.test.ts` exercises:

- Valid furnished project fixture and three independent camera presets.
- Case-insensitive real library filtering and category constraints.
- Placement identities, repeated-placement offsets and typed asset geometry.
- Transform, material and visibility updates without mutating other objects.
- Multi-step undo/redo, branching history, no-ops and the bounded 60-state stack.
- JSON export/import round trips including precise coordinates and saved ambience.
- Malformed, duplicate, unsupported and oversized persistence inputs.
- Seed determinism/range and the sun's east-to-west coordinate trajectory.
- Flat project foundations and bounded raised terrain around the forest.

## Browser golden path and expected outcomes

Test the production preview with a fresh/reset fixture at 1440×900:

1. Inspect the initial scene: actual forest, glass pavilion, deck, interior furniture,
   pond reflection and boardwalk. The library, scene tree, ambience and media controls
   must all be visible. Orbit by dragging and zoom with the wheel. Restore the first
   media shot.
2. Search Library for `bench`. Expect one actual Timber bench. Click it.
   Expect new bench geometry, a selected scene row, bounding-box selection and
   object properties.
3. Rename the bench `Pond bench`. Set X=8, Y=0.3, Z=4, rotation=35, scale=1.2.
   Commit numeric edits with Enter or blur. Also type X=-2.5 and scale=0.5 to
   exercise intermediate negative/fractional input, then restore the above values.
   Apply Terracotta. Expect the inspector and rendered object to match.
4. Undo material, then redo it. Duplicate the bench, hide/show the copy and delete
   it. Undo delete. Expect actual scene and object counts to follow each action.
5. Choose Ambience. Change time, Autumn season, Mist weather and haze.
   Expect lighting, foliage and depth haze to visibly change. Range edits commit on
   pointer release, blur or a 200ms keyboard pause. Hold/repeat arrow keys rapidly;
   expect correct final values without React update-depth errors.
6. Drag to a new composition. Create image, rename it `Autumn retreat`.
   Switch to another media image, then return. Expect camera and saved ambience
   restored. Enter Present, use next/previous camera, exit with Escape.
7. Export PNG. Verify a nonempty PNG with the current render dimensions and actual
   scene content. Export project from File. Parse JSON and verify the edited bench,
   coordinates, material, new camera and saved ambience.
8. Reload. Expect the modified scene/objects/media to persist. Reset then reopen
   the exported project. Expect the edited scene recovered; invalid JSON should
   leave the current project untouched with a readable error.
9. Inspect default and changed-state layout at 1920×1080 and 1280×800.
   Critical controls should remain reachable; panels have independent scrolling.
   Inspect console/network for errors and missing assets.
10. Hide both side panels and the media dock, then restore them with footer controls.
    Repeat at all three desktop sizes. Expect Library, Scene and Properties footer
    buttons to remain visible when their panel is hidden.
11. Place rock, fern and lamp assets and apply Terracotta. Expect each asset's
    surface to change. Ordinary object edits must not regenerate saved thumbnails.
    Orbit and use a shot's refresh icon; expect updated camera, ambience and thumbnail.
12. Exercise empty Library/Scene searches and recovery. Import 150 objects/20 shots;
    expect further placement/camera creation disabled with a visible object-limit
    explanation. A 500001-byte project import must be rejected without mutation.

Capture the best full, uncropped scene PNG and a real annotated screen recording.
Final recording format must be VP8/VP9 **WebM**, never MP4.

## Results

Programmatic verification, September 15, 2026: clean install, lint (0 warnings/errors),
TypeScript, all 19 unit tests, production build and dependency audit (0 vulnerabilities)
passed. Production browser tests have verified real viewport selection, transforms,
materials, undo/redo, environment/media/presentation, actual PNG/JSON exports, reload
persistence and import boundaries. Import error recovery, visibility-driven thumbnails
and panel restoration passed at 1440×900, 1920×1080 and 1280×800.

Final executable revision `cc7c1cf12583ac6abae90e219ad72382a9a198ef` passed the
rapid-arrow range regression, range undo/redo, saved ambience restoration and a
continuous seven-step production golden path. No captured React exceptions or failed
network requests remained. Unchanged comprehensive workflows retain their earlier
revision evidence, explicitly identified in the report.

Software WebGL measured approximately 2.3 seconds median / 6 seconds maximum from
interaction to two animation frames, and approximately 22 seconds for thumbnails.
These are observed rendering/scheduling delays, not isolated event-handler timings.

- [Full test report and exact steps](https://app.devin.ai/attachments/41ef7988-cf5e-4161-b8a9-03ebdf4c25e1/nuvio-final-report.md)
- [Full workspace screenshot](https://app.devin.ai/attachments/3d4ea03f-eca5-4832-a50b-7abc5bec5760/final-nuvio-cc7c1cf.png)
- [Complete captioned VP9 WebM](https://app.devin.ai/attachments/bd761553-9f94-4589-ab9e-d3852876f09d/nuvio-golden-cc7c1cf.webm):
  1440×900, 388.416 seconds, 6,080,467 bytes; verified with ffprobe and decoded
  beginning/middle/end frames. A shortened recorder output was rejected; the final
  artifact uses a continuous direct X11 capture with source-timed annotations.

## Boundaries

- This is a usable browser V1 inspired by the documented Twinmotion 2025.1 workspace;
  no literal pixel parity or native-engine feature parity is claimed. Public reference
  access cannot provide a matched native fixture or interactive native behavior proof.
- Local scene objects have uniform scale, one yaw angle and numeric translation;
  there are no drag-axis transform gizmos, multiselect or mesh-edit operations.
- Reflective pond and fixed forest are part of the project fixture rather than
  individual selectable objects. User-placed vegetation and architecture are editable.
- Winter changes foliage tint, not snowfall accumulation; Mist changes depth fog,
  not particle precipitation. Foliage has no wind animation.
- Media thumbnails render saved camera and ambience when visible after initial load,
  shot creation or explicit refresh. Object edits retain the snapshot; reloading generates
  thumbnails from current project geometry. A camera click restores saved ambience.
- PNG exports the live viewport resolution, not an offline/path-traced render.
- Software WebGL (SwiftShader/llvmpipe) uses automatic Performance mode at 75% render
  resolution, lighter foliage, 256px reflection and 512px shadow maps; Standard mode
  uses the hardware renderer. Software orbit and scene edits can take seconds.
- Changes auto-save locally; undo history and current orbit position are session-only.
  Saved camera shots persist. Browser storage is per-origin and last write wins across
  tabs. Portable JSON export is the backup path.
- Limits: 150 objects, 20 images, 500 KB project file, 60 undo states.
- Desktop workspace minimum width 1024 px, minimum height 720 px. Optimized for
  1280×800, 1440×900 and 1920×1080; smaller screens scroll rather than becoming a mobile UI.
- Standard WebGL rendering only. Lumen, path tracing, volumetric clouds, commercial
  assets, CAD imports, cloud/VR/video and live native integration are outside scope.

## Reference sources

See README's measured reference audit.

- https://dev.epicgames.com/documentation/en-us/twinmotion/the-viewport-in-twinmotion
- https://d1iv7db44yhgxn.cloudfront.net/documentation/images/7af1097d-befb-4b1b-a1ac-e5a25636a62a/viewport-in-twinmotion.png
- https://www.twinmotion.com/en-US/news/twinmotion-2025-1-is-here
- https://design8.com/en/news/twinmotion-2025-1-is-available/
