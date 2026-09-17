# Atrio

![Atrio screenshot](screenshots/atrio.jpg)

A local, editable architectural workspace inspired by **Graphisoft Archicad 28**.
The included Oak & Light arts campus links a real Three.js axonometric model to
an SVG floor plan. No account, backend, commercial engine, or remote assets required.

```sh
npm ci
npm run dev
```

Use the left Toolbox to draw walls and slabs with two plan clicks. Place a door
on a wall. Select geometry in either view and edit its dimensions, material,
position, or story in Element Settings. Changes autosave; undo/redo works across
model edits. Save Project exports editable JSON; Open Project validates it.
Export Plan produces a dimensioned SVG of the active story and layer combination.

See [TESTING.md](TESTING.md) for reproducible checks, browser steps, and limitations.
See [REFERENCES.md](REFERENCES.md) for source observations and attribution.
