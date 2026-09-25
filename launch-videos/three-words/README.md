# Launch video: Three Words

Devin on macOS — typography-led launch film. `Build.` `Run.` `Verify.` each morph into the real Devin UI (prompt interface → session with the Computer pane booting the iOS Simulator → test recording viewer with passed checks).

- Remotion 4, 1920×1080 @ 60 fps, ~30.5 s, silent.
- UI rebuilt from the "Devin Screenshots" Figma file (exact sizes, colors, radii, icons in `public/icons`).
- `public/media/computer.mp4` is a small crop of the Computer pane from the reference recording (`npm run prep` regenerates it).

```sh
npm install
npm run studio   # preview
npm run render   # out/three-words.mp4
```
