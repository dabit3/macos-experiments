# Swiss Grid in Motion (dark)

Launch video for "macOS in Devin Cloud", direction 1. HTML + CSS renderer driven frame by frame with Playwright, encoded with ffmpeg.

- `config.js` - every editable parameter: grid, palette tokens, headline, composer copy, session captions, footage in/out, scene timings, zoom scales.
- `index.html` - the scene layout and motion (`window.setFrame(f)`).
- `render.mjs` - renders 840 PNG frames with Chromium and encodes `out/swiss-grid-in-motion.mp4` (1920x1080, 30 fps, libx264, yuv420p, no audio). `node render.mjs --stills 1.2 12.0` renders single frames.
- `extract-frames.sh` - regenerates `frames/rl/` from the supplied `roomlight_ipad_landscape.mp4`.

Setup: `npm install && npx playwright install chromium`, put the Devin logo PNGs (`DEVIN_LOCKUP_HORIZONTAL_WHITE_TRANSPARENT.png`, `DEVIN_AVATAR_SQUARE_WHITE_NO_BG.png`) in `assets/`, run `./extract-frames.sh`, then `node render.mjs`.
