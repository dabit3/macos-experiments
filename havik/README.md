# Havik

![Havik screenshot](screenshots/havik.jpg)

A locally editable residential-design application inspired by **Chief Architect Premier X16**. Opens to the furnished **Cedar Point Lake House**: a 260 m², seven-room residence with a lakeside deck, landscaping, dimensioned vector plan, and a linked WebGL model.

## Run

Node.js 22.12+ or 24 is supported. No backend, credentials, commercial license, external assets, or Python is required.

```sh
cd havik
npm ci
npm run dev
```

For production: `npm run build && npm run preview -- --port 4173`. Vite's `base: './'` supports static hosting inside a subdirectory. Do not publicly deploy without approval.

## Workflows

- Switch between Floor Plan, Dollhouse Overview and Lakeside Camera with document tabs or keys **1 / 2 / 3**.
- Select rooms, walls, doors, windows or furniture. Edit their specification and **Apply changes**.
- Place any of the eight library symbols by selecting it and clicking in the model or plan. Search and filter the actual local catalog. Drag furniture in plan view.
- Draw orthogonal partition walls with two clicks; place doors/windows on available wall segments. Opening constraints reject overlaps and out-of-bounds positions.
- Change materials, ceiling heights, wall thickness/heights, opening dimensions, furniture coordinates/dimensions/rotation.
- Undo/redo up to 50 edits, save automatically to local storage, export/import a validated Havik JSON project.
- Toggle roof, landscaping, floor and plan annotation visibility. Orbit, pan and zoom the real Three.js model.
- Export an actual dimensioned SVG plan or PNG of the current camera/plan; exports contain editable geometry or rendered pixels, rather than a bundled screenshot.

## Reference and attribution

The coherent visual reference is the **Chief Architect Premier X16 Reference Manual**, particularly printed pages **12–13** (annotated application workspace) and **979–980** (Library Browser).

- https://cloud.chiefarchitect.com/1/pdf/documentation/chief-architect-x16-reference-manual.pdf
- https://cloud.chiefarchitect.com/1/pdf/documentation/chief-architect-x16-tutorial-guide.pdf
- https://www.chiefarchitect.com/support/article/KB-00811/customizing-toolbars.html

Observed in the annotated X16 screenshot: light traditional menu bars, two densely packed icon rows, document tabs immediately above the workspace, a narrow left view-tool strip, a docked right Library Browser with search/filter/tree/results/preview sections, and bottom contextual/status/coordinate strips. Small icons use blue/ochre/red/green accents, squared selection outlines, and compact sans-serif labels.

The public manual's embedded screenshot is about 640 × 316 native pixels, so its printed layout is unsuitable for honest pixel-identity assertions. The inspected 4× PDF crop was 1480 × 708 px; within it the app image starts near x=173 and ends near x=1419. Two tool rows occupy approximately y=97–160, document tabs y=160–189, the view-tool rail x=176–220, and the Library Browser starts near x=900. Havik scales this hierarchy for browser usability: 37 px title / 25 px menu / 40+39 px toolbars / 33 px tabs / 39 px left rail / 290 px right dock at 1440 px. At 1920 px the dock is 326 px; at 1280 px it is 266 px. Small-screen minimum width is 1000 px; this is a desktop demo.

Havik intentionally uses a restrained sage/ivory interpretation and new branding, original procedural furniture and scene geometry, and Lucide icons (ISC). No proprietary application code, catalog assets, photos, fonts or native `.plan` files are copied. Chief Architect is a trademark of its respective owner; Havik is an independent demonstration, not affiliated with or endorsed by Chief Architect.

The `clone-this` skill's reference/inventory/convergence approach was followed within the explicitly requested browser V1 scope. Native reference execution and matched pixel comparisons were inaccessible, so **full native parity and literal pixel parity are not claimed**. Untracked reference/audit evidence stays inside `havik/.devin/clone-this/havik/`.

See [TESTING.md](TESTING.md) for executable checks, golden-path steps and limitations.
