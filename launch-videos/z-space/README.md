# Launch video: Z-Space Layers

Remotion source for the Devin on macOS launch video (1920x1080, 60 fps, ~30 s).
The Devin UI is rebuilt as React components (`src/ui/`) from the Figma captures and floated as layered cards in 3D space (`src/Layer.tsx`, `src/Video.tsx`).

```sh
npm install
npm run typecheck
npm run render   # out/z-space.mp4
npm run still -- --frame=1290
```

`public/media/desktop.mp4` is a cropped Computer-pane segment from the reference recording, used inside the rebuilt Computer pane and test player.
