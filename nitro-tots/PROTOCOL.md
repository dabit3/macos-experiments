# Nitro Tots network protocol (v1)

JSON messages over a single WebSocket (`/ws`). Every message is an object with a
`type` field. The server owns the race state; clients send intent (profile,
readiness, per-tick input) and render authoritative snapshots with local
prediction and interpolation. All four clients (web, iOS, Android, macOS) and the
server share the same Dart simulation in `packages/nitro_core`, so a snapshot
applied on any platform produces identical state.

The protocol version is `protocolVersion = 1` in
`packages/nitro_core/lib/src/protocol.dart`; message names live in the `Msg`
class there. Unknown message types are answered with an `error`.

## Transport and HTTP endpoints

| Endpoint        | Method | Purpose                                                       |
| --------------- | ------ | ------------------------------------------------------------- |
| `/`             | GET    | `{name, protocol, rooms}`                                     |
| `/health`       | GET    | `{ok: true, uptimeMs}` liveness probe                         |
| `/rooms`        | GET    | Inspect all rooms (players, status, per-player test reports)  |
| `/rooms/<code>` | GET    | Inspect one room; `404 {error: "no_such_room"}` if missing    |
| `/ws`           | WS     | Game channel                                                  |

Defaults: `ws://localhost:8787/ws`. The Android emulator reaches the host at
`ws://10.0.2.2:8787/ws`. CORS is open so the web build can connect from any
origin.

## Session lifecycle

```
client                                server
  |-- hello {name,character,kart,platform,v} -->|
  |<-- welcome {playerId,token,serverTime,v} ---|
  |-- create_room {settings?} / join_room {code} -->|
  |<-- room_state ... (broadcast on every change)   |
  |-- set_ready {ready:true} -->|
  |-- start_match (host) ------>|
  |<-- match_start {trackId,seed,racers,...} ---|
  |<-- snapshot (every 2nd tick, 15 Hz) ---------|
  |-- input {tick,t,s,d,i,b} (every tick, 30 Hz) -->|
  |<-- race_finished {results,standings,nextInMs}|
  |   ... repeats per Grand Prix race ...        |
  |<-- match_over {standings,races,hash} --------|
```

Reconnect: keep `playerId` + `token` from `welcome`; on a new socket send
`resume {playerId, token}` instead of `hello`. The server re-sends `welcome`
(`resumed: true`), the current `room_state` and, if a race is running,
`match_start` so the client can rebuild its local sim and resume from the next
snapshot. A disconnected racer keeps driving under bot control until it resumes
or the race ends.

## Client → server

| type              | fields                                                                                                             |
| ----------------- | ------------------------------------------------------------------------------------------------------------------ |
| `hello`           | `name` (≤14 chars), `character` id, `kart` id, `platform` (`web`/`ios`/`android`/`macos`), `v` protocol version    |
| `resume`          | `playerId`, `token`                                                                                                |
| `create_room`     | optional `code` (4–6 chars, upper-cased) and `settings` (partial `RoomSettings`)                                    |
| `join_room`       | `code`                                                                                                             |
| `leave_room`      | –                                                                                                                  |
| `set_ready`       | `ready` bool                                                                                                       |
| `update_profile`  | any of `name`, `character`, `kart`                                                                                 |
| `update_settings` | host only; partial `RoomSettings` merged into the room                                                             |
| `start_match`     | host only; requires ≥ `max(2, minPlayers)` connected, ready humans (bots fill the rest)                            |
| `next_race`       | host only; skips the results countdown between Grand Prix races                                                     |
| `input`           | `tick`, `t` throttle −1..1, `s` steer −1..1, `d` drift (1), `i` item (1), `b` look back (1). Absent flags mean 0.   |
| `ping`            | `t` client time; answered with `pong`                                                                              |
| `test_report`     | free-form; stored per player and exposed via `/rooms/<code>` for the automated cross-platform test                 |

Item presses are buffered until the next simulation tick on both the client
and server. A newer steering packet does not erase a pending `i:1`; consuming
it clears only the item flag. Throttle, steering, drift and look-back retain
their latest values. Multiple item presses received within one tick coalesce.

`RoomSettings` (all optional on the wire, defaults shown):

```json
{
  "mode": "race",          // race | battle | timeTrial
  "cupId": "sugar",        // sugar | nitro (Grand Prix track list)
  "trackId": "sprinkle",   // single-race track
  "laps": 3,
  "maxPlayers": 8,
  "minPlayers": 2,
  "fillBots": true,
  "botSkill": 0.7,
  "grandPrix": true,
  "battleSeconds": 120
}
```

## Server → client

| type            | fields                                                                                                                   |
| --------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `welcome`       | `playerId`, `token`, `serverTime`, `v`, `resumed?`                                                                       |
| `error`         | `code`, `message`. Codes: `not_host`, `already_racing`, `room_full`, `match_in_progress`, `no_such_room`, `no_room`, `not_in_results`, `resume_failed`, `unknown_type` |
| `room_state`    | `code`, `hostId`, `status` (`lobby`/`racing`/`results`), `settings`, `players[]`, `raceIndex`, `totalRaces`, `standings[]` |
| `player_left`   | `playerId`                                                                                                               |
| `match_start`   | `code`, `raceIndex`, `totalRaces`, `trackId`, `seed`, `laps`, `mode`, `battleSeconds`, `tick`, `racers[]`               |
| `snapshot`      | see below                                                                                                                |
| `race_finished` | `raceIndex`, `totalRaces`, `trackId`, `results[]`, `standings[]`, `nextInMs`, `isLast`                                   |
| `match_over`    | `standings[]`, `races[] {trackId, results[]}`, `hash`                                                                    |
| `pong`          | `t` (echoed), `serverTime`                                                                                               |

`players[]` entries: `{id, name, character, kart, platform, ready, connected,
host, slot, bot}`. `racers[]` in `match_start`: `{slot, playerId, name,
character, kart, bot, platform}` — slot order is the deterministic start grid.

### Snapshot

Sent every other simulation tick (30 Hz sim → 15 Hz network). Field names are
short to keep 8-racer snapshots small.

```json
{
  "type": "snapshot",
  "tick": 1234,
  "phase": "racing",                 // countdown | racing | finished
  "racers": [ { "s": 0, "x": 12.3, "y": 4.5, "h": 1.57, "v": 8.2, ... } ],
  "proj":   [ { "id": 7, "k": "rocket", "o": 2, "x": .., "y": .., "h": .. } ],
  "drop":   [ { "id": 9, "x": .., "y": .., "o": 3 } ],
  "boxes":  [ 3, 5 ],                // item boxes currently respawning
  "mov":    [ { "x": .., "y": .. } ],// moving hazards
  "events": [ { "e": "lap", "r": 0, "v": 2 } ],
  "ack":    { "0": 1230 },           // last input tick applied per slot
  "left":   0                        // battle seconds remaining
}
```

Racer wire fields (`racerToWire` in `protocol.dart`) cover position, heading,
speed, lap, checkpoint, progress, item, boost/drift state, balloons and score.
The client applies the snapshot for remote karts with interpolation and, for the
local kart, re-simulates unacknowledged inputs after `ack[slot]` (reconciliation).

### Results, points and hash

`results[]` entries: `{slot, name, character, kart, bot, platform, place,
finishTick, lapTicks[], points, score}`. Points per place: `15, 12, 10, 9, 8,
7, 6, 5`. Grand Prix `standings[]` accumulate points across races and are
ordered by points, then best places, then slot: `{slot, name, character, kart,
bot, platform, points, places[]}`.

`match_over.hash` is a stable digest of every race's results (`resultHash()` in
`packages/nitro_server/lib/src/room.dart`). The native headless integration test
(`test/multiplayer-e2e.sh`) compares two clients' authoritative results and
hashes, submits a `test_report`, then exercises rematch and leave. Native apps
launched with `NT_TEST=1` report the hash and standings at match completion;
`test/verify_room.py` compares those reports with the server.

## Determinism

The server is started with `--seed`; room codes and race seeds derive from it.
The simulation runs a fixed 30 Hz step with seeded RNG, integer ticks and
deterministic bots, so the same seed + inputs reproduce the same race on every
platform.
