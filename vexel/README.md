# Vexel

![Vexel screenshot](screenshots/vexel.jpg)

A self-contained architectural scene editor inspired by the dark **Autodesk 3ds Max 2025** desktop workspace. Opens directly to **Forma Gallery**, a procedural limestone gallery with eleven sculptural arch ribs, bronze glazing, four artworks, plinths, oak benches, plants and studio lighting.

## Run

Node.js 22.12+ (verified with 24.19.0), npm 10+:

```sh
cd vexel
npm ci
npm run dev
```

Production: `npm run build && npm run preview -- --port 4173`. Vite uses `base: './'`; production files also work below a subdirectory. No backend, external assets, account or credentials.

## Workflows

- Four synchronized WebGL viewports: Top, Front, Left wireframes and a shaded Perspective. Select in a viewport or the Scene Explorer, filter names, toggle object visibility.
- Accurate numeric world transforms; add box/sphere/cylinder/torus primitives, clone/delete objects, change name and material, and apply a real vertex Twist modifier.
- Material presets and numeric roughness/metalness; studio/daylight lighting.
- Alt+W or viewport corner buttons maximize/restore views. Perspective supports orbit, pan and zoom; orthographic views support zoom.
- A 0–100 frame timeline at 24 FPS with linear position/rotation/scale keys. Elapsed-time playback maintains animation speed when rendering skips frames. Set Key captures the current pose. Editing an already-keyed object updates the current frame; Auto Key adds keys to unkeyed objects.
- Undo/redo up to 60 scene revisions. Project automatically saves to `localStorage`; File menu imports/exports validated JSON. OBJ export bakes modifiers and the sampled animation frame into real triangle geometry.

### Shortcuts

`Ctrl+Z/Y` undo/redo · `Ctrl+S` save locally · `Alt+W` maximize/restore · `Space` play/pause · `G` grid · `F` reset cameras · `Delete` selected object.

## Source reference and observations

Single coherent reference: Autodesk's **3ds Max 2025** documentation. Autodesk notes some help screenshots may depict older interface elements. These were inspected before implementation:

- [Interface overview](https://help.autodesk.com/cloudhelp/2025/ENU/3DSMax-Basics/files/GUID-F8326C68-F2F9-47F7-AC1D-BA41D7825C7C.htm)
- [Official annotated UI screenshot](https://help.autodesk.com/cloudhelp/2025/ENU/3DSMax-Basics/images/GUID-6C09F135-CAF9-4556-A917-F5CC719F898C.png)
- [Command Panel](https://help.autodesk.com/cloudhelp/2025/ENU/3DSMax-Basics/files/GUID-E3CB809D-94ED-4C30-892B-1D12B8721EA5.htm)

Observed screenshot dimensions: **1356 × 757**. Application bounds approximately x=35–1308, y=32–717. Menu around y=48–65; toolbar y=66–94; Graphite ribbon y=95–190; viewports x=310–1145, y=196–631 in equal quadrants. Scene Explorer occupies x=78–307 (~229 px); right Command Panel x=1147–1308 (~161 px, older narrow UI); timeline/status y=633–717 (~84 px). Text is approximately 10–11 px at screenshot scale, square gray controls, thin separators, blue selection, yellow active viewport edges. Command tabs are icons, modifier controls use compact rollouts, and bottom controls remain visible while scene panels scroll.

Vexel retains those structural relationships, dark gray palette and control density. Its usable right panel is 256 px at 1440 and 236 px at 1280 to accommodate actual browser numeric fields. The original scene, view labels and product name differ by request. The generated gallery is original geometry, not an Autodesk screenshot or commercial sample asset.

All geometry, lighting and artwork are generated locally. Icons: Lucide (ISC); React (MIT); Three.js (MIT). No Autodesk source code, logos, commercial assets or proprietary engine are bundled. This is an independent browser V1, not Autodesk software or a claim of native feature/pixel parity. See [TESTING.md](TESTING.md) for reproducible evidence and limitations.
