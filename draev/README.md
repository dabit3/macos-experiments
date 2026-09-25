# Draev

![Draev screenshot](screenshots/draev.jpg)

A local, editable architectural drafting workspace inspired by the AutoCAD dark desktop interface. Opens on a procedurally drawn courtyard residence with walls, glazing, doors, furniture, paving, planting, dimensions and room schedules. No server, credentials, remote assets or commercial engine required.

## Start

Node 22.12+ or 24 recommended.

```sh
cd draev
npm ci
npm run dev
```

`npm run typecheck`, `npm run lint`, `npm test`, and `npm run build` run all quality checks. `npm run preview` serves the production build on port 4173. Vite uses `base: './'`.

## Draft

Select an entity to edit its geometry and layer in Properties. LINE, RECTANGLE and CIRCLE work with mouse clicks or coordinates in the command line. Coordinates are millimeters, X right / Y up. For example:

```text
LINE 1000,1000 5000,1000
RECTANGLE 1000,2000 4000,4000
CIRCLE 8000,8000 750
MOVE 500,0
```

Commands can also be entered one prompt at a time. Relative points use `@dx,dy`. Enter ends a continuous LINE. Escape cancels. Wheel zooms at the cursor; middle-button drag or the Pan tool pans. F3 toggles endpoint/center object snapping; F7 grid; F8 ortho; F9 100 mm grid snap. Ctrl/Cmd+Z undoes, Ctrl/Cmd+Y redoes. Delete removes the selection. Ctrl/Cmd+S saves locally.

The project auto-saves to localStorage. Download a project JSON for a portable backup, SVG for vector presentation, or ASCII DXF for supported drafting entities. The A-101 layout is an editable paper preview of the same model. It does not provide native DWG compatibility.

See [TESTING.md](TESTING.md) for reproducible tests, source observations, and exact V1 boundaries.
