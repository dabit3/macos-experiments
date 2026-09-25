# Launch video: Accessibility X-Ray

Devin on macOS, 31s at 1920x1080 / 60fps. Prompt, environment switch to macOS, build session, iOS Simulator boot, then an accessibility-tree overlay of the Flappy Otter pause menu with the `query` -> `@i17 button "Resume" {press}` -> `act press` loop, ending on a passed check in the test recording view.

The Devin UI, Simulator chrome and game are React/SVG (Remotion). `public/macos-desktop.jpg` is a still from the reference recording.

```sh
npm install
npm run studio   # preview
npm run render   # out/a11y-xray.mp4 (H.264, CRF 14, yuv420p)
npm run typecheck && npm run lint
```
