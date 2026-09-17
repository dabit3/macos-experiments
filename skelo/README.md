# Skelo

![Skelo screenshot](screenshots/skelo.jpg)

A local, interactive architectural modeling demo inspired by **SketchUp Pro 2023 for Windows**. Opens directly into Komorebi House, an original procedural Japanese courtyard residence with timber screens, sliding glazing, open furnished rooms, a stone garden, hillside terraces and trees.

```sh
npm ci
npm run dev
```

Node 24 is recommended. No backend, credentials, external textures or native license are required. Production uses `base: './'`; serve `dist` independently or in a subdirectory.

Use the left palette to select, draw rectangles, push/pull parametric masses, paint, orbit, pan and zoom. The right tray provides editable entity dimensions, material swatches, tag visibility, shadows and an outliner. Shift-click selects multiple entities; Make Group creates an assembly. Scene tabs recall camera and tag visibility. Changes autosave locally. File offers validated project import, JSON project export and Wavefront OBJ geometry export.

See [TESTING.md](TESTING.md) for reproducible checks, UI steps and boundaries; [REFERENCES.md](REFERENCES.md) records the actual source observations. Skelo is an independent educational demo, unaffiliated with Trimble. SketchUp is a Trimble trademark. All project geometry and icons here are original.
