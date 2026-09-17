# Rhova

![Rhova screenshot](screenshots/rhova.jpg)

A local browser modeling application studying the **Rhino 8 for Windows** interface. Opens directly into Aurelian Museum: a sweeping, parameterized rib canopy over a patterned glass pavilion, with terraces, a reflecting pool, sculpture, furniture and planted site.

## Run

Requires Node.js 22.12+ (tested with Node 24.19.0).

```sh
cd rhova
npm ci
npm run dev
```

For a production build: `npm run build && npm run preview -- --port 4173`.
Vite uses `base: './'`; build assets resolve relative to the application directory.
No account, backend, API key, native license or remote asset service is required.

## Workflows

- Four interactive Three.js viewports; orbit/pan/zoom, per-view display mode, fit and maximize.
- Select scene geometry or the object list; Shift-click for multi-selection.
- Edit canopy rise/rib count, numeric position, Z rotation and uniform scale.
- Draw interpolated curves; edit control points by dragging in orthographic views or by coordinates.
- Extrude a curve vertically or loft two sampled curves into genuine mesh surfaces.
- Layer visibility, locking and color; local autosave; bounded undo/redo.
- Export/import validated Rhova JSON projects; export visible geometry as Wavefront OBJ.
- Command input supports `Curve`, `PointsOn`, `Extrude`, `Loft`, `Move x y z`, `Rotate degrees`, `Scale factor`, `Undo`, `Redo`, `Save`, `Export`, `4View`.

See [TESTING.md](TESTING.md) for reproducible tests, browser steps and boundaries.

## Reference and measured observations

Single coherent source version: Rhino 8 Windows public documentation, inspected September 15, 2026.

- [Rhino 8 window documentation](https://docs.mcneel.com/rhino/8/help/en-us/user_interface/rhino_window.htm)
- [Official annotated Rhino 8 window screenshot](https://docs.mcneel.com/rhino/8/help/en-us/image/localization/rhinowindow_win.png)
- [Viewport arrangements](https://docs.mcneel.com/rhino/8/help/en-us/commands/new_viewport_arrangements.htm)
- [Loft command documentation](https://docs.mcneel.com/rhino/8/help/en-us/commands/loft.htm)

The source PNG is 1252 × 866 including annotations and outer whitespace. Its application rectangle spans approximately x=70–1180, y=56–797. Observed toolbar/viewport geometry: title at y=56–87, menu at y=88–109, command history and prompt at y=110–168, horizontal container at y=169–229; left tools x=72–199, viewport region x=200–952, right properties x=953–1178. The source has 2×2 Top/Perspective/Front/Right panes; grey backgrounds, tight square edges, viewport-name dropdowns at upper left, blue active title, stacked right property rows, bottom view tabs and object-snap/status controls. Typeface visually resembles Windows Segoe UI/Tahoma; toolbar icons are approximately 22–24 px.

Rhova preserves this hierarchy with a 32 px title bar, 26 px menu, 69 px command area, 25 px category tabs, 41 px icon row, 68 px two-column side toolbar, 272 px right container and 28 px status bar at 1440×900. Its narrower side toolbar and warm technical drawing background intentionally allocate more space to the user's architectural fixture. The reference uses an empty modeling grid; the museum is original synthetic geometry. These are documented V1 adaptations, not pixel parity claims.

The clone-this plugin's reference/audit/convergence procedure was read in full. Evidence and its unresolved full-parity manifest stay ignored under `.devin/clone-this/rhova/`. The native commercial application was not run, so matched runtime screenshots, exact pixel differences, a NURBS engine and full native behavioral parity are **not claimed**.

## Attribution

Rhino / Rhinoceros are trademarks of Robert McNeel & Associates. Rhova is an independent browser UI study, not an official McNeel product. The reference screenshot is used for inspection only and is not bundled in the app. All app icons are original SVG line art; all scene assets are procedural and local. Third-party dependencies retain their own licenses.
