# Brickfolk shared rules

Pure Dart, with no Flutter dependency. This package contains protocol names,
player/avatar models, catalog, badges, rewards, chat filtering, deterministic
random generation and the authoritative Obby, Tycoon and Tag simulations used
by `../server`.

The native Apple client uses typed Swift wire models. Catalog and geometry
are exported by `../server/tool/export_apple_content.dart` into its content
bundle; gameplay snapshots and decisions still come from the Dart server.

```sh
dart pub get
dart format --output=none --set-exit-if-changed lib test
dart analyze --fatal-infos
dart test
```

Keep these deterministic simulation/protocol tests when changing clients.
See [../PROTOCOL.md](../PROTOCOL.md) for the wire contract.
