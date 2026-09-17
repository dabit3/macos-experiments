# Nuvio

A local architectural visualization editor inspired by **Twinmotion 2025.1**.
Opens directly to Forest House: a cantilevered glazed pavilion with a cedar terrace,
furnished interior, lounge chairs, boardwalk, reflected pond, rocks and seeded forest.
Everything in the viewport is actual Three.js geometry. No scene screenshots, external
model services, authentication, commercial engine, or runtime asset downloads are used.

## Run

Node 22.12+ (tested with 24.19), npm 10+.

```sh
cd nuvio
npm ci
npm run dev
```

For the production build and full reproducible test instructions, see [TESTING.md](TESTING.md).

## Workspace

- Search/filter eight local assets and click to place real geometry.
- Click an object or its scene row to select; set position, rotation, scale, visibility
  and surface finish. Duplicate, delete, frame selection; use undo/redo.
  Numeric transforms commit on Enter or blur, including negative/fractional values.
- Set time of day, summer/autumn/winter foliage, clear/overcast/mist weather and haze.
- Orbit, pan and zoom the real camera. Save and rename camera images, restore their
  camera and ambience, open presentation mode, export the current viewport as PNG.
  Use the refresh icon below an image to update its camera, ambience and thumbnail.
- Edits auto-save to `nuvio.project.v1` in localStorage. Export/import a validated
  `.nuvio.json` file for portable projects. Reset Demo is undoable.
- Library, scene/properties, and media docks can collapse independently.

## Reference audit and attribution

The coherent visual target is Twinmotion **2025.1**, using Epic's publicly accessible
viewport screenshot and the February 18, 2025 release description of its environment
redesign. The screenshot includes the 2025 volumetric-cloud control. Documentation can
change; this audit describes the material captured September 15, 2026.

Sources actually inspected:

1. https://dev.epicgames.com/documentation/en-us/twinmotion/the-viewport-in-twinmotion
2. https://d1iv7db44yhgxn.cloudfront.net/documentation/images/7af1097d-befb-4b1b-a1ac-e5a25636a62a/viewport-in-twinmotion.png
3. https://www.twinmotion.com/en-US/news/twinmotion-2025-1-is-here
4. https://design8.com/en/news/twinmotion-2025-1-is-available/

The raw reference PNG is 1438×808. Observed geometry: 25 px menu/title strip,
~39 px tool strip, library x=0–263, viewport x=265–1175, right panel x=1180–1437,
footer y=758–807. Right scene graph ends around y=288; environment tabs sit below
it. Media occupies the viewport-width dock at y≈532–758. Palette: charcoal,
low-contrast dividers, small gray monoline icons, blue selected tools/text and
slider accents. Image media are compact rectangular thumbnails. The visible
source has cloud/environment controls, an Ambience scene row, Env/Camera/Render/FX
tabs and footer toggles.

Nuvio applies those panel/layout principles with a 252/292 px left/right layout
at 1440 px and a 190 px media dock, modestly larger readable browser text, Nuvio
branding, local curated assets instead of commercial library categories, and the
requested forest-retreat project. These are documented adaptations, **not measured
pixel equality**. The browser reference was inspected, including its full-size PNG.
Native commercial runtime behavior and same-fixture native/clone visual comparisons
were inaccessible. No zero-pixel-difference or full engine-parity claim is made.

All scene geometry, texture generation and graphic layout code here is original.
Reference images are inspection evidence only and are not shipped in the application.
Twinmotion is an Epic Games product; Nuvio is an independent browser demo with no
affiliation. React, Three.js, Vite, Vitest and Lucide retain their package licenses.

## Technical boundaries

Uses a seeded procedural forest with instanced foliage/trunks, static-on-change
shadow maps, a real planar reflection, procedural wood texture, physical materials,
and direct Three.js rendering. Software WebGL automatically enables the visible
Performance mode: 75% viewport resolution, lighter forest detail and smaller
reflection/shadow maps. Hardware WebGL uses Standard mode. Thumbnails render when
visible and remain stable during object edits; update a shot explicitly to refresh it.
No Lumen, path tracing, volumetric clouds, native CAD
import, VR, cloud presentations, animation export, or commercial asset-library access.
Render and FX controls are explicitly disabled. Project import accepts Nuvio JSON only.
See [TESTING.md](TESTING.md) for further fidelity and persistence boundaries.
