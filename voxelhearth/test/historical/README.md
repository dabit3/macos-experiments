# Historical Flutter evidence

These unchanged scripts and widget tests document the retired Flutter client.
They require the application at commit
`f58c20454ae9a930bf72e2eae4d574445a829c4f` and its original directory layout;
they are not active native launch commands or evidence of native UI parity.

The original server/rules tests remain active under
`packages/voxelhearth_core/test/`. Native XCTest suites are in
`apple/Core/Tests/` and `apple/Tests/`. Run `../multiplayer-e2e.sh` for the
current Swift-to-Dart protocol integration without browser automation.

The old synthetic fixture/layout/screenshot comparison drivers have no native
equivalent. Native diagnostics operate only on the live client, with
`VH_TEST=1` and a server started with `--test-mode`.
