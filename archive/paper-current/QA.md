# Paper Current — native QA and design review

## Environment and automated checks

Verified on macOS arm64 (Darwin 25.5.0), Xcode 26.6 (17F113), iOS 26.5 Simulator.
No credentials, signing, servers or third-party packages are required.

Run from `native-games/ios/paper-current`:

```sh
xcrun swift-format lint --strict -r Sources Tests Tools
xcodebuild -project PaperCurrent.xcodeproj -scheme PaperCurrent \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project PaperCurrent.xcodeproj -scheme PaperCurrent \
  -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project PaperCurrent.xcodeproj -scheme PaperCurrent \
  -destination 'platform=iOS Simulator,id=691C57A7-98F5-4C32-A5AF-3074F4F0FBA3' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
```

All four commands passed on revision `1129f8c` and were rerun successfully for
the visual redesign on `ae5a873` and final app revision `bd7d12c`. Each test run
executed five tests with zero failures. Build checks include Swift typechecking. Use
`xcrun simctl list devices available` to choose a different local test UUID.

The tests verify ten contiguous, stamp-complete solvable routes; unsolved initial
boards and hint solvability; distinct closed-lock and reversed-current failures;
rotation/lock undo and move counts; and persistent minimum scores/sequential
unlocking. This is automated all-level verification, not a claim that every level
was played manually. The repository currently has no PR CI checks.

## Three visual review passes

### 1. Composition, hierarchy and identity

Inspected native home, gameplay, failure and result screens. Retained the
paper-cut town, folded boat, canal blues, parchment postcard and vermilion actions.
Observed dark status icons against the dark background, dimmed noninteractive
canals, and a generic share preview.

Changed status appearance to light icons, explicitly kept modal sheets light,
replaced disabled styling on display-only boards with hit testing, added a
red failure endpoint, and supplied postcard image metadata to the native share
sheet. Added move/stamp counts to the exported card.

### 2. Gameplay readability, motion and controls

Verified level-two locks separately from rotation, undo restoring the lock and
zero moves, reset, closed-lock failure, pause, background/resume, five-move
delivery, three seals and replay. Native Save to Files produced a PNG; opening
it in Files/Preview showed the complete postcard.

Observed a blank SpringBoard icon, sideways boat travel and implicit reset
cancellation. Fixed both icon generation and asset-catalog inclusion; oriented
the boat to its travel segment and added gold stamp particles. A cancel action
inside the system confirmation dialog remained hidden on the tested runtime;
replaced that presentation with an alert containing visible **Keep planning**.

### 3. Small/large-screen fit and edge cases

Tested iPhone 17 Pro Max and a dedicated iPhone SE (3rd generation), 375×667 points.
Confirmed the reset cancellation preserves the plan and reset restores zero
moves. Played level three with one hint and manual edits, deliberately reversed
a current, received the correct failure, undid the edits, delivered, replayed,
shared and relaunched. Real Pro Max progression reached 3/10 with best eight moves
and letter four unlocked.

Native motion frames confirmed north/south boat orientation and gold particles.
Reduce Motion produced discrete travel, no spreading particles and static home
artwork; successful delivery still worked. Restored Reduce Motion to off.
Correct app icons appeared on both devices.

For isolated SE layout coverage, the first five completed letters were seeded
on that device only. Letter six was then actually delivered with five hints.
Its 5×5 board, postcard, lower actions and native sharing were reachable with
vertical swipes. This fixture does not demonstrate real progression through
letters one through five.

Final screenshot inspection found scrolled SE content behind status text and
singular hint wording. Added explicit clipping to gameplay/results scroll views
and corrected the one-hint label. Final targeted native verification follows
these changes: held swipes retained the solid status strip, lower actions remained
reachable, and real Pro Max replay/delivery/share showed **8 moves · 1 hint**.
No blocking defects remained in that recheck. The app was left open at the real
Pro Max letter-three result.

## Evidence and scope

### Second visual direction — the Rainwater Post

The user accepted the original testing but requested a more authored visual
design. Reworked the home around a locally bundled papercraft harbor illustration,
Baskerville roman/italic typography and a fictional Rainwater Post identity.
Replaced generic red buttons and circular icon surfaces with cream letterpress
controls, restrained vermilion seals and quieter navigation. Collection, help and
settings now use matching paper sheets. Gameplay received layered paper banks,
more detailed native houses, foliage, lamps, a drawn postbox, perforated stamps,
brass lock latches and visible canal rotation. The collectible postcard uses a
destination title, numbered postal seal and a finer typographic hierarchy.

#### Rendered review and refinement

Native review of `ae5a873` on Pro Max verified home, settings, collection/help,
rotation wrap endpoints (3→0), Undo, both reset choices, real letter-three
delivery, replay and native share thumbnail. The SE3 screenshot exposed hard
vertical edges around the Harbor image. A blank-middle collection-row tap also
failed during that review; tapping its label worked. Screenshot inspection showed
overly heavy board shadows and visibly aligned paper-grain dots.

Fixed the image mask to fade all four edges of the fitted artwork, expanded
transparent row hit areas, composited the board before applying a softer shadow,
and distributed quieter paper fibers with deterministic irregular spacing and
area-based density.

#### Final native recheck — `bd7d12c`

The final 103-second native recording includes structured setup, named tests and
assertions. Pro Max and SE3 both show smoothly blended artwork and responsive
blank-middle collection taps. Compact settings, all five help sections and
collection rows remain readable. Empty chapter-row space and the close-control
edge respond. The final screenshots confirm softer board shadows and irregular
paper grain.

Real Pro Max letter-three replay delivered at **8 moves · 1 hint**, two seals.
The isolated SE3 level-six fixture delivered its 5×5 route at **5 moves · 5 hints**,
one seal. Its 6/10 count is fixture-derived; genuine Pro Max progression remains
3/10. Compact postcard/lower actions remain reachable, held scrolling preserves
the clear status strip, and native sharing displays the redesigned thumbnail.
Brief Reduce Motion navigation/canal/Undo checks passed; the setting was restored
to off. No new blocking UI defects were observed, and Pro Max was left running at
the real letter-three postcard.

This recheck does not claim fresh PNG export, all-ten-level manual play,
exhaustive motion analysis, VoiceOver announcements or hardware verification.
Unchanged mechanics retain the earlier native coverage plus rerun rule tests.

- [Final native redesign report](https://app.devin.ai/attachments/8a09cc3b-a7f5-4b54-857d-b92583733de2/paper-current-bd7-report.md)
- [Pro Max home](https://app.devin.ai/attachments/c1fd4ada-2fc1-4a50-a2e1-c1b490bb21a7/paper-bd7-home-promax.png)
- [Gameplay](https://app.devin.ai/attachments/d4b3adb1-c13f-4bac-826b-a0c2f0af5618/paper-bd7-gameplay-promax.png)
- [Delivered postcard](https://app.devin.ai/attachments/460ced24-bbc6-40e2-a231-ab172be75fb2/paper-bd7-result-promax.png)
- [SE3 home](https://app.devin.ai/attachments/4a9c2c1a-13b1-464b-99eb-2b15f842f857/paper-bd7-home-se3.png)

### Prior implementation evidence

The session delivers the original edited native recording and its structured
setup/test/assertion timeline, native screenshots and the consolidated GUI report:
https://app.devin.ai/sessions/17300d2b2e474160be14ddf7269aa8a2

- [Consolidated GUI report](https://app.devin.ai/attachments/9c8af877-3d01-4467-b6be-8930c138e51c/paper-current-final-report.md)
- [Home](https://app.devin.ai/attachments/9a58af51-5013-43a9-ae29-435c0afd090a/paper-1129-home-promax.png)
- [Gameplay](https://app.devin.ai/attachments/86313a2d-04fa-48df-8f14-299f5f6deee7/paper-1129-gameplay-promax.png)
- [Delivered postcard](https://app.devin.ai/attachments/11e8d69d-8365-4965-9b1c-edbe351c9d01/paper-1129-result-promax.png)

Build outputs and recordings are intentionally excluded from git. The native
recordings show actual Simulator interaction; supplemental motion captures were
used only to inspect frames, not as substitutes for annotated computer use.

## Remaining limits

- Portrait iPhone V1; SE layouts use scrolling to preserve readable controls.
- Tide is a per-step route budget, not a real-time planning deadline.
- Completed progress/best moves persist; unfinished plans restart after termination.
- No cloud sync, online leaderboard, daily challenge or external service.
- Simulator cannot validate physical haptics/audio, signed distribution or
  delivery through third-party sharing destinations.
- Accessibility labels/identifiers are supplied and Reduce Motion was exercised;
  this is not a complete VoiceOver/Dynamic Type audit.
