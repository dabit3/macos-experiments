# Flowchart Studio: node-and-edge diagramming

![Flowchart Studio: node-and-edge diagramming screenshot](screenshots/flowchart-studio.jpg)

A self-contained flowchart editor built with hand-rolled SVG (no React Flow). Drag shapes from the
palette onto an infinite canvas, wire them together by dragging from one node's port to another,
rename things inline, and export the result as SVG or JSON.

**Recording:** https://app.devin.ai/attachments/a6c1fd19-2355-437a-9daf-95e32a749222/flowchart-design-pass-showcase-edited.mp4

## Features

- Palette of node types: start / end pill, process rectangle, decision diamond, data parallelogram.
- Drag from the palette to place a node; double-click a node or edge to edit its label inline.
- Four connection ports per node — drag a port onto another node (or one of its ports) to create an
  edge with an arrowhead. Edges can carry an optional label ("Yes" / "No").
- Orthogonal (rounded elbows) or straight edge style toggle.
- Marquee multi-select on empty canvas, Shift-click to add to the selection, drag to move the whole
  selection together, `Delete` to remove, `Ctrl+D` to duplicate, `Ctrl+A` to select all.
- Snap-to-grid (20 px, centre-aligned so ports on different shapes line up), undo / redo.
- Wheel zoom around the cursor, Space + drag (or the pan tool / middle mouse) to pan, minimap that
  can be clicked / dragged to jump around.
- Auto layout: layered top-to-bottom placement (longest-path layering + barycenter ordering) that
  also re-assigns ports so loop-back edges route around the outside of the graph.
- Export SVG (standalone file with all labels as `<text>`), export / import JSON.
- Keyboard shortcut reference (`?`), floating zoom control, and a selection chip that summarises what is selected.
- The document autosaves to `localStorage`; there is no backend and no network access at runtime. Inter is bundled via `@fontsource-variable/inter`, so typography does not depend on system fonts.

## Run it

```sh
cd flowchart-studio
npm install
npm run dev      # http://localhost:5173
npm run lint
npm run build
```

## Computer-use skill showcased

**Port-to-port edge dragging, marquee selection, panning / zooming an infinite canvas.** The whole
scenario below is driven with the mouse and keyboard through the UI — precise press-drag-release
gestures between small port handles, rubber-band selection over empty canvas, wheel zooming and
Space + drag panning — and the exported file is then verified from the shell.

## Browser test scenario

Scenario: draw a 7-node flowchart for "Devin fixes a CI failure".

| # | Step | Expected result |
|---|------|-----------------|
| 1 | Maximise Chrome, open `http://localhost:5173`, click **New** | Empty dotted canvas, palette on the left, minimap bottom-right with the caption `0 nodes · 0 edges`, and a "Start with a shape" empty-state card. |
| 2 | Drag seven shapes from the palette onto the canvas: Start pill, Process ×4, Decision diamond, End pill | Each drop creates a node snapped to the grid; the minimap caption counts up to `7 nodes`. |
| 3 | Double-click each node and type a label: `CI fails`, `Read CI logs`, `Reproduce locally`, `Write a fix`, `CI green?`, `Merge PR`, `Done` | The inline editor opens on double-click, `Enter` commits and the node shows the new label. |
| 4 | Drag from the bottom port of each node to the top port of the next one to chain them; drag from the diamond's bottom port to `Merge PR` and from its right port back up to `Read CI logs` | Every drop creates an edge with an arrowhead pointing at the target; the loop-back edge routes around the right side. |
| 5 | Double-click the two edges leaving the diamond and type `Yes` and `No` | Edge labels render on a pill at the edge's midpoint. |
| 6 | Marquee-select three nodes by dragging a rectangle over empty canvas around them, then drag one of them | The three nodes highlight together, the selection chip at the bottom of the canvas says `3 nodes + 2 edges selected` (the edges between them are picked up too), and all three move as a group. |
| 7 | Click a single node and press `Ctrl+D`, then press `Delete` | A duplicate appears offset by one grid step and is selected ("Duplicated 1 node"); `Delete` removes it and the count returns to `7 nodes`. |
| 8 | Click **Auto layout** | Nodes are arranged into layers top-to-bottom, the loop-back edge goes around the right side, and the view fits the diagram. |
| 9 | Scroll the wheel down over the canvas, then back up | The zoom percentage in the bottom-left zoom control drops and rises again; the minimap re-frames to show the new visible area relative to the nodes. |
| 10 | Click **Export SVG** | Chrome downloads `flowchart.svg` to `~/Downloads`; a toast confirms the download. |
| 11 | In a shell, parse the file and count labels | The file parses as XML with an `svg` root and contains all seven node labels. |
