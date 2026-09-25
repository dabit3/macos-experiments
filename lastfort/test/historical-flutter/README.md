# Historical Flutter harness

These files are retained as evidence of the former web/iOS/Android/macOS
Flutter test workflow. They are **not supported launch instructions** and
cannot run against the native application. The superseded Flutter client,
including its framework-specific widget tests, has been removed.

The active `../multiplayer-e2e.sh` exercises native Swift Codable and
URLSession WebSocket clients against the real, unchanged Dart simulation.
Native model, persistence, world-generation and protocol tests live in
`../../apple/Tests/LastfortKitTests`. Existing Dart core/server tests remain
unchanged. Native UI/visual regression checks require separate device testing.
