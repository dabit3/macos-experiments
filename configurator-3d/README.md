# 3D Sneaker Configurator (Three.js)

![3D Sneaker Configurator (Three.js) screenshot](screenshots/configurator-3d.jpg)

A Three.js product configurator for a low-top court sneaker in the spirit of the Nike Air Force 1. The shoe is built entirely from procedural geometry: a lofted "last" surface (superellipse cross-sections swept along a Hermite profile) forms the upper, and every overlay panel (toe cap with perforations, mudguard, eyestays, heel counter, swoosh) is a thin shell offset from that same surface, so panels sit flush no matter how the profile is tuned. The chunky cupsole and gum outsole are extruded from the last's footprint and bent with the toe spring. There are no external model files, no backend and no runtime network calls; everything is bundled by Vite.

## Features

- **Click-to-select in 3D** – parts are picked with a `THREE.Raycaster`; the hovered part gets a black inverted-hull outline and the selected part an orange one. A status chip in the viewer mirrors the selection.
- **Eight configurable parts** – Base (quarter, vamp and collar), Overlays (toe cap, mudguard, eyestays, heel counter), Swoosh, Laces, Tongue, Heel tab, Midsole and Outsole, each with its own colour and finish.
- **Guided editing** – an eight-step part stepper (Previous/Next buttons, progress bar, `←`/`→` keys) flies the camera to the best angle for each part; a floating quick bar in the viewer carries the part name, stepper and 16 swatches so most edits never leave the stage. Hovering the shoe shows the part name at the cursor.
- **Curated icons** – six one-click colourways (Triple White, Bred, Game Royal, Wheat Gum, Volt Night, Liquid Chrome); the active one is detected from the current design.
- **Undo / redo** – full design history (buttons in the header, `Ctrl+Z` / `Ctrl+Shift+Z`); typing and colour-picker drags collapse into single steps.
- **Colours** – 16 named swatches plus a native `<input type="color">` and a validated hex field. Colour changes ease in on the model.
- **Finishes** – matte leather (sheen), suede (napped, velvety sheen), gloss (clear-coated patent) and metallic, on `MeshPhysicalMaterial` with a `RoomEnvironment` PMREM and neutral tone mapping.
- **Heel label** – up to 8 characters on a rounded, stitched, padded heel patch. Three techniques — satin-stitch embroidery (with seven thread colours, Auto picks contrast), debossed leather, or hot-stamped gold foil — each rendered as a 1024 × 560 colour layer plus a matching relief (bump) map so the lettering physically catches the light. The sidebar preview is rendered from the same artwork. Empty text shows the brand mark.
- **Construction detail** – deterministic leather/textile bump maps, a moulded rib and "AIR" mark on the cupsole wall, punched toe perforations, and double stitch rows along the toe cap, eyestays and cupsole. A contact shadow is baked from the real sole footprint.
- **Camera** – orbit by dragging, zoom with the wheel, autorotate toggle (`Space`), four animated presets (Hero, Side, Heel, Top; keys `1`–`4`).
- **Randomise** – a seeded `mulberry32` PRNG so the sequence of random designs is reproducible in a fresh tab (key `R`).
- **Share** – the full design is encoded in the URL hash (`#upper=1f4bd8.metallic&stripe=c8102e.gloss&…&text=DEVIN&view=hero`) and restored on load, so a copied link or a reload in a new tab reproduces the sneaker exactly.
- **Download PNG** – renders a clean transparent frame (outlines removed) and saves `sneaker-<text>.png`.
- **Software-GL friendly** – direct `WebGLRenderer.render` (no post-processing passes), adaptive render scale while orbiting, and a painted floor shadow instead of shadow maps, so it stays fluid even on SwiftShader.

## Run it

```sh
cd configurator-3d
npm install
npm run dev      # http://localhost:5173
npm run lint     # oxlint
npm run build    # tsc -b && vite build
```

## Computer-use skill showcased

**Orbiting a WebGL scene by dragging, selecting 3D parts, and verifying rendered colours.** The scene is a `<canvas>`; there is no DOM to inspect for the shoe itself, so the agent has to drag to orbit, click on the correct 3D region to pick a part, and confirm from the rendered pixels (and the status chip / parts list, which mirror the scene state) that the right part changed colour and finish.

## Browser test scenario

1. Open the app in a maximised Chrome window. **Expect:** a white "Court Classic" with black patent swoosh and gum outsole on a sage stage; Materials tab on the right with six curated icons and the part stepper.
2. Drag on the canvas to orbit and scroll to zoom. Hover the shoe. **Expect:** the camera rotates/zooms; a tooltip names the part under the cursor.
3. Click the **Bred** icon, then **Undo** (`Ctrl+Z`) and **Redo**. **Expect:** the whole shoe switches to black/red, reverts, then returns; the Bred card is marked active.
4. Click the midsole in 3D and pick **Obsidian** from the floating quick bar. **Expect:** orange outline on the cupsole, the midsole re-renders in navy.
5. Click the base in 3D, pick **Royal** and set **Metallic**. Use the stepper's **Next** to reach Laces (camera flies to the laces) and pick **Volt**; click the swoosh in 3D and pick **University Red** + **Gloss**. **Expect:** four distinctly coloured parts.
6. Open Personalise (camera goes to Heel), type `DEVIN`, and try **Embroidered**, **Debossed** and **Gold foil**. **Expect:** the lettering appears on the stitched heel label and in the preview for each technique; counter `5/8`.
7. Switch Hero, Side, Heel and Top and toggle Auto-rotate. **Expect:** animated camera moves, active preset highlighted.
8. Click **Download PNG**. **Expect:** `sneaker-devin.png` in Downloads, hundreds of KB.
9. Open Your design, copy the share URL and open it in a new tab. **Expect:** the identical sneaker including label technique and `DEVIN`.

### Additional checks

- Before building the final colourway, exercise Randomise then Reset. **Expect:** colours change, then defaults return.
- Apply `#123456`, then enter `#ZZZZZZ`. **Expect:** the valid colour applies; invalid input does not replace it.
- Enter `ABCDEFGHI` in Engraving. **Expect:** `ABCDEFGH`, counter `8/8`.
- Focus a sidebar tab and use Left/Right arrows. **Expect:** the active section changes and wraps.
- Inspect all four camera views on desktop and at 390 × 844. **Expect:** the sneaker fits above the camera controls and footer, with a readable heel label.
- Inspect Chrome's console. **Expect:** no runtime errors.

## Recording

Recording: https://app.devin.ai/attachments/519f79e7-62a6-48a5-9442-de3cec6cb515/configurator-c9a95bf-edited.mp4

Steps 1–9 passed on `c9a95bf` with native mouse and keyboard; the exported PNG was 332,023 bytes, 1150 × 983 RGBA, and the share URL restored every field including the label technique. Follow-up commits widened the laces/tongue guided shots and made the label preview a canvas (the original run logged `ERR_INVALID_URL` for the old data-URL preview); both were re-verified in the browser.
