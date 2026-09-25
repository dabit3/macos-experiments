# Swapmate wire protocol (v1)

Swapmate clients talk to one authoritative server over a single WebSocket
carrying JSON text frames. The server owns all rules, clocks and room state;
clients only render snapshots and send intents. Every message is a JSON object
with a `type` field. Unknown fields are ignored; unknown types produce an
`error`.

The canonical constants live in `packages/swapmate_core/lib/src/protocol.dart`.
The native iOS/macOS client mirrors the exact payloads with typed Codable models
in `apple/Sources/SwapmateKit/Protocol.swift`; live-server integration tests
verify interoperability.

```
ws://<host>:8787/ws        WebSocket endpoint
http://<host>:8787/healthz  {ok, rooms, clients, testMode}
http://<host>:8787/rooms/<CODE>  {room, game, bpgn} read-only snapshot
http://<host>:8787/         static web build when started with --static
```

## Vocabulary

| Term | Values | Meaning |
| --- | --- | --- |
| board | `a`, `b` | The two simultaneous boards (displayed as A and B). |
| seat | `aw`, `ab`, `bw`, `bb` | Board letter + colour. Team 1 = `aw`+`bb`, Team 2 = `ab`+`bw`. |
| team | `1`, `2` | Partners sit on opposite colours of opposite boards. |
| colour | `w`, `b` | |
| piece letter | `P N B R Q K` | |
| square | `a1` … `h8` | |
| move | `{from, to, promotion?}` or `{drop, to}` | `drop` is a piece letter placed from the reserve. |
| FEN | standard FEN + `[reserve]` | Reserve letters in brackets after the placement field (uppercase = white). |

## Handshake

```jsonc
// client -> server (first message)
{"type":"hello","v":1,"name":"Nader","platform":"ios",
 "resumeToken":"r-…", "testId":"ios"}          // both optional

// server -> client
{"type":"welcome","v":1,"playerId":"p-…","resumeToken":"r-…",
 "room":"SWAP"|null,"serverTime":1710000000000,"testMode":false}
```

`resumeToken` re-attaches a dropped connection to its player and room; the
server replays `room.state`, `game.state` and the player's pending premove.
`testId` is only honoured by servers started with `--test`.

`{"type":"ping","t":<ms>}` ⇄ `{"type":"pong","t":<ms>,"serverTime":<ms>}` keeps
the connection alive and lets clients estimate skew for clock rendering.

## Rooms and lobby

| client → server | fields | notes |
| --- | --- | --- |
| `room.create` | `timeControl?` `{initialMs, incrementMs}`, `fillBots?`, `code?` | `code` only honoured in test mode; otherwise a 4-letter join code is generated. `fillBots` seats deterministic bots in every empty seat. |
| `room.join` | `code`, `spectate?` | Spectators receive every broadcast but cannot act. |
| `room.leave` | | |
| `room.seat` | `seat` or `null` | Take/leave a seat. Seats are first-come. |
| `room.bot` | `seat`, `add` | Host only. Adds/removes a server-side bot. |
| `room.ready` | `ready` | |
| `room.start` | | Host only; requires four seats and every human ready. |
| `room.timeControl` | `timeControl` | Host only, lobby only. |
| `room.rematch` | | Any seated player after `finished`; when all humans vote the room returns to `playing` with colours swapped. |

Every change broadcasts

```jsonc
{"type":"room.state","room":{
  "code":"SWAP","phase":"lobby|playing|finished","host":"p-…",
  "timeControl":{"initialMs":180000,"incrementMs":0},
  "players":[{"id":"p-…","name":"Web player","seat":"aw","ready":true,
              "bot":false,"connected":true,"platform":"web"}, …],
  "spectators":[…],"rematchVotes":["p-…"]}}
```

`room: null` is sent to a player who has left.

## Gameplay

| client → server | fields | notes |
| --- | --- | --- |
| `game.move` | `move` | Must be legal for the sender's seat and colour to move. |
| `game.premove` | `move` or `null` | Stored per player, validated and executed when the player's turn arrives; `null` clears. Works for drops (pre-drop). |
| `game.resign` | | Ends the match for the sender's team. |
| `game.draw` | `action`: `offer`, `accept`, `decline` | After an opposing offer, both members of the accepting team must accept (bots count as agreeing). |
| `chat.send` | `quick` (code) or `text`, `scope`: `team` or `room` | Quick codes: `need_p need_n need_b need_r need_q no_q sit go trades mating help gg thanks sorry`. |

The server broadcasts a full snapshot after every change:

```jsonc
{"type":"game.state","game":{
  "gameId":"g-…",
  "boards":{
    "a":{"id":"a","fen":"rnbqkbnr/…[NP] w KQkq - 0 1",
         "clock":{"w":179400,"b":180000,"running":"w"},
         "lastMove":{"from":"e2","to":"e4"},"inCheck":false},
    "b":{…}},
  "moves":[{"seq":1,"board":"a","color":"w","number":1,
            "move":{"from":"e2","to":"e4"},"san":"e4","clockMs":180000},
           {"seq":7,"board":"a","color":"b","number":4,
            "move":{"drop":"P","to":"h6"},"san":"P@h6","clockMs":171200,
            "captured":null}],
  "result":null | {"winner":"1"|"2"|null,
                   "reason":"checkmate|timeout|resignation|stalemate|repetition|agreement|abandonment",
                   "board":"a","loser":"ab"},
  "serverTime":1710000000000,
  "premove":{"from":"g8","to":"f6"} | null,    // recipient's own premove
  "drawOffers":["aw"],
  "bpgn":"[Event …]" | null                    // present once finished
}}
```

Clocks are sent as remaining milliseconds sampled at `serverTime`; clients
extrapolate the running side locally and never enforce time themselves.

Alongside each snapshot the server emits a `game.event` so clients can
animate what happened:

```jsonc
{"type":"game.event","event":{"kind":"move|drop|pass|start|finish",
  "board":"a","seat":"aw","move":{…},"san":"Qxf7#",
  "captured":"P","toBoard":"b","toColor":"b"}}
```

`pass` events carry the captured piece to the partner's reserve on the other
board (`toBoard`, `toColor`), which drives the piece-passing animation.

## Rules enforced by the server

Standard chess movement including castling, en passant and promotion, plus
Bughouse extensions per the common chess.com/FICS rule set:

- A captured piece is added to the *partner's* reserve (partner = opposite
  colour on the other board). Promoted pieces revert to pawns when captured.
- A drop places one reserve piece on any *empty* square as a full move.
  Pawns may not be dropped on ranks 1 or 8.
- Drops that give check **or checkmate** are legal.
- Checkmate, timeout or resignation on either board ends the whole match for
  both boards. Stalemate, threefold repetition and agreement are draws.
- Each board keeps independent white/black clocks with per-move increment.
- Sitting (declining to move) is allowed; the clock keeps running.

## Chat

```jsonc
{"type":"chat.message","message":{"from":"p-…","name":"iOS player","seat":"ab",
  "ts":1710000000000,"scope":"team","quick":"need_n"}}
{"type":"chat.message","message":{…,"scope":"room","text":"gg"}}
```

## Errors

```jsonc
{"type":"error","code":"illegal_move","message":"…","ref":"game.move"}
```

Codes: `bad_request room_not_found room_full seat_taken not_host not_seated
not_your_turn illegal_move not_playing not_ready rate_limited`.
`rate_limited` is returned for `chat.send` beyond 10 messages in 5 seconds.
`chat.send` text is trimmed and truncated to 200 characters.

## Test channel (server started with `--test`)

The native shell harness `test/multiplayer-e2e.sh` runs Swift clients against
the real server, including command acknowledgements through this endpoint.
A native client launched with `SWAPMATE_TEST_ID` can also be addressed over HTTP:

```
GET  /test/clients                  -> {"clients":[{"testId","playerId","name","platform","room","seat"}]}
POST /test/command                  {"testId":"ios","command":{"cmd":"move","uci":"e2e4"},"timeoutMs":30000}
                                    -> {"ok":true,"result":{…client state…}} | {"ok":false,"error":"…"}
```

The server forwards the command as `{"type":"test.command","id":"t-…", …command}`
and the client answers `{"type":"test.result","id":"t-…","ok":true, …}`.
Commands run through the same native `GameClient` intents as the UI, including
advisory move validation. They wait for authoritative snapshots/errors, not a
back door into server state. The native result contains `room` and `game`
snapshots, `mySeat`, `chats` (count), `theme`, `ok`, and optional `error`; absent
optional values are omitted.

| cmd | fields | result |
| --- | --- | --- |
| `state` | | Native result described above |
| `create_room` | `code?`, `fillBots?`, `timeControl?` | state once the room exists |
| `join_room` | `code`, `spectate?` | |
| `seat` | `seat` | waits until the seat is held |
| `bot` | `seat`, `add` | |
| `ready` | `ready` | |
| `start` | | waits for `playing` + first `game.state` |
| `move` | `uci` (`e2e4`, `e7e8q`, `P@h6`) | waits for the move to be applied or rejects with the server error |
| `premove` | `uci` | |
| `quick_chat` | `code` | |
| `chat` | `text` | |
| `resign`, `draw` (`action`), `rematch`, `leave` | | |
| `theme` | `mode`: `dark` or `light` | |
| `wait` | `phase?`, `moves?`, `over?`, `timeoutMs?` | Blocks until the snapshot predicate holds or returns an explicit timeout error. |

The retired Flutter raster `capture` command and frame-count predicates are
not supported by the native client. Use native XCTest, macOS screenshot tools
or `xcrun simctl io booted screenshot` for separately authorized UI validation.
Historical four-platform raster harnesses are archived under `historical/`.

Seeds: `--seed` fixes the server RNG (room codes, bot move choice) and bots
choose moves by a deterministic evaluation over the seeded RNG, so a test with
a fixed seed and fixed time control replays identically.
