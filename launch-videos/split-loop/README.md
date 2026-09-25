# Launch video: Split Loop

Remotion source for the "Split Loop" Devin on macOS launch video (1920x1080, 60 fps, 30.5 s).

Left half: the Devin session (prompt -> reply -> build steps). Right half: Devin's Mac (desktop -> Simulator boot -> Otter Flap played with computer use). The split then merges into the test-recording player with the passed checks, followed by the end card.

```bash
npm install
./scripts/prepare-footage.sh /path/to/dv1.mp4   # extracts public/footage/mac.mp4 (not committed)
npm run render -- --fps 60                      # out/split-loop.mp4
npm run still -- --frame=1450                   # out/poster.png
```
