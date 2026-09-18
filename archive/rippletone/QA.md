# Rippletone — V1 design and QA

## Native environment

- macOS arm64; Xcode 26.6 (17F113); iOS 26.5 Simulator.
- iPhone 17 Pro Max: 440×956 points / 1320×2868 pixels.
- iPhone SE (3rd generation): 375×667 points / 750×1334 pixels.
- Final app source revision: `1daac66f1bd14ff921821e321ce8bc9212b626c4`.
- PR: https://github.com/dabit3/experiments/pull/112

## Build and automated checks

Run from this directory:

```sh
xcrun swift-format lint --strict --recursive Rippletone Tests Tools
xcodebuild -project Rippletone.xcodeproj -scheme Rippletone \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Rippletone.xcodeproj -scheme Rippletone \
  -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Rippletone.xcodeproj -scheme Rippletone \
  -destination 'platform=iOS Simulator,id=691C57A7-98F5-4C32-A5AF-3074F4F0FBA3' \
  -derivedDataPath .build \
  -resultBundlePath /Users/devin/rippletone-tests.xcresult \
  CODE_SIGNING_ALLOWED=NO test
```

Both final simulator configurations and strict formatting passed. Builds also
typecheck Swift. XCTest reported **10 tests, 0 failures** for timing boundaries,
wrong-lane/duplicate input, expiration, combo, perfect phrases, scoring/coverage,
three escalating patterns, failure, Codable results and settings persistence.
The rules/state code did not change during subsequent presentation fixes.
Replace the recorded simulator UUID with an available device when reproducing.

## Initial three visual review passes

### 1. Composition and hierarchy

Reviewed the native home, three composition rows, held-target tutorial, playfield,
combo, pause and return home. The weakest details were small secondary text,
competing tutorial actions, distant judgement feedback and ambiguous progress.

Changed tutorial completion/skip hierarchy, increased secondary contrast, moved
judgements beside their lily, labelled note progress and bloom requirements,
strengthened target outlines, differentiated decorative lilies, and protected
the top HUD from moving pond artwork.

### 2. Play feel and performance presentation

Played First light using real scheduled mouse events against the Simulator:
12 Perfect, 100% accuracy and best combo 12. Reviewed celebration, results,
replay, persisted bloom progress and native image export.

The first cold-process share sheet was blank; the export rank crossed the koi,
and phrase text crossed the celebration. Replaced independent Boolean/image
share state with one complete item-backed payload, a PNG item provider and
native title/image metadata. Repositioned export art above the statistics,
added explicit Accuracy labels, protected celebration text, and made compact
results scroll to keep replay/share reachable.

### 3. Small/large screens, edge cases and final recording

Reviewed SE3 and Pro Max. SE3 verified settings across cold relaunch, automatic
background pause, resume, restart, untouched 0% / 12-missed results and replay.
The first cold-process share presentation was populated with the correct title
and card thumbnail. Save to Files produced the descriptive filename and
800×1440 artwork with separated rank/koi and the performance message.

The remaining 2–6pt tutorial target movement came from a 44pt Skip footer versus
52pt Play footer. Both now reserve 52pt; the final simulator review confirmed
stable target positions. A final native recording was captured with setup,
test-start and passed-assertion annotations plus computer-use actions.

## Additional art direction and native review

### 1. Illustrated nocturne collection

Replaced broad fish silhouettes and boxed rows with patterned koi, translucent
etched fins, botanical lily contours, broken moon arcs and subtle water flow.
Baskerville display/italic type, a ripple seal and chart-derived rhythm signatures
provide a consistent identity. Home, results and the framed performance print
reserve dedicated illustration space; the icon uses the same procedural artwork.
Timing, compositions, scoring, persistence and native share architecture remain
unchanged.

Native review of `b07dd4c` revealed that the copper tail clipped on SE3 and
crossed the home caption on Pro Max. The tail root also looked pinched.

### 2. Complete artwork bounds

Sized the hero using the complete koi envelope, moved its caption into a separate
layout band, and widened the tail roots. Review of `5619d15` confirmed full tails,
clear caption spacing and working tutorial/results/share on both sizes. Both
real-input First light attempts scored 12 Perfect / 100%; actual native exports
were 800×1440 with intact padding.

The SE3 celebration exposed the next weak detail: bright koi could pass behind
local gold judgement text and remain visible through targets.

### 3. Feedback protection and final native recording

Added opaque ink behind target-local feedback and inside timing targets.
Softened the tail junction pigment/stroke and rendered small eyes at their final
size. Regenerated the matching opaque 1024×1024 icon.

Final source `1daac66` passed strict Swift-format lint and Debug/Release simulator
builds. The redesign XCTest run passed 10 tests, 0 failures; subsequent changes
were limited to presentation.

Final SE3 preflight confirmed protected feedback during a 12 Perfect / 100% run.
The Pro Max recording covered all three tutorial lilies, a genuine perfect run,
celebration, populated first-share presentation, native Save to Files, an honest
0% / 12-missed replay, retry and return home with the best preserved. Exported PNG
was 800×1440 with separated illustration, rank and statistics. Both home layouts
fit; the app was left running on both Simulators.

The original native recording contains one setup, four test starts, nine passed
assertions and thirteen control-action entries. Scheduled native mouse events
were real game input; the individual timed note clicks are not separately listed
in the native action timeline. The edited video is 40.67 seconds at 1600×1200.
Fine fin etching and decorative captions remain subtle on SE3.

[Detailed final redesign report](https://app.devin.ai/attachments/d10a5e3d-99e4-490c-bf42-1b391aa0a200/report.md)

## Evidence and limitations

The session contains the final native annotated recording, full-screen
screenshots, exported artwork and the detailed tester report:
https://app.devin.ai/sessions/43057c7b50474887a44b020493e5f15b

The video is a real Simulator interaction run, not a prerecorded game mode.
Timed mouse events provide genuine input; no saved result was injected to
produce success. Small-device edge checks also include unrecorded preflight
coverage, distinguished in the detailed report.

No physical iPhone was used. Audio/haptic feel, calls and device interruptions,
App Store signing, iPad and landscape are unverified or outside V1. Simulator
AVAudio route warnings appeared during XCTest but did not fail tests. This
visual rhythm game does not claim nonvisual VoiceOver gameplay or dynamic-type
layout scaling.
