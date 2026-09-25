# Panic Pantry — network protocol

Panic Pantry uses a single authoritative server. Clients never simulate the
kitchen themselves: they send *intent* (movement, interact, action, dash,
emote) and render the snapshots the server broadcasts every tick. The same
`panic_pantry_core` package runs on the server and inside every client, so a
snapshot deserialises into the exact same `GameState` on web, iOS, Android
and macOS.

* Transport: WebSocket, text frames, one JSON object per frame.
* Endpoint: `ws://<host>:8787/ws` (`kDefaultPort = 8787`).
* Versioning: `kProtocolVersion = 1`. The client sends its version in `hello`;
  a mismatch produces an `error` with `code: "protocol"`.
* Simulation tick: `Rules.tickSeconds = 0.05` (20 Hz). The server runs the
  fixed-step loop and broadcasts one `game.snapshot` per tick; the room's
  `speed` multiplier only changes wall-clock pacing, never the simulation.
* Every message has a `type` string. Unknown types return
  `error {code: "unknown_type"}`.

Message-type constants live in `core/lib/src/protocol.dart` (`Msg`).

## Client → server

| `type` | Fields | Notes |
| --- | --- | --- |
| `hello` | `name`, `platform` (`web`/`ios`/`android`/`macos`), `protocol`, `token?` | First message on every socket. With a previously issued `token`, the server re-attaches the connection to the existing seat (reconnect/resume) even mid-match. |
| `ping` | `t` (client ms) | Answered with `pong`; the client uses it for the RTT badge. |
| `room.create` | `level?`, `code?`, `seed?` | Creates a room and joins it as host. Codes are 4 uppercase letters (no vowels/ambiguous glyphs). |
| `room.join` | `code` | Joins a lobby. Errors: `no_room`, `in_progress`, `full`. |
| `room.leave` | — | Leaves the room; server replies `room.state {room: null}`. |
| `room.ready` | `ready` (bool, default `true`) | Toggle ready. |
| `room.setLevel` | `level` | Host only. |
| `room.addBot` / `room.removeBot` | `id?` | Host only. Bots occupy real seats and run the deterministic core bot. |
| `room.start` | `force?` | Host only; requires everyone ready unless `force`. |
| `room.rematch` | — | Host only; returns everyone to the lobby with the same seats and an advanced match seed. |
| `input` | `dx?`, `dy?` (−1…1), `i?` interact, `a?` action, `d?` dash, `e?` emote index, `tx?`/`ty?` | The chef's intent for the *next* tick. Movement and `a` (a held button: chop/wash/spray progress accrues every tick it is on) are sticky until the next `input`; `i`/`d`/`e` are edge-triggered and consumed by one tick. `tx`/`ty` is the tile the client believed it faced when pressing interact (lag compensation for pickup/drop: the server honours it if the chef is adjacent). |
| `test.report` | `platform`, `screen`, `phase`, `tick`, `score`, `stars`, `results`, `rtt`, `automated`, … | Sent by the client in response to a `test.command {cmd: "report"}`. Stored per player and exposed on `GET /test/rooms/<code>`. |

## Server → client

| `type` | Fields | Notes |
| --- | --- | --- |
| `welcome` | `playerId`, `token`, `name`, `protocol`, `resumed`, `tickSeconds`, `levels[]` | Reply to `hello`. `levels` carries `id`, `name`, `tagline`, `gimmick`, `roundSeconds`, `menu[]`, `tutorial`. Persist `token` to resume later. |
| `room.state` | `room` or `null` | Full roster: `code`, `seed`, `speed`, `level`, `hostId`, `phase`, `match`, `tick`, `maxPlayers`, `players[]` (`id`, `name`, `slot`, `platform`, `ready`, `connected`, `bot`). Broadcast on any change. |
| `game.snapshot` | `code`, `state` | Authoritative kitchen state (below), every tick while a match runs. |
| `game.results` | `code`, `results`, `seed`, `match` | Sent once when the match finishes (and again on resume). |
| `pong` | `t`, `serverTime` | |
| `error` | `code`, `message` | `bad_json`, `no_hello`, `protocol`, `no_room`, `in_progress`, `full`, `code_taken`, `not_ready`, `not_host`, `unknown_type`, `internal`. |
| `test.input` | `steps[]` | Scripted input for automation (see below). |
| `test.command` | `cmd`, … | Automation command (see below). |

### Snapshot (`state`)

```jsonc
{
  "tick": 1234, "time": 61.7, "phase": "playing",        // lobby|countdown|playing|overtime|finished
  "countdown": 0, "timeLeft": 88.3, "overtime": 0,
  "score": 116, "combo": 2, "served": 4, "expired": 0,
  "tiles": { "3,1": { "i": { "t": "plate", "n": [], "k": false }, "p": 0.4, "f": 0 } },  // sparse: only tiles with dynamic state (item, progress, conveyor offset, fire)
  "movers": [[ /* tile row for each conveyor / moving platform */ ]],
  "offsets": [0.25],                                     // mover offsets in tiles
  "chefs": [{ "id": "pabc", "s": 0, "n": "Webby", "b": false, "x": 3.5, "y": 2.5, "f": 1,
              "h": { "t": "ing", "i": "tomato", "c": true }, "w": true, "e": 2 }],
  "orders": [{ "id": 7, "d": "tomatoSoup", "r": 31.2, "u": 60 }],
  "events": [{ "k": "served", "x": 7, "y": 0, "c": "pabc", "v": 28 }]   // one-shot effects since last tick
}
```

The static layout (walls, counters, stations, conveyor directions, mover
tracks) comes from the level definition shared through `panic_pantry_core`,
so snapshots only carry what changes. Item encoding (`items.dart`), `t`:
`ing` (`i` ingredient, `c` chopped), `pot` (`n` contents, `k` cook 0…1, `b`
burn 0…1, `x` burnt), `plate` (`n` contents, `k` cooked), `stack` (`c` count,
`d` dirty) and `ext` (fire extinguisher). Chef fields: `s` slot, `n` name, `b`
bot, `f` facing, `h` held item, `d` dash timer, `w` working at a station, `e`
emote index, `off` disconnected.

### Results

```jsonc
{ "levelId": "corner-cafe", "score": 316, "stars": 1, "thresholds": [260, 420, 600],
  "served": 10, "expired": 1, "tips": 116, "bestCombo": 4, "wrongServes": 0,
  "burntPots": 0, "servedByDish": { "tomatoSoup": 6, "onionSoup": 4 }, "players": 4, "tick": 3061 }
```

The automated test compares `score`, `stars`, `served`, `tips`, `expired`,
`bestCombo`, `wrongServes` and `burntPots` across every client and the server.

## Match lifecycle

```
hello ──► welcome ──► room.create / room.join ──► room.state (lobby)
   room.ready ×N ──► room.start ──► game.snapshot (countdown 3 s → playing → overtime 5 s)
   ──► phase "finished" + game.results ──► room.rematch ──► room.state (lobby, match+1)
```

* Seed: `matchSeed = room.seed + match * 7919`; every order, hazard and bot
  decision derives from it, so a seed + input script replays exactly.
* Reconnect: a client that drops keeps its seat (`connected: false`, chef
  greyed out). Reconnecting with the same `token` resumes, receives the
  current snapshot and, if the match ended meanwhile, the results.
* Rooms with no connected players expire after five minutes.

## Automation / test channel (HTTP)

The server can also expose a small JSON HTTP API used by
`test/native-integration.sh` (also available as `test/multiplayer-e2e.sh`). It is served on the
same port, is unauthenticated, and is therefore **off by default**: start the
server with `--test-harness` (or `PP_TEST_HARNESS=1`) to mount the `/test/*`
routes. Without the flag they answer 404. `/health` and `/levels` are always
available.

| Method & path | Body | Purpose |
| --- | --- | --- |
| `GET /health` | | `{ok, rooms, protocol}` |
| `GET /levels` | | Level catalogue |
| `GET /test/rooms` | | All rooms |
| `POST /test/rooms` | `{code?, seed?, level?, speed?, bots?}` | Create a room with a fixed code/seed (409 if taken) |
| `GET /test/rooms/<code>` | | Room roster plus `reports` (last `test.report` per player), `results` and the current `state` |
| `POST /test/rooms/<code>/start` / `/rematch` | | Start / rematch without a host |
| `POST /test/rooms/<code>/bots` | `{count}` | Add server bots |
| `POST /test/rooms/<code>/players/<id>/input` | `{via, steps[]}` | Scripted inputs. Each step is an `input` payload plus `ticks` (repeat count). `via: "client"` (default) forwards them as `test.input` so the client feeds them through its own input pipeline; `via: "server"` applies them on consecutive ticks server-side. |
| `POST /test/rooms/<code>/players/<id>/command` | `{cmd, …}` | Forward a `test.command` to one player, or to everyone with `id = *` |
| `DELETE /test/rooms/<code>` | | Remove a room |
| `GET /test/clients` | | Every open socket: player `id`, `name`, `platform`, current `room` code (or null) and last `report` — reaches clients that are connected but not seated |
| `POST /test/clients/<id>/command` | `{cmd, …}` | Forward a `test.command` to one connection regardless of room membership |

Supported `test.command` values handled by `GameClient`: `report`,
`ready {ready}`, `start`, `rematch`, `addBot`, `setLevel {level}`,
`emote {index}`, `clearInput`. The app layer additionally handles
`theme {mode: light|dark|system}`, `join {code}`, `host {level?}`, `leave`,
`howto` (opens the How-to-play sheet) and `dismiss` (pops it). Anything else
is surfaced through `GameClient.commands`.

The native implementation is in `apple/Sources/PantryKit/`. Swift `Codable`
models preserve these message names and compact keys. `hello` explicitly
includes protocol `1`. Inputs use the same held-versus-edge semantics, and
resume tokens are stored in the device Keychain. `test.command` handling
also supports native theme, help-sheet, host/join/leave and report state.
The former browser viewport/pixel-ratio report extensions are historical
visual-harness metadata and are not part of native protocol validation.

`server/bin/plan.dart` runs the shared simulation headlessly with the core
bots on every seat, records the inputs of the seats that will be driven by
real clients, and prints the expected results; the E2E harness queues those
inputs and asserts every platform reports the same numbers.
