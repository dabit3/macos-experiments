# Prism

![Prism screenshot](screenshots/prism.jpg)

A native macOS image studio built around a real, editable image-processing graph. A graphite workspace, color-coded ports, curved connections and a live Core Image viewer keep the composition at the center of the app.

## Requirements and launch

- macOS 14 or newer; an Apple Silicon Mac is used for the attached build.
- Xcode with the Swift 6 toolchain selected. Built and tested using Xcode 26.6 / Swift 6.3.3 on macOS 26.5.2.
- No dependencies, network access, generator, account or signing credentials.

From this directory:

```sh
bash scripts/build.sh
open dist/Prism.app
```

The Swift package is also directly openable in Xcode with `open Package.swift`. The build script produces an ad-hoc-signed native `.app`, including its bundled artwork, in `dist/`. This is a local development build, not a notarized App Store release.

## Make a composition

First launch opens **Solstice / color study**, an editable image → exposure → saturation → output graph. **New** starts with an image connected directly to output. **Example** restores the first-launch composition. Both actions can be undone.

1. Add nodes using the graph toolbar.
2. Click the small output port on the right edge of a node, then an input port on the left of another. An existing input connection is replaced atomically. Press Escape to cancel a pending wire.
3. Select a node to adjust its controls in the inspector. The inspector’s input menus provide an alternative way to connect nodes; entries include each node’s index to distinguish duplicates.
4. Drag node headers to rearrange the graph. Scroll in either direction to pan; use −/+ to change graph zoom from 45–140%.
5. **Compare original** toggles the first image node’s untouched source. The exported image always comes from the output node, regardless of comparison mode.

### Nodes

| Node | Behavior |
|---|---|
| Image | Select either bundled original: Solstice or Nocturne |
| Exposure | Core Image exposure adjustment, −3 to +3 EV |
| Saturation | Core Image color controls, 0–200% |
| Blur | Gaussian blur, 0–60 source-image pixels, clamped and cropped edges |
| Blend | Linear crossfade: input A at 0%, input B at 100%; both inputs required |
| Output | Exactly one output node, used for the preview and PNG export |

The renderer validates the DAG and memoizes each visited node per evaluation. Disconnected experimental branches do not affect output. A missing input on the output’s active branch shows a useful empty state and disables export. Invalid cycles, self-connections and malformed projects are rejected without changing the graph.

### Files and recovery

- **Save** / **Open** use native file panels and human-readable `.prism` JSON files containing nodes, settings, positions and edges.
- Projects and images are saved wherever you choose in the native save panel. PNGs are real **1600 × 1100, 8-bit sRGB** composites.
- Every graph edit is atomically autosaved to `~/Library/Application Support/Prism/autosave.prism` and restored at launch.
- Undo/redo retain the last 80 edits in memory, including changes of project. Undo history and the manually saved file URL do not persist across app launches.
- The output node cannot be deleted. Other nodes may be deleted from the inspector, the context menu or the keyboard; Undo restores them and their wires.
- Invalid project files leave the current document intact. Inputs outside permitted numeric ranges are clamped; non-finite edits are ignored.

| Shortcut | Action |
|---|---|
| ⌘N / ⌘O / ⌘S | New / open / save |
| ⇧⌘S | Save as |
| ⇧⌘E | Export composite PNG |
| ⌘Z / ⇧⌘Z | Undo / redo |
| Delete | Delete selected node |
| B | Toggle original comparison |
| Escape | Cancel pending connection |

## Original artwork

Solstice and Nocturne are original, deterministic Core Graphics landscapes created specifically for this app, not downloaded photography. Their source is `scripts/artwork.swift`; regenerate with:

```sh
swift scripts/artwork.swift Sources/Prism/Resources
```

They depict a softly lit orbital form over sculptural mineral dunes. Both are bundled at full resolution so first launch is compelling and every workflow is available offline.

## Checks

```sh
bash scripts/check.sh
```

This runs the Xcode-bundled `swift-format` linter with strict mode, `swift test`, and the native release build/package/signing step. Format changes with:

```sh
xcrun swift-format format --in-place --recursive Sources Tests scripts/artwork.swift Package.swift
```

The logic suite covers cycle rejection with atomic rollback, connection replacement, deletion cleanup, protected output, JSON round-trips, malformed projects, required blend inputs, actual mixed pixel values, exposure doubling in linear light, grayscale output, blur bounds and real PNG serialization.

Native UI acceptance: build an image → exposure → saturation → output graph through ports; add a blur/blend branch; tune controls; compare original; reject a back-edge cycle; delete/undo; save/open; quit/relaunch; export two visually and numerically different PNGs. Native UI evidence and the executed test report are attached to the implementation session/PR.

## Bounded V1

- Uses two bundled, equal-size image sources; arbitrary image import, masks and additional blend modes are not implemented.
- Blend is a crossfade, not Photoshop-style screen/multiply. Core Image uses its color-managed working space; output is converted to sRGB.
- Full-size synchronous rendering favors correctness and a small dependency-free project. Very large graphs (up to 64 nodes) can be slower during slider interaction.
- The graph has a finite scrollable workspace and bounded zoom. Dense graphs may require manual arrangement.
- Original comparison refers to the first image node in the project, even if another source is used by the active output.
- Selection, pending wires, comparison, zoom and undo history are session UI state, not stored project data.
