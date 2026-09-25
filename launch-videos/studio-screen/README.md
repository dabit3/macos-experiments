# Launch video: Studio Screen

Remotion + three.js. The Devin UI is rebuilt in React from Figma values and projected onto a monitor in a bright studio; at push-ins the camera lands exactly 1:1 so the UI is rendered flat.

```sh
npm install
./scripts/extract-footage.sh /path/to/dv1.mp4   # Computer-pane footage (not committed)
npm run studio
npx remotion render StudioScreen out/devin-macos-studio-screen.mp4 --gl=angle
```

1920x1080, 60 fps, 33.5 s, H.264 yuv420p CRF 14, silent.
