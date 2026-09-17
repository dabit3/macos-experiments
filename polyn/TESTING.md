# Polyn validation

## Reproducible commands

From a clean clone:

```sh
cd polyn
npm ci
npm run lint
npm run typecheck
npm test
npm run build
npm audit
npm run preview
```

The preview is served on port 4173. No credentials or backend. For subdirectory verification, serve `dist` from any static host at a nested path; relative asset paths are emitted by Vite.

## Deterministic fixture and reset

The built-in `createProject()` fixture creates the same 15 objects and four cameras every time without randomness or external assets. File → New · Built-in loft → Open loft resets it and preserves the prior document in Undo. Browser storage key: `polyn.project.v1`. To clear all browser state, remove that key and reload. Reload retains document state, not undo history, selection, temporary playback or exposure.

## Executable test coverage

`src/model.test.ts` tests actual object geometry and state: independent default fixtures; immutable edits; clone isolation; add/delete; multistep undo/redo and redo invalidation; bounded history; JSON export/import including materials, cameras and keys; malformed, oversized and incompatible imports; duplicate IDs, invalid transforms, colors and bookmarks; animation interpolation, clamping and replacement; finite geometry bounds; full-height spiral stairs; detailed scene mesh count; Blender Z-up ↔ Three.js Y-up coordinate conversion; nonempty selection edges for rounded furniture and smooth primitives.

## Browser golden path

1. Open production preview at 1440×900. Confirm the complete cutaway loft, compact workspace chrome, selected Sienna sofa in Outliner and editable Properties. No loading/errors.
2. Click the lounge chair in the Outliner; confirm the orange geometry outline and matching Properties name. Set Location X to 4, Rotation Z to 15 and Scale X to 1.2. Values and real geometry must change.
3. Change the material to the green palette swatch and roughness to 0.35; confirm actual mesh color. Undo and redo and verify values return.
4. Use Add → Mesh · Cube. Rename to “Test plinth”. Use `G X 1 Enter`, `R Z 30 Enter`, `S 0.7 Enter`; inspect numeric fields, duplicate with Shift D, then Delete. Undo/redo delete and confirm Outliner counts.
5. Save with Ctrl S, reload, search “Test plinth” in Outliner, select it and verify saved position, rotation, scale, color and object count.
6. Insert a key at frame 1. Change frame to 120, change Location X, insert a second key, scrub to 60. Verify visible interpolation. Play/Pause changes and stops the frame.
7. Switch actual Solid → Wireframe → Material modes, change saved cameras, orbit and toggle the grid. Save a custom camera through View and verify it appears in the selector.
8. File → Export project. Inspect downloaded JSON for version 1, edited object, transforms, cameras and keyframes. Open/import it and verify scene replacement.
9. Render image, check the real scene in Render Result without selection/grid/transform handles, Save image and verify a nonempty valid PNG of actual canvas dimensions.
10. Check browser console/runtime errors, default and changed-state layouts at 1280×800, 1440×900 and 1920×1080. Restore default loft, material shading and overview camera for the finished screenshot.

## Results

2026-09-15: `npm ci`, lint, typecheck, all 23 Vitest tests, production build and `npm audit` passed. Audit reports zero vulnerabilities. The build reports one non-fatal 850 kB JavaScript chunk warning (Three.js and the editor are loaded together).

Production browser validation passed on runtime commit `38f2ddd047a6271caa90c6f905016efd6737c19f`. Final delivery documentation changes do not alter this tested runtime.

- Real viewport clicks and Outliner selection synchronize Properties and orange geometry edges. Rounded cube, sofa and chair outlines are visible.
- Numeric edits, typed G/R/S transforms, transform handles, material changes, duplicate/delete and undo/redo work. Saved edits survive reload.
- Transform keyframes interpolate at intermediate frames; playback advances and pauses. Material/Solid/Wireframe shading and the grid change actual viewport rendering.
- Orbit and pan select Custom view; camera bookmarks, saved custom views and Home reset update the camera label and framing.
- Exported JSON deep-matches the persisted project, including 16 objects, 5 cameras and animation keys. Reimport restores it; malformed JSON is rejected without replacing the document.
- PNG export produces a real 1591×835 image without editor overlays. Downloaded content and image dimensions were inspected.
- Default and edited layouts work at 1280×800, 1440×900 and 1920×1080. The final screenshot restores the built-in loft, Material mode and overview camera.
- No JavaScript exceptions or console errors occurred. Network inspection recorded an initial missing favicon request (HTTP 404). Three.js emitted a shadow-map deprecation warning and Chromium's software WebGL renderer emitted performance/readback warnings.

The browser run initially used an overly broad test selector that clicked Duplicate instead of Move. The extra object was removed and exact G/R/S controls and reload persistence were retested on the intended 16-object fixture. This was a test procedure correction, not an application failure.

The PR and session deliver the full PNG, annotated VP9 WebM and a detailed testing report. Earlier interrupted recordings are not final evidence.

## Side-by-side evidence viewer

The delivered offline bundle opens with `index.html`: full WebM on the left, timestamped recorded steps on the right. Play, pause, seek, restart and playback speed control the actual video. Selecting a step seeks to its original recording timestamp; highlighting and optional auto-scroll follow playback.

The **Full action log** tab preserves every original browser-harness action and UTC batch timestamp, including earlier runs. These batches do not have per-command recording timestamps and are intentionally shown separately from the synchronized recording annotations.

The viewer has no runtime dependencies or network requests. Keep the extracted bundle files together and open it in Chrome or Firefox. To rebuild from the original evidence files:

```sh
npm run test:evidence
node tools/build-evidence.mjs \
  /path/to/full-recording.webm \
  /path/to/recording-annotations.json \
  /path/to/ui-steps.jsonl \
  /path/to/TEST_REPORT.md \
  /path/to/poster.png \
  .devin/evidence-viewer
```

`source_time_ms` is used directly, never the accelerated recording's `edited_time_s`. The generator rejects non-WebM input and invalid recording timestamps, preserves original media and raw logs, and escapes embedded evidence data. Generated bundles and media remain untracked.

Viewer browser checks: verify playback and synchronized highlighting, click a later assertion and seek back to setup, change playback speed, pause/restart, expand the full action log, toggle follow mode, download the report and raw steps, and check the left/right layout at 1920×1080, 1440×900 and 1280×800.

## Source references and observed geometry

See README for explicit observed dimensions, palette and attribution:

- https://docs.blender.org/manual/en/4.2/interface/window_system/introduction.html
- https://docs.blender.org/manual/en/4.2/editors/3dview/introduction.html
- https://docs.blender.org/manual/en/4.2/_images/interface_window-system_introduction_default-startup.png

The clone-this reference/audit/convergence procedure is used within the explicitly requested browser V1 scope. Its full-native/parity gate is not a claim of this demo: a screenshot cannot establish all Blender behavior, and the source project geometry differs. No pixel-diff metrics are fabricated.

## Honest parity boundaries

- This is an independent browser V1. No literal pixel identity or native Blender feature parity is claimed. The accessible 4.2 manual reuses a screenshot labeled 3.2.0 Alpha.
- Object Mode only: no mesh vertex editing, sculpting, UVs, topology modifiers, geometry nodes, simulation, Cycles path tracing, native .blend import/export, animation video rendering or native workspaces. Unavailable controls are disabled and labeled.
- PNG export uses the live WebGL canvas at its current resolution and ACES filmic shading, not Cycles. Material editing recolors the primary material of a composite object; intentionally separate trim/upholstery accents retain their colors.
- Timeline stores whole-object position/Euler rotation/scale keys and linear interpolation only. Document changes return to editing the stored transform; scrub/play previews interpolated values. No curve editor, skeletal rigs or full animation editor.
- Gizmos and typed transforms are in a world-aligned basis. The orientation graphic is decorative and labeled; cameras and real OrbitControls perform navigation.
- Authentication, networking and collaboration are not applicable. Data is synthetic/local; storage failures are reported and JSON export remains available. Undo/redo is session-only.
- 200 editable objects, 250 frames, 30 saved cameras, 2 MB import limit. Geometry is detailed procedural mesh content, not external textures/models.
- Desktop UI is targeted at 1280×800 and above; below 1060 px it keeps a minimum-width desktop workspace instead of a separate mobile layout. Properties and Outliner scroll independently.
