# Solune

![Solune screenshot](screenshots/solune.jpg)

A local architectural visualization studio inspired by **Lumion 2024**. Opens on Casa del Mar, an original procedural coastal villa: two furnished floors, recessed glazing, timber pergola, infinity pool with planar reflection, landscape, palms and olive trees.

## Run

Requires Node.js 22.12+ (verified using Node 24.19) and a WebGL 2 browser.

```sh
cd solune
npm ci
npm run dev
```

Production: `npm run build && npm run preview -- --port 4173`. Vite uses `base: './'`, so the contents of `dist` can also be served from a subdirectory. No backend, auth, remote assets or API keys.

## Workflows

- **Build:** orbit/pan/zoom, edit time, sun heading, weather, cloud coverage and interior lighting.
- **Materials:** apply four stone finishes and adjust roughness. Click the villa to select it.
- **Objects:** searchable library, click-to-place four procedural assets, scene selection, position/rotation/scale, duplication and deletion.
- **Photo:** four initial camera compositions, store up to twelve shots, update cameras, exposure/saturation/bloom/vignette, composition grid and genuine PNG export up to 3840×2160.
- **Projects:** localStorage autosave, undo/redo, validated JSON import/export, and undoable fixture reset.

Dragging sliders creates one undo step per gesture. Camera navigation is exploratory; **Update camera** commits a composition to the project.

See [TESTING.md](TESTING.md) for exact tests, browser sequence and parity boundaries.

## Reference audit and attribution

The reference is one coherent release, **Lumion 2024**, rather than a mixture of Lumion versions.

1. [Lumion 2024 release](https://lumion.com/news/lumion-2024-release) — vertical mode navigation, real-time preview, nature/glass lighting, camera schemes.
2. [Real skies guide, April 2024](https://lumion.com/tips-guides/real-skies-guide-2024) — FX panel and real skies controls.
3. [Official real-skies UI clip](https://a.storyblok.com/f/180614/x/1dd79904e4/real-skies-ui.mp4) — inspected the actual frame at 2 seconds (1568×882).
4. [Official camera-input clip](https://a.storyblok.com/f/180614/x/d6862fed7b/camera-control-schemes-sketchup-new-2024.mp4) — inspected settings at 3 seconds.

### Direct observations and measurements

The 1568×882 official sky UI frame has a dark charcoal background (~#29292b), a **34 px left mode rail**, **294 px effects column** beginning at x=47, square-edged controls, white fine-stroke icons around 16–24 px, a blue style block, a top FX strip from x=395, a framed preview at x=519–1430/y=86–600, and a **horizontal camera/clip strip at y=747–844**. Numbered thumbnails, blue active mode and export tiles, compact labels, and thin horizontal parameter sliders anchor the visual system. The guide explicitly documents sky heading, brightness and sun-intensity sliders. The release documents the new vertical photo/movie/panorama sidebar.

Solune retains this visual hierarchy, palette and photographic workflow but deliberately gives the requested original coastal scene more viewport space. Build controls are clustered at the bottom; Photo mode uses effects at left and a numbered bottom camera strip. A 49 px project bar, 47 px rail and 241–276 px translucent inspector are browser V1 adaptations. Their dimensions are implementation values, not claimed Lumion measurements.

The installed `clone-this` reference/audit/convergence process was followed within the requested browser V1 scope. Private native interactions and identical-source scene renders could not be captured; its zero-pixel native parity gate is **not claimed as passed**. Source videos and audit artifacts remain untracked in the app's `.devin/clone-this` run directory.

All scene geometry is authored here; no Lumion models, commercial textures, screenshot backdrops or copied software assets are distributed. Lumion is a trademark of its respective owner; this is an independent demonstration without affiliation. Three.js and Lucide are MIT-licensed dependencies. All required runtime assets are bundled locally.
