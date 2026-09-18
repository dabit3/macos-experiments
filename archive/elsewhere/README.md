# Elsewhere

![Elsewhere screenshot](screenshots/elsewhere.jpg)

A native, offline iPhone travel scrapbook. Cream paper, cobalt passport stamps,
original procedural destination illustrations and vermilion journal details.

## Features

- Three clearly labeled sample journeys, plus create, edit and delete your own.
- Dated stops with notes, optional photo import, favorites and custom ordering.
- A journal timeline and a decorative route diagram that works without map tiles.
- Real 1200 × 1760 postcard images rendered locally, inspectable with zoom
  controls and shared/saved through the native iOS share sheet.
- Local persistence across launches. Photos are resized to at most 1600 px and
  stored as JPEGs inside the journal; no accounts, network requests or API keys.
- Original app icon and three original SwiftUI Canvas illustrations.

## Open and run

Requires Xcode with an iOS 17+ SDK. Verified tool versions and final QA results are
included in the delivery report. The generated project and shared scheme are
committed, so no package manager is needed to run:

```sh
open Elsewhere.xcodeproj
```

Select the Elsewhere scheme and an iPhone simulator. Code signing is disabled
for simulator builds. For a physical device, configure your own development team
and signing settings.

If changing the project configuration, regenerate with XcodeGen:

```sh
brew install xcodegen
xcodegen generate
```

## Build, test and lint

Run from this directory:

```sh
xcodebuild -project Elsewhere.xcodeproj -scheme Elsewhere \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build build CODE_SIGNING_ALLOWED=NO
xcodebuild -project Elsewhere.xcodeproj -scheme Elsewhere \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build test CODE_SIGNING_ALLOWED=NO
xcrun swift-format lint --recursive --strict Sources Tests Tools
```

Regenerate the original icon, if needed:

```sh
swift Tools/GenerateIcon.swift Assets.xcassets/AppIcon.appiconset/Icon.png
```

## Controls and data

Begin a journey from the library. Open it, then add stops. Tap any stop to read,
favorite, edit or make a postcard. The ellipsis menu edits/deletes journeys and
opens stop ordering; arrow buttons move a stop immediately. The Journal/Route
switch changes presentation without changing order or dates. Saved collects all
favorited stops. The passport button explains storage and can restore sample
journeys without touching personal journals.

Journey and memory actions stay above the bottom safe area. Postcards have a
larger inspection view with pinch, double-tap and labeled zoom/reset controls.
Sharing creates a named PNG file in a unique cache folder and passes its file URL
to the native share sheet. The file remains available until the sheet dismisses,
then its export folder is removed. Saved copies remain in Files or Photos.
Type follows system settings; decorative labels cap their growth while titles,
notes and controls remain scalable. At accessibility sizes, illustrations shrink
to give text more room. There are no essential animated transitions.

Forms save only after tapping Save; Cancel discards drafts. Empty names cannot
be saved. Deletion asks for confirmation. Notes have a 4,000-character limit;
place/journey names and region labels have an 80-character limit.

The journal is stored atomically as JSON in the app's Documents/Elsewhere folder.
A read failure leaves the original file untouched and blocks further writes
instead of silently overwriting it. Deleting the app deletes the journal.

## Scope and limitations

- Sample journeys are fictional examples. Illustrations are not imported photos.
- Routes are clearly labeled diagrams of stop order, not geographic maps.
  The diagram marks the first five stops; the full ordered list includes all.
- Offline photo import requires the chosen photo to be available on the device.
- No cloud sync, account, geocoding, navigation or full-journal backup import.
- Postcards include an excerpt of up to 220 note characters.
- Portrait iPhone V1; no physical-device or App Store signing/approval claim.
