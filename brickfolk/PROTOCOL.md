# Brickfolk network protocol (v1)

Brickfolk clients talk to a single authoritative server over one WebSocket.
Every frame in either direction is a UTF-8 JSON object with a string `type`
field. The server owns all game state; clients only send intent (inputs,
purchases, room actions) and render what the server sends back.

The message identifiers below are defined once in
`shared/lib/src/protocol.dart` (`MsgType`, `ErrorCode`, `ChatChannel`) and
used by the Dart server and mirrored in the native Apple client. The Swift
wire models are in `apple/Sources/BrickfolkCore/`.

- Endpoint: `ws://<host>:<port>/ws`
- Health: `GET /health` → `{"ok":true,"protocolVersion":1}`
- Tick rate: 30 simulation ticks per second (`ticksPerSecond`)
- Room size: up to 8 seats including bots (`maxRoomPlayers`)
- Timestamps (`serverTime`, `*EndsAt`) are server milliseconds. In test mode
  they come from a fixed clock that advances one tick per simulation step.

## 1. Connection and handshake

The first frame a client sends must be `hello`. Anything else is answered
with `error{code:"unauthenticated"}`.

```jsonc
// client → server
{"type":"hello","protocolVersion":1,"platform":"web",
 "name":"WebWren",          // required on first sign-in
 "token":"<32 chars>"}      // optional: returning player
```

- `protocolVersion` must equal the server version or the socket is closed.
- `platform` is a free-form label (`web`, `ios`, `android`, `macos`) shown to
  other players and used by the test harness.
- `name` must match `^[A-Za-z][A-Za-z0-9_]{2,15}$`. Names are unique.
- `token` resumes a persisted player. When it resolves, `name` is ignored. A
  token the server no longer knows (e.g. after a database reset) falls back to
  `name`; with no `name` the reply is `error{code:"unauthenticated",
  inReplyTo:"hello"}` and the client should discard the token.
- Signing in from a second client replaces the previous session (the old
  socket receives `error` "Signed in from another client." and is closed).
  A player who reconnects while still seated in a room re-enters it.

```jsonc
// server → client
{"type":"welcome","protocolVersion":1,"token":"…",
 "player":{…PlayerProfile…},"serverTime":123456,
 "testMode":false,"roomCode":null,"partyCode":null}
```

Immediately after `welcome` the server pushes `places`, `friends.state` and,
if the player is in a party, `party.state`.

Keep-alive: `{"type":"ping","nonce":n}` → `{"type":"pong","nonce":n,"serverTime":…}`.

### Errors

```jsonc
{"type":"error","code":"name_taken","message":"That name is already taken.",
 "inReplyTo":"hello"}
```

Codes: `bad_request`, `name_taken`, `invalid_name`, `not_found`, `room_full`,
`not_enough_pips`, `already_owned`, `not_leader`, `cooldown`, `rate_limited`,
`unauthenticated`. `inReplyTo` carries the type of the offending frame.

## 2. Message catalogue

### Client → server

| type | payload | effect |
|---|---|---|
| `hello` | `protocolVersion, platform, name?, token?` | sign in (see above) |
| `ping` | `nonce` | keep-alive |
| `avatar.update` | `avatar: Avatar` | save avatar (only owned items are accepted) → `player.updated` |
| `shop.buy` | `item` | spend Pips on a catalogue item → `player.updated` or `error` |
| `daily.claim` | – | claim the daily reward → `daily.result` |
| `friends.request` | `player` (name or id) | send a friend request |
| `friends.accept` / `friends.decline` / `friends.remove` | `player` | manage friendships → `friends.state` to both players |
| `party.create` | `code?` | create a party (4-char code, optional fixed code in test mode) |
| `party.join` | `code` | join a party |
| `party.leave` | – | leave the party |
| `party.launch` | `experience, bots?` | leader only: create a room and pull every member in |
| `chat.send` | `channel, text` | post to `global`, `party` or `room` chat (filtered, rate limited) |
| `places.list` | – | request the place browser list → `places` |
| `place.rate` | `place, up` (`true`, `false` or `null` to clear) | thumbs up/down a place → `places` to everyone |
| `profile.get` | `player` | request another player's profile → `profile` |
| `room.create` | `experience, bots?` | create a room and join it |
| `room.join` | `code` | join an existing room |
| `room.leave` | – | leave the room (and its party link) |
| `room.ready` | `ready` (bool, default true) | toggle readiness in the lobby |
| `input` | `data` (experience specific, §5) | per-tick gameplay intent |
| `test.report` | `phase, payload` | test mode only: record a client-side observation (§7) |

### Server → client

| type | payload |
|---|---|
| `welcome` | see §1 |
| `pong` | `nonce, serverTime` |
| `error` | `code, message, inReplyTo?` |
| `player.updated` | `player: PlayerProfile` (pips, inventory, avatar, badges, streak) |
| `daily.result` | `claimed: bool, reward, streak, nextClaimAt` |
| `friends.state` | `friends: [PlayerSummary+online], incoming: [...], outgoing: [...]` |
| `party.state` | `party: PartyState \| null` |
| `chat.message` | `message: {id, channel, from: PlayerSummary, text, at}` |
| `places` | `places: [PlaceInfo + playing, rooms, visits, likes, dislikes, myVote]`, `online` (id, name, blurb, matchSeconds, humans currently in rooms, open rooms, all-time room entries, vote totals and the receiving player's own vote) |
| `profile` | `profile: PlayerProfile` (owned items removed for other players), `isFriend` |
| `room.state` | `room: RoomState \| null, botCount, serverTime` |
| `game.state` | experience frame (§5) plus `tick`, `ticksLeft` |
| `game.event` | `events: [{kind, player?, value?}], tick` |
| `game.results` | `results: MatchResults, resultsEndsAt` |
| `test.control` | test mode only: harness command relayed to a room (§7) |

## 3. Party lifecycle

A party is a cross-platform pre-lobby group with a 4-character join code.

```
party.create ─► party.state{code, leaderId, members[{id,name,platform,online}], roomCode:null}
party.join   ─► party.state broadcast to all members
party.launch ─► server creates a room, sets party.roomCode, seats every
                *online* member, and broadcasts room.state to them
party.leave  ─► party.state (or party:null to the leaver); the party is
                deleted when its last member leaves; leadership passes to the
                next member if the leader leaves
```

Members who are offline stay in the party (`online:false`) and are seated
in the party's room when they reconnect (`welcome.partyCode` + `roomCode`).

## 4. Room lifecycle

```
          all seated players ready            3 s
 lobby ───────────────────────────► countdown ─────► playing
   ▲                                    │              │ game over
   │        any player un-readies       │              ▼
   └────────────────────────────────────┘          results (20 s) ──► lobby
```

- `room.state.room` = `{code, experience, phase, members[{player, ready,
  disconnected}], seed, countdownEndsAt?, matchEndsAt?, round}`. `round` is
  the number of finished matches in this room.
- `room.create` / `party.launch` accept `bots` (0-7). Bots are added when
  the match starts and share the seat limit with humans.
- Players joining during `playing` spectate until the next match.
- A player who disconnects keeps their seat for 30 s (`reconnectGraceMs`);
  the seat is released if they do not reconnect.
- Match seed = room seed + match number, so a room with a fixed seed replays
  identically.

## 5. Gameplay frames

While `phase == playing` the server broadcasts `game.state` every tick and
`game.event` whenever something noteworthy happens. Clients send `input`
frames whenever their intent changes and repeat a held movement input at
least every 0.5 s. The server keeps the last input per player and treats it
as released once 1 s (30 ticks) passes without a refresh, so a stalled or
dropped client stops instead of running off the course. Movement,
collisions, scoring and timers are all simulated on the server; clients
interpolate between the last two frames.

### Obby (`experience: "obby"`)

```jsonc
// input.data — immediate form
{"l":false,"r":true,"j":true,"t":880}   // left, right, jump; t (optional) =
                                        // tick of the frame the input reacts to
// input.data — scheduled form (plan)
{"t":880,"plan":[[890,2],[893,6],[950,0]]}
//   [tick, flags] pairs, ascending; flags bit 0 = left, 1 = right, 2 = jump.
//   Each entry takes effect at its tick and stays held until the next one.
//   A plan replaces earlier scheduled entries from its first tick on; entries
//   already due when it arrives apply at once. Held plan entries never time
//   out, so the last entry must be a release (flags 0). Autopilots in the
//   automated test send a plan covering the next 2 s on every frame they
//   manage to process, so a client starved for CPU keeps steering correctly.
// game.state
{"tick":900,"ticksLeft":2700,
 "players":{"<id>":[x,y,vx,vy,flags,checkpoint,deaths,finishTick,respawnUntilTick,inputLag]}}
//   flags bit 0 = grounded, bit 1 = facing right
//   inputLag = ticks between the latest input's `t` and its arrival (0 if it was
//   untagged, -1 until any input applied); a remote autopilot replays its in-flight
//   decisions over that many ticks before deciding on the predicted state
// game.event kinds
"jump","land","checkpoint","death","finish"
```

Course geometry is the shared deterministic `ObbyCourse.instance`
(`shared/lib/src/obby.dart`), exported into the native content bundle. Score =
finish bonus − time, or checkpoints reached for unfinished players.

### Tycoon (`experience: "tycoon"`)

```jsonc
// input.data
{"a":"place","cell":37,"item":"dropper"}
{"a":"remove","cell":37}
{"a":"upgrade","item":"boost1"}
// game.state (sent only when a plot changed or once per second)
{"tick":…,"ticksLeft":…,
 "plots":{"<id>":{cells:[…],upgrades:[…],cash,earned,bricksPlaced}},
 "earned":{"<id>":123}}
// game.event kinds
"place"
```

Plots persist per player across matches; `earned` is the in-match income
that decides the leaderboard.

### Tag (`experience: "tag"`)

```jsonc
// input.data
{"dx":0.71,"dy":-0.71}             // unit-ish move vector
// game.state
{"tick":…,"ticksLeft":…,"round":1,"roundTicksLeft":…,"intermission":0,
 "players":{"<id>":[x,y,flags,thawProgress,freezes,thaws,timesFrozen,roundScore,totalScore,facing]}}
//   flags bit 0 = tagger, bit 1 = frozen
// game.event kinds
"roundStart","freeze","thaw","roundEnd" (with swept: bool)
```

Three rounds of 20 s each (the 60 s match split evenly); the tagger rotates
each round.

## 6. Results and checksum

When a match ends the room enters `results` and every seated client gets:

```jsonc
{"type":"game.results","resultsEndsAt":…,
 "results":{"experience":"obby","round":1,"seed":1235,"durationMs":64300,
  "entries":[{"rank":1,"player":{…PlayerSummary…},"score":98072,
              "detail":"Finished 64.3s"}, …],
  "checksum":"1d2c9e8d"}}
```

`checksum` is computed by `MatchResults.computeChecksum` in the shared
package from `rank|name|score|detail` of every entry using integer string
hashing only, so it is bit-identical on Dart VM, Dart web (JS numbers) and
every native target. Clients that observe the same match must report the
same checksum; the native protocol integration probe asserts exactly that.

Persistence (server-side SQLite): players, tokens, Pips, inventory, avatar,
badges, daily streak, friendships, tycoon plots, and per-experience stats
(matches, wins, best obby time).

## 7. Test mode

Started with `--test-mode` (`server/bin/server.dart`). Adds a fixed clock,
deterministic bots, reuse of fixed names across restarts, and:

- `GET /test/state` → snapshot `{serverTime, tick, online, players[], rooms[]
  (with lastResults), parties[], testReports[]}`.
- `POST /test/control {"room":"ABCD","cmd":"leave"|"ready"|"report"|"show",
  "platform"?, …}` → relayed to the room's clients (all clients when `room`
  is omitted) as `{"type":"test.control","cmd":…}`; a client ignores commands
  whose `platform` names another platform. `show {screen}` switches the hub to
  a screen for the visual tour; `ready` marks the client ready in its lobby
  (used for clients started with `BRICKFOLK_AUTO_READY=false`).
- `test.report {phase, payload}` from clients is appended to `testReports`
  with the player's platform and server time. The native `AutomationDriver`
  reports `signedIn`, `party`, `launch`, `lobby`, `countdown`, `playing`,
  `results` and `tour`; results carry the canonical leaderboard/checksum.
  Native reports describe received state and set `rendered: false`: they
  do not assert rasterization or visual parity. `BRICKFOLK_PHASE_MARKER=true`
  adds an in-app phase label; `--results-ms` controls the results hold time.
  `test/multiplayer-e2e.sh` checks two real URLSession WebSocket peers and
  all three games without launching a UI. Historical Flutter display
  comparisons are retained only under `.devin/`.
