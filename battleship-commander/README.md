# Battleship Commander

![Battleship Commander screenshot](screenshots/battleship-commander.jpg)

Battleship against a hunt-and-target AI. Two 10×10 grids, the classic 5/4/3/3/2
fleet, drag-and-drop ship placement, a deterministic seed so any game can be
replayed move-for-move, animated hits/misses/sunk announcements, a shot log, an
educational probability heatmap for your own guesses, and a one-click rematch.
The arcade presentation includes an illustrated title screen, an original
anchor-and-wave insignia, ocean radar, top-down ship models, a live score strip,
combat callouts, and a victory/defeat award screen. Motion respects the system's
reduced-motion preference.

## Run it

```bash
cd battleship-commander
npm install
npm run dev        # http://localhost:5173/?seed=8
npm run lint
npm run build
```

No backend, no network calls; everything is bundled (including the Barlow
Condensed / Inter / JetBrains Mono fonts, SVG insignia, and generated ocean
key art). The insignia and ship models are hand-authored SVGs.

## How to play

- **Launch.** Click *Take command* on the title screen to enter deployment.
- **Placement.** Drag each ship from the dock onto *Your fleet*. Press `R`
  while dragging (or while hovering a ship in the dock / on the board) to
  rotate; clicking a placed ship also rotates it. Invalid drops (off-grid or
  overlapping) snap back. *Random placement* fills the grid for you.
- **Battle.** Click a cell in *Enemy waters* to fire. Hits explode, misses
  ripple, and sinking a ship shows a banner. After a short beat the AI fires
  back at your grid.
- **AI.** Hunt mode probes a checkerboard parity sized to the smallest ship
  still afloat; after a hit it switches to target mode, extends the line of
  adjacent hits, and returns to hunting when the ship is sunk.
- **Seeds.** `?seed=N` fixes both the enemy layout and the AI's random
  choices. Same seed + same moves = same game. *Rematch* replays the same
  seed against your current fleet; *New seed* picks another one.
- **Heatmap.** Toggle *Probability heatmap* to shade every unknown enemy cell
  by how many legal placements of the remaining ships cover it (placements
  through open hits are weighted heavily). The pulsing cell is the best guess.

## Computer-use skill showcased

**Turn-based grid clicking with probability reasoning and reading two boards
at once.** The agent has to drag ships precisely onto grid cells, rotate them
with the keyboard, then alternate between reading the enemy board (its own
shots, the heatmap) and its own board (incoming fire) while clicking small
targets turn after turn until the game ends.

## Browser test scenario

Open `http://localhost:5173/?seed=8` in a maximised Chrome window. Capture the
arcade title screen and click *Take command* to enter deployment.

1. Drag all five ships from the dock onto *Your fleet*, rotating at least two
   of them to vertical with `R`. **Expected:** green preview while hovering a
   legal spot, red while illegal; five dock cards read `DEPLOYED`, the badge reads
   `5/5 placed`, and *Start battle* becomes enabled.
2. Click *Start battle*. **Expected:** the dock is replaced by the heatmap
   toggle, fleet status, and shot log; the status pill says it is your turn.
3. Fire a few opening shots by clicking cells in *Enemy waters*.
   **Expected:** each click shows an animated miss/hit, appears at the top of
   the shot log, then the AI fires at your board after a short delay.
4. Turn on *Probability heatmap* and use it for several turns, firing at the
   highlighted best cell. **Expected:** the overlay shades cells amber with
   percentages, switches to *target mode* after a hit, and updates every shot.
5. Sink a ship. **Expected:** a "You sank the enemy Cruiser!" style banner,
   the sunk cells turn dark red, and *Enemy fleet* strikes the ship through.
6. Play to the end. **Expected:** a win/lose overlay with seed, game number,
   shots, hits, accuracy, and ships sunk for both sides.
7. If the game was lost, click *Rematch* once. **Expected:** the same seed and
   your same fleet are reused, the enemy layout is identical, and the game is
   played again to a final result.

This scenario is also packaged as a computer-use regression test in
`.agents/skills/battleship-commander-showcase/SKILL.md` (repo root): Devin's
testing agent drives the real UI in maximised Chrome, records the run, and
annotates it with setup / test_start / assertion markers, so the annotated
video is the test artifact. A seed-8 oracle in the skill (fixed enemy layout,
`D5` hit / `E5` miss) lets it check determinism without scripting the browser.

Recording: https://app.devin.ai/attachments/9c63b38a-6ebc-40bb-a7bc-10096f9d138d/battleship-showcase5-edited.mp4

Result of the arcade recording (revision `7b545cc`): both game 1 and the required
same-seed rematch ended in defeat. Each report showed 36 player shots, 15 hits,
42% accuracy and 4/5 enemy ships sunk; the AI recorded 36 shots, 17 hits, 47%
accuracy and 5/5 sunk. The full requested procedure completed using visible
heatmap reasoning. Victory-specific styling was not exercised on this revision.

During testing, generic combat text overlapped the named sinking banner.
The fix reserves sinking feedback for the banner and hides other shot callouts
while it is active. The fresh recording verifies both isolation and no stale
callout after dismissal. A failed win-attempt annotation in the video describes
the gameplay result, not an application defect.

Animated preview (6.2 MB, 800 px wide, 5× speed):
https://app.devin.ai/attachments/712ee6af-5cf0-4cfb-b14d-b69e5fa55213/battleship-arcade-preview.webp
