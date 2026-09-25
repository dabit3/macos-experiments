# Gambit Court wire protocol (v1)

Gambit Court clients talk to one authoritative server over a single WebSocket.
Every frame is a UTF-8 JSON object with a `type` field. The server owns the
rules, the clocks and the room roster; clients never apply a move locally until
the server echoes it back inside a `room_state` snapshot.

The Dart definitions live in
`packages/gambit_court_core/lib/src/protocol.dart` and are shared verbatim by
the server. The native Apple client has equivalent typed Codable models in
`apple/Sources/CourtCore/Protocol.swift`.

```
ws://<host>:8765/ws        game protocol (JSON text frames)
GET  /health               {"ok":true,"clients":n,"rooms":n,"serverTimeMs":…}
GET  /rooms                public room listings (same shape as `rooms.rooms`)
/control/…                 test-automation bridge, only with `--control`
```

## Conventions

* Colours are `"w"` / `"b"`. Squares and moves use UCI (`e2e4`, `e7e8q`).
* Times are integer milliseconds. `serverTimeMs` is the server's monotonic
  wall clock; in `--frozen-clocks` mode it only advances via the control API.
* Every message the server sends about a room carries the full
  `RoomSnapshot`, never a delta. Snapshots have a monotonically increasing
  `seq`; clients drop anything older than what they hold.
* Errors are never fatal unless `fatal: true` is present; the connection stays
  open and the client keeps its last snapshot.

## Handshake

The first frame on a fresh socket must be `hello`. The same `clientId`
re-attaches to the same session (and therefore the same room) after a
reconnect; a second live socket with the same id evicts the first one with a
`fatal` `error`.

```jsonc
→ {"type":"hello","clientId":"web-e2e","name":"Web Ada","platform":"web"}
← {"type":"welcome","protocol":1,"clientId":"web-e2e","name":"Web Ada",
   "serverTimeMs":0,"frozenClocks":true,"room":null | RoomSnapshot}
```

After `welcome` the server sends either `rooms` (client is in the lobby) or a
`room_state` (client was reconnected into a room). Sessions that disconnect
while seated keep their seat for `--reconnect-grace-ms` (default 45 s), then
forfeit by abandonment.

## Client → server

| type | fields | notes |
| --- | --- | --- |
| `ping` | `nonce?` | answered with `pong` (`serverTimeMs`, `nonce`) |
| `set_name` | `name` (1–24 chars) | broadcast to the room / lobby |
| `list_rooms` | — | request a fresh `rooms` |
| `create_room` | `timeControl?`, `side?` (`white`/`black`/`random`), `botLevel?` (1–4), `isPublic?` | host sits on `side`; a `botLevel` seats an engine opposite and starts immediately |
| `join_room` | `code`, `asSpectator?` | fills the open seat if the room is waiting, otherwise spectates |
| `quick_pair` | `timeControl?`, `botLevel?`, `botAfterMs?` | joins the matchmaking queue; answered with `queued`. Pairs with the first waiting player on the same time control; with `botLevel`, a bot fills the game after `botAfterMs` |
| `cancel_pair` | — | leaves the queue (`left` with `reason:"pair_cancelled"`) |
| `leave_room` | — | leaving a live game resigns it |
| `add_bot` | `botLevel?` | host of a waiting room fills the empty seat |
| `move` | `uci` | must be legal and on the mover's turn; promotions require the piece suffix |
| `resign` | — | |
| `offer_draw` / `accept_draw` / `decline_draw` | — | a move by the offering side's opponent withdraws the offer |
| `offer_takeback` / `accept_takeback` / `decline_takeback` | — | accepted takebacks undo the last ply and restore its clock |
| `offer_rematch` / `accept_rematch` / `decline_rematch` | — | on a finished room; accepting swaps colours and restarts the same room |
| `ui_report` | `id`, … | reply to a `ui_command` (automation only) |

`timeControl` is `{"initialMs":180000,"incrementMs":2000}`; `initialMs: 0`
means no clock. Presets offered by the clients: bullet 1+0 / 2+1, blitz 3+0 /
3+2 / 5+0 / 5+3, rapid 10+0 / 10+5 / 15+10, classical 30+0 / 30+20 / 90+30,
plus a custom minutes + increment picker.

## Server → client

| type | fields |
| --- | --- |
| `welcome` | see handshake |
| `rooms` | `rooms: RoomListing[]`, `online` |
| `room_state` | `room: RoomSnapshot` |
| `queued` | `timeControl`, `position`, `botAfterMs` |
| `left` | `code?` (room you left) or `reason:"pair_cancelled"` |
| `error` | `code`, `message`, `about?` (offending message type), `fatal?` |
| `pong` | `serverTimeMs`, `nonce` |
| `ui_command` | `id`, `action`, … (automation only) |

Error codes: `bad_request`, `room_not_found`, `room_full`, `not_in_room`,
`not_your_turn`, `illegal_move`, `not_playing`, `not_allowed`.

### RoomSnapshot

```jsonc
{
  "code": "U8LZ5W",            // 6 chars, alphabet ABCDEFGHJKLMNPQRSTUVWXYZ23456789
  "seq": 38,
  "status": "waiting" | "playing" | "finished",
  "timeControl": {"initialMs": 180000, "incrementMs": 2000},
  "white": Participant | null,
  "black": Participant | null,
  "spectators": Participant[],
  "hostClientId": "web-e2e",
  "startFen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "fen": "…",                   // live position
  "moves": [{"uci":"e2e4","san":"e4","fen":"…"}, …],
  "turn": "w" | "b",
  "clocks": {"whiteMs": 212000, "blackMs": 210000, "running": "w" | "b" | null,
             "asOfServerMs": 0, "frozen": true},
  "result": {"outcome": "whiteWins" | "blackWins" | "draw",
             "reason": "checkmate" | "stalemate" | "resignation" | "timeout" |
                       "agreement" | "threefoldRepetition" | "fiftyMoveRule" |
                       "insufficientMaterial" | "abandonment"} | null,
  "offers": {"draw": "w"|"b"|null, "takeback": …, "rematch": …},
  "rematchRoom": null,
  "isPublic": true
}
```

`Participant` is `{clientId, name, platform, connected, isBot, botLevel?}`.
`RoomListing` is `{code, hostName, hostPlatform, timeControl, status,
playerCount, spectatorCount, hasBot}`.

### Clocks

Remaining times are exact at `asOfServerMs`; the client extrapolates the
`running` side using its own offset to `serverTimeMs`. Neither side's first
move is timed; the clock starts once both have moved. Each later move charges
the elapsed time and credits `incrementMs`. A flag ends the game by `timeout`
(a draw if the opponent has no mating material). With `--frozen-clocks` the
server never ticks, so every client shows identical, deterministic clocks.

## Test-automation bridge

Started with `dart run bin/server.dart --control [--seed N --frozen-clocks
--bot-delay-ms 0]`. Native clients launched with `--GC_AUTOMATION true` (or the
`GC_AUTOMATION=true` environment variable) accept `ui_command` frames and answer with `ui_report`; the bridge
lets an orchestrator drive any connected client through the server and read
its rendered state back.

```
GET  /control/state                 all sessions, rooms and the queue
GET  /control/rooms/<code>          RoomSnapshot
POST /control/clients/<id>/ui       {"action": …, "timeoutMs"?: 15000} → ui_report
POST /control/clock/advance         {"ms": 2000}   (frozen clocks only)
```

`ui_command` actions understood by the native Swift client:

`state`, `set_name {name}`, `set_theme {theme}`, `create_room {timeControl?,
side?, botLevel?, isPublic?}`, `join_room {code, asSpectator?}`, `quick_pair
{bot?}`, `leave_room`, `move {uci}`, `premove {uci}`, `resign`, `offer_draw`,
`accept_draw`, `offer_takeback`, `accept_takeback`, `offer_rematch`,
`accept_rematch`, `flip`, `view_ply {ply}`, `dismiss_results`, `export_pgn`,
`import_pgn {pgn}`, `close_review`, `drop_connection`, `settle`.

Every report is `{"ok": bool, …}`; most include the client's rendered state:

```jsonc
{"ok":true,"clientId":"macos-e2e","platform":"macOS","screen":"game",
 "theme":"dark","roomCode":"U8LZ5W","status":"finished","seq":38,
 "fen":"…","liveFen":"…","moves":["e4","e5",…],"moveCount":33,"turn":"b",
 "mySide":null,"isSpectator":true,"orientation":"w",
 "result":{"outcome":"whiteWins","reason":"checkmate"},"score":"1-0",
 "clocks":{"whiteMs":212000,"blackMs":210000,"running":null,"frozen":true},
 "white":"Web Ada","black":"iOS Bram","spectators":["macOS Dov"],
 "offers":{"draw":null,"takeback":null,"rematch":null},"premove":null}
```

Native reports describe the Swift state bound to the view; they do not carry
the retired Flutter `view` metrics or certify that a frame was rendered.
`settle` waits for pending server intents, then returns the same state report.
`drop_connection` replies before reconnecting with the same client identity.
The bridge is disabled by default; use it only with a development server.

`fen` is the position currently displayed (it differs from `liveFen` while the
user browses history); `moves` is the full live move list, or the imported
mainline in PGN review mode. The active `test/multiplayer-e2e.sh` validates four
native client stores against the server after every ply. The previous
four-platform rendering harness is archived in `test/historical-flutter/`.
