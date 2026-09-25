# Voxelhearth network protocol

Version `1`. JSON objects over a single WebSocket (`ws://host:8787/ws`). Every
message has a string `t` (type). Unknown fields are ignored; unknown types get
an `error` reply. The server is authoritative: clients send intents, the
server validates them against the shared rules in `packages/voxelhearth_core`
and broadcasts the resulting state. Clients may predict locally (block edits,
own movement) but always converge on what the server sends.

Ticks run at 20 Hz (`tickHz` in `welcome`). A day is 24 000 ticks.

## Session

| Direction | `t` | Fields | Notes |
|---|---|---|---|
| C→S | `hello` | `name`, `platform` (`web`/`ios`/`android`/`macos`), `token?`, `version` | First message. `token` from a previous `welcome` resumes the same player identity (reconnect). |
| S→C | `welcome` | `playerId`, `token`, `name`, `serverVersion`, `testMode`, `tickHz` | Followed by `room_joined` (auto-rejoin after a drop) or `rooms`. |
| C→S | `ping` `{ts}` / S→C `pong` `{ts, serverTime}` | | Keep-alive + latency. |
| S→C | `error` | `code`, `msg` | Codes: `bad_json`, `version`, `no_hello`, `bad_code`, `no_room`, `not_in_room`, `forbidden`, `unknown`, `internal`. |

## Rooms and lobby

| Direction | `t` | Fields |
|---|---|---|
| C→S | `list_rooms` | — |
| S→C | `rooms` | `rooms: [{code, name, mode, phase, players, humans}]` |
| C→S | `create_room` | `name?`, `seed?`, `mode?` (`survival`/`creative`), `durationTicks?` (0 = free play), `freezeTime?`, `spawnMobs?`, `startTime?`, `bots?` (0-6), `code?` (test mode only) |
| C→S | `join_room` | `code` (5-letter join code, case-insensitive) |
| C→S | `leave_room` | — |
| S→C | `room_joined` | `code`, `roomName`, `seed`, `mode`, `phase`, `time`, `freezeTime`, `durationTicks`, `tick`, `you`, `host`, `spawn: [x,y,z]`, `x`,`y`,`z`,`yaw`,`pitch`, `players: [PlayerInfo]`, `chat: [ChatLine]`, `matchEndTick` |
| S→C | `room_state` | `code`, `name`, `seed`, `mode`, `phase`, `host`, `durationTicks`, `freezeTime`, `spawnMobs`, `matchEndTick`, `tick`, `time`, `players: [PlayerInfo]` — sent on every lobby change and every 100 ticks |
| S→C | `player_joined` `{player: PlayerInfo}` / `player_left` `{id}` | |
| C→S | `ready` | `ready: bool` |
| C→S (host) | `start_match`, `end_match`, `back_to_lobby`, `add_bot`, `remove_bot` | — |
| C→S (host) | `room_settings` | any of `mode`, `durationTicks`, `freezeTime`, `spawnMobs` |
| C→S (host) | `set_mode` `{mode}`, `set_time` `{time}`, `rename_room` `{name}` | |
| S→C | `phase` | `phase` (`lobby`/`playing`/`results`), `tick`, `time?`, `matchEndTick?`; in `results` also `results: [PlayerInfo]` sorted by score, `worldHash`, `chatHash` |

`PlayerInfo = {id, name, platform, bot, connected, ready, score, placed, broken, crafted, kills, deaths}`.
Score = placed + broken + crafted×3 + kills×5.

Match flow: `lobby` → host `start_match` → `playing` (everyone is teleported
to spawn, chunks stream) → host `end_match` or `matchEndTick` reached →
`results` → host `back_to_lobby`. The world persists across matches and
across server restarts (`--save-dir`).

Reconnection: a client that reconnects with its `token` gets the same player
id and is rejoined to its room automatically (`room_joined` instead of
`rooms`). A disconnected host keeps the role for 30 s (`Room.hostGraceTicks`)
so a quick reconnect keeps control; after that, or when the host leaves, the
first connected human becomes host (`room_state.host` changes).

## World

Chunks are 16×16 columns, 64 blocks high. Terrain is generated
deterministically from `seed` on both sides; the server only sends **edits**
(diffs against generation), so world state is compact and hashable.

| Direction | `t` | Fields |
|---|---|---|
| C→S | `request_chunks` | — (server streams chunks around the player automatically) |
| S→C | `chunk` | `cx`, `cz`, `edits: [idx, id, idx, id, …]` (`idx = (y*16 + z)*16 + x`) |
| S→C | `block_set` | `x`,`y`,`z`,`id`, `by` (player id or null), `tick` |
| S→C | `time_set` | `time`, `tick` |
| S→C | `snapshot` | `tick`, `time`, `players: [{id,x,y,z,yaw,pitch,held,sneak,sleep,hp}]`, `mobs: [{id,kind,x,y,z,yaw,hp,hurt}]` — every tick |
| S→C | `teleport` | `x`,`y`,`z` (respawn / match start) |

## Gameplay intents

| C→S `t` | Fields | Server checks |
|---|---|---|
| `move` | `x`,`y`,`z`,`vx`,`vy`,`vz`,`yaw`,`pitch`,`sneak`,`sprint`,`fly` | speed/teleport sanity, fall damage, chunk streaming |
| `break` | `x`,`y`,`z` | reach, breakable, harvest tier → drop |
| `place` | `x`,`y`,`z`,`nx`,`ny`,`nz` | reach, replaceable target, no entity overlap, support for plants/torches, consumes item in survival |
| `interact` | `x`,`y`,`z` | opens workbench / chest / kiln, sleeps in a bed |
| `select_slot` | `slot` (0-8) | |
| `move_item` | `from`,`to` (inventory slot indices), `count?` | swap / merge / split inside the player's inventory; `chest_put {slot, cslot}` / `kiln_put {slot, kslot: input\|fuel\|output}` exchange with the open container |
| `craft` | `grid: [ids…]`, `n` (2 or 3), `count` | recipe table in `recipes.dart` |
| `eat` | — | held food |
| `attack` | `id` (mob) | reach, weapon damage |
| `sleep` | `x`,`y`,`z` | night only, no hostiles nearby; sets spawn, skips to dawn when everyone sleeps |
| `chat` | `text` (≤ 200 chars) | |
| `kiln_put`, `chest_put`, `drop_item`, `close_ui`, `respawn` | | |
| `give` | `id`,`count`,`slot` | creative mode or test-mode rooms only |

| S→C `t` | Fields |
|---|---|
| `inventory` | `slots: [[id,count]…]` (36 slots; 0-8 hotbar), `selected` |
| `stats` | `hp`, `food`, `air`, `score` |
| `container` | `kind` (`chest`/`kiln`), `pos`, `slots?` / `kiln?` |
| `open_ui` | `kind` (`inventory`/`workbench`/`chest`/`kiln`) |
| `chat_msg` | `from`, `text`, `tick`, `system?` |
| `effect` | `kind` ∈ `break`, `place`, `craft`, `eat`, `hit`, `hurt`, `died`, `mob_died`, `mob_attack`, `inventory_full`, `toast`, plus kind-specific fields |

## Determinism and verification

* `worldHash` — FNV-1a 32-bit over `seed` + every edit `(cx, cz, idx, id)` in
  sorted order. Identical on every peer that has applied the same edits,
  regardless of which chunks it has loaded.
* `chatHash` — FNV-1a over `(from, text)` of the full chat log.
* Region hash — FNV-1a over raw block ids in an inclusive box; used by the
  e2e test to prove all clients render the same shared structure.

All arithmetic in the hash, RNG and noise code is explicit 32-bit so the Dart
server and native Swift clients agree bit-for-bit. Native terrain fixtures
are generated by the authoritative Dart implementation.

## Test mode / director channel

Started with `--test-mode`. Adds: requested room codes, deterministic tokens
(`test-<name>`), the `give` cheat, and a director channel for automation.

| Direction | `t` | Fields |
|---|---|---|
| C→S | `director` | `key` (default `voxelhearth-director`) → `director_ok {rooms}` |
| D→S | `drive` | `player` (name, id, or `@platform`), `id`, `action: {t, …}` — forwarded to that client as `drive`; the client answers `drive_done {id, ok, …}` which is relayed back as a `director_event` |
| D→S | `hash_request` | `room`, `region?` — server asks every client in the room for `client_hash {id, world, chat, region?, phase, players}` and replies `hashes {id, server: {world, chat, region}, clients: {playerId: …}, missing: [ids], timedOut}` |
| D→S | `director_query` | `room`, `region?`, `cmd?` → `director_event {t: 'query', state, worldHash, chatHash, chat, positions, mobs, inventories, blocks}` |
| S→D | `director_event` | `room`, `event` — also emitted for `joined` and `phase` changes |

Native drive actions (see `apple/Sources/Game.swift` and
`apple/Sources/Session.swift`): `screen`, `wait_screen`, `create_room`,
`join_room`, `leave_room`, `ready`, `start_match`, `end_match`,
`back_to_lobby`, `set_theme`, `set_touch`, `wait_game`, `state`, `look`,
`look_at`, `teleport`, `walk`, `break`, `place`, `place_at`, `select_slot`,
`chat`, `give`, `craft`, `open_inventory`, `close_overlay`, `toggle_chat`,
`pause`, `block`, `chat_log`, `results`, `wait_ready`, `drop_connection`
(severs the socket and waits for the token-based rejoin). Legacy `fixture`
and `layout` actions that synthesized Flutter screens and dumped text-node
geometry are historical; the native client reports unsupported actions.

Native clients enter test mode via `VH_TEST=1` in their environment or
`-VH_TEST 1` launch arguments. `VH_NAME`, `VH_SERVER`, `VH_JOIN` and
`VH_CREATE` work the same way. Client automation is enabled only when the
server's welcome also reports `testMode: true`. Region diagnostics accept
inclusive boxes up to 128 blocks per axis.
