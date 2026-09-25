# Lantern Parade — native validation

Native SwiftUI / Canvas app tested on macOS arm64, Xcode 26.6 (17F113), iOS 26.5.
Latest tested application revision: `d394699a74f231d89e62357a9faf47bfee4b4bcb`.
The latest report update changes documentation only.

## Build and automated checks

Executed from `native-games/ios/lantern-parade`:

```sh
xcrun swift-format lint --strict --recursive Sources Tests Scripts
xcodebuild -project LanternParade.xcodeproj -scheme LanternParade \
  -configuration Debug -sdk iphonesimulator -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project LanternParade.xcodeproj -scheme LanternParade \
  -configuration Release -sdk iphonesimulator -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project LanternParade.xcodeproj -scheme LanternParade \
  -destination 'platform=iOS Simulator,id=113E2F1A-A37A-4546-A7AE-8A9CA23C7F89' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
```

Results: strict format clean; Debug and Release **BUILD SUCCEEDED**;
**9 XCTest tests, 0 failures**, **TEST SUCCEEDED**. Builds also check Swift types.
For another machine, discover its simulator UUID with `xcrun simctl list devices available`.
No CI checks were configured/reported for the PR.

Tests exercise all twelve authored solutions, 31 deterministic daily variants,
ordered lanterns, gate/rooftop/square restrictions, crossing rejection, undo,
scoring, touch geometry and saved route/best-star persistence.

## Three rendered design passes

1. **Composition, identity and hierarchy — iPhone 17.**
   Replaced a solved gameplay-map home preview with a distinct illustrated
   festival vignette. Varied roof geometry, increased secondary type, made open
   gates visibly lift/widen, highlighted legal next streets, and replaced the
   generic share thumbnail with a rendered poster preview.
2. **Readability, animation and control feel — iPhone 17.**
   Exercised 5×5 and 6×6 play, taps and held drag, wrong gates/colors, tangle
   recovery, undo, clear, pause and procession. Hid completed-game controls.
   Fixed stale Guide text and explained guide-related star loss, including
   singular `1 GUIDE`. Verified actual artwork in native image sharing.
3. **Small/large fit and final edge cases — SE3 and iPhone 17 Pro Max.**
   Made Settings scroll with full prose; clipped scrolled content inside safe
   areas; tightened compact spacing. Real force-quit testing exposed a stale
   presentation flag: puzzle and restored route now travel together as one
   presentation value. A short held drag exposed a release-time button tap:
   drawing now takes priority over street-button taps. Both defects were
   reproduced, fixed and retested.

## Initial native UI verdict

No failures observed in the final iteration. SE forward drag retains Amber,
backward drag undoes once, ordinary taps and longer drags remain usable, and
force-quit/Continue restores the route. Compact 6×6 targets were sampled near
their edges. Prior regression checks verified replay, three-star clean
completion, saved best score and haptics preference.

Pro Max home, Settings, tutorial, gameplay, result and poster fit. Guide hides
after five seconds and restores the objective. Guided Indigo Steps completion
shows **20 steps, 0 missteps, 1 GUIDE, two stars** with accurate advice.
The native share sheet displays the poster thumbnail; no external recipient was
used. Pro Max score persists after force-quit. The app is left running on its
Pro Max home screen.

## Additional visual redesign following user review

The user approved the testing but requested a more distinctive, finished visual
identity. Revision `31d6979` replaced the procedural home vignette with an original
bundled AI-generated woodblock-style illustration. The redesign introduces
Baskerville roman/italic display type, a restrained petrol/cream palette,
ticket-shaped actions, fine engraved map frames and quieter navigation.
Native town art now has curved tiled roofs, timber facades, lit windows, hanging
banners, pines, clustered blossoms and ponds. Route lighting is softer, lantern
collection uses physical lantern illustrations, and result/share layouts become
cream collectible prints.

### Rendered review and correction

The first redesign review on Pro Max and SE found a cropped moon on compact
home, undersized secondary labels, faint atlas stars, excess poster whitespace,
and compact replay below the initial result viewport. Inspection also showed
square clipping around small lantern glows. Revision `d394699` corrected image
alignment and compact proportions, enlarged metadata and star marks, contained
the glow, tightened compact results and reduced poster height while enlarging
its secondary typography.

### Latest native UI verdict

No failures were observed in the scoped final test on SE3 and iPhone 17 Pro Max.
The full moon and bridge, wordmark, collection labels, compact result actions,
poster typography and all four poster borders were inspected in rendered
screenshots. Pro Max Settings and atlas fit; empty stars are more visible.

- SE mixed taps and held drag: First Light completed in 12 steps, zero missteps
  and zero guides, with three stars.
- Replay, one-step Undo and confirmed Clear passed.
- Pro Max 6×6 held drag retained 18 steps/all colors after release; completion
  produced 20 steps, zero missteps, one guide and two stars with accurate advice.
- Guide expired, re-enabled its button and restored the current objective.
- Pause → home → Continue restored the two-step Amber route and welcome notice.
- Native sharing showed the actual cream poster thumbnail and title; dismissal
  returned correctly. No external recipient was used.

The final original edited recording is `lantern-final-d394699-edited.mp4`, with
native setup, test-start and assertion annotations. The detailed runtime report
and full-screen compact/large screenshots are attached to the session.
The app is left running on the Pro Max home screen.

Debug and Release builds, strict formatting and all nine XCTest tests passed
again on this application revision using the commands above. No PR CI checks
were reported. This final redesign run did not repeat force-quit persistence,
compact 6×6, Daily Light or exhaustive recovery/all-town coverage. Tutorial fit
was verified at the immediately preceding redesign checkpoint; deeper
persistence/recovery evidence remains in the initial three passes.

## Evidence and limits

The final original edited Simulator recording, structured setup/test/assertion
timeline, full-screen home/gameplay/result/poster screenshots and detailed tester
report are attached in the
[Devin session](https://app.devin.ai/sessions/c19637f382b44c50b8ab43ef41498268).
The video was created with native Devin recording tools and computer interaction,
not a prerecorded showcase.

Simulator only: physical haptics, signed-device execution, external share delivery,
comprehensive VoiceOver/Dynamic Type checks and exhaustive target-frame
measurement were not validated. All authored towns are unit-tested for completion;
only representative towns received UI playthroughs. The game is intentionally
silent. No backend, online leaderboard, App Store upload or distribution signing.
