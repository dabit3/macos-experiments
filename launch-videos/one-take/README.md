# Launch video: One Take

Devin on macOS, as a single continuous camera move across one canvas: caret close-up, prompt typed, macOS environment selected, send, session, Computer pane, iPhone Simulator gameplay, test-results panel, end card.

- 1920x1080, 60 fps, 30 s, H.264 yuv420p (CRF 14), silent master.
- UI is rebuilt as React/CSS from the Figma file `vPLOWDwez4ZK6iQnPTCnN5`; the camera is a single transform over one 1203x690 Devin window (`src/Main.tsx`, `cameraAt`).

```sh
npm install
npm run dev        # Remotion Studio
npm run render     # out/one-take.mp4
npm run poster     # out/one-take-poster.png
npm run typecheck
```
