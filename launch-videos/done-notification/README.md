# Launch video: Done Notification

Bookended 32s launch film for Devin on macOS (1920x1080, 60 fps, H.264). Opens on Devin's
"I'm done building the Flappy Otter game" message, expands the recording thumbnail, rewinds
through prompt -> build -> computer-use testing in the iOS Simulator -> passed checks, then
returns to the message and the end card.

Built with Remotion; every Devin UI surface is rebuilt in React from the Figma captures
(icons in `public/icons`, lockup in `public/brand`).

## Render

```bash
npm install
./scripts/prepare-footage.sh /path/to/dv1.mp4   # extracts Simulator frames to public/generated (not committed)
npm run typecheck
npm run render                                  # -> out/done-notification.mp4
```
