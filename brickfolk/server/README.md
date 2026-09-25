# Brickfolk server

The authoritative Dart server is shared by the native macOS, iPhone and iPad
clients. It owns identities, social state, room lifecycle, simulation,
results/checksums and SQLite persistence. Requires Dart 3.13.3 or newer.

```sh
dart pub get
dart run bin/server.dart --port 8080 --db brickfolk.sqlite
curl http://localhost:8080/health
```

Connect native clients to `ws://<server>:8080/ws`. Use `--host 127.0.0.1` for
local-only development; the default `0.0.0.0` permits same-LAN devices.

For isolated protocol tests:

```sh
dart run bin/server.dart --host 127.0.0.1 --port 8088 --db :memory: \
  --test-mode --seed 73 --match-length-scale 0.08 --results-ms 1000
```

Test mode exposes `/test/state` and `/test/control` and uses a fixed clock.
Do not enable it on a public service. Normal clients need only `/health` and
`/ws`. Terminate TLS in a reverse proxy to offer `wss://`.

```sh
dart analyze --fatal-infos
dart test
# Bundles SQLite's native library through Dart build hooks:
dart build cli -o build/cli
```

`tool/export_apple_content.dart` exports shared definitions into the checked-in
Swift resource; run it after changes to the catalog, rewards or world geometry.
See [the main README](../README.md) and [protocol](../PROTOCOL.md).
