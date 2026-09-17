# Veyra

![Veyra screenshot](screenshots/veyra.jpg)

A local, interactive browser BIM workspace inspired by Autodesk Revit 2025.1.
The included Alder Cultural Pavilion is original procedural architecture: two
storeys, glazed galleries, a timber screen, roof garden, courtyard, reflecting
pool and landscaped public realm.

## Run

Node 24 (Node 22.18+ also supports the test runner), npm 10+.

```sh
cd veyra
npm ci
npm run dev
```

No account, backend, Python, remote assets or API keys. Production:
`npm run build && npm run preview`. Vite uses `base: './'`.

## Editing

Open Level 1 to draw walls with two clicks on the 0.5 m grid. Place a door by
clicking near a wall; the door is hosted and creates an actual opening in 3D.
Select elements in any view, edit Properties, then Apply. Changes coordinate
across the 3D, floor plan and south elevation. Use the category dialog to hide
model categories, the view cube to orient the 3D view, and mouse drag/wheel to
orbit/zoom (right drag pans). Ctrl/Cmd+Z and Ctrl/Cmd+Shift+Z undo/redo.

Changes automatically save in this browser. File provides explicit Save, project
JSON download/open, model schedule CSV, plan SVG and reset. All exports contain
current model data, not screenshots. `TESTING.md` records reproducible checks.

## Source study and attribution

Autodesk Revit is a trademark of Autodesk. Veyra is an independent browser demo,
not affiliated with Autodesk; it neither reads nor writes RVT files.
All application geometry, icons, code and styling are original. No Autodesk
assets are bundled in the runtime.

The coherent visual reference is **Revit 2025.1**, shown in Autodesk's public
2025 “User Interface” tutorial:

- https://help.autodesk.com/cloudhelp/2025/ENU/Revit-GetStarted/files/GUID-3197A4ED-323F-4D32-91C0-BA79E794B806.htm
- https://help.autodesk.com/videos/97dfde60-54e0-11ea-86bb-6702fb65b9b8/video.webm
- https://help.autodesk.com/cloudhelp/2025/ENU/Revit-GetStarted/files/GUID-A764EA7A-FE26-469B-857C-F3A70812FC34.htm
- https://help.autodesk.com/cloudhelp/2025/ENU/Revit-GetStarted/files/GUID-C8D3E5A6-02A5-43A9-AFFC-D49DD27398B1.htm

### Observations and measurements

The tutorial frames at 00:28 and 01:05 are 1280 × 720. Observed: 25 px title /
quick access row; roughly 18 px tab strip; ribbon from y=43 to y=120; 21 px
options row; 18 px view tabs. Left palettes occupy x=0–228; Properties ends
near y=420, Project Browser fills below. Pale gray/lavender chrome, thin
one-pixel dividers, square 24–32 px technical icons, blue active selection,
compact approximately 11 px system text, nested tree rows and table-like
property fields. View controls lie at the canvas bottom. The tutorial
demonstrates coordinated selection/property changes in tiled 3D, plan and
elevation views.

Veyra uses that hierarchy and palette, with a 252 px dock at normal desktop
width and 232 px at 1280 px. The workspace opens one enlarged 3D tab to showcase
the pavilion; coordinated drawings are adjacent tabs. This is a browser V1
within the requested scope. Native source execution and matched screenshot
comparisons are unavailable; **literal pixel identity and native feature
parity are not claimed**. The clone-this reference/audit process was used,
with commercial-engine parity boundaries documented in TESTING.md.
