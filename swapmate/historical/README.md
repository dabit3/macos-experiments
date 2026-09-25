# Historical Flutter artifacts — inactive

This directory preserves tests, harness tools and the README from the
superseded Flutter client. Their original runtime/import paths no longer
exist; do not use these files as current setup or validation instructions.
Restore the pre-migration Git revision to reproduce a historical run.

`flutter-tests/` retains all four former Flutter client tests unchanged.
`flutter-harness/` retains the old browser/Android/four-platform scripts and
pixel comparison tooling. `FLUTTER-README.md` describes that retired setup.
Existing `.devin/clone-this/` manifests and evidence elsewhere under Swapmate
also refer to the historical Flutter application and do not establish native
SwiftUI parity.

Current Apple build/run/test commands are in [`../README.md`](../README.md).
