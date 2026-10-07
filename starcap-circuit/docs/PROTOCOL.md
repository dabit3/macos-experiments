# Starcap room protocol v1

JSON text frames over WebSocket, default `ws://HOST:8791`. Native
`URLSessionWebSocketTask`; server `ws` 8.21.3, exact dependency lockfile.
No cookies, web login or Apple account. All racing commands operate on the player
associated with the socket; clients never submit position, score, laps or health.

## Client → server

```json
{"type":"join","code":"STAR","name":"PipPilot","racer":0,"track":0,"token":""}
{"type":"ready"}
{"type":"input","seq":42,"steer":-0.45,"throttle":1,"brake":false,"drift":true,"use":false}
{"type":"rematch"}
{"type":"ping","sent":12345}
```

Room code: 4–8 ASCII alphanumeric characters; case-normalized. Guest name truncated
to 16 characters. Racer is 0–2, course 0–1. First join creates a room. Maximum two
players; racing rooms reject new identities. No AI occupies remote slots.

Inputs carry a strictly increasing safe integer sequence. Old/duplicate sequences
and non-finite steering/throttle are discarded. Inputs clamp to valid ranges.
`use` shares that sequence acceptance so retransmission cannot repeat an item.
Inputs stale for 600 ms switch to braking. Commands in irrelevant phases have no
effect. Server payload bound: 2048 bytes; rate bound: 90 messages/second/socket.

Both connected players ready triggers a common server `startAt = now + 3500 ms`.
Fixed simulation step is 1/30 second. Snapshots go to every peer at 15 Hz.
Clients estimate server time from the last received snapshot plus elapsed local
monotonic time; no synchronous clock-setting or client-trusted lap timing.

`rematch` is accepted only in results. It resets readiness, alternates the track
and returns all participants to the shared lobby. The next all-ready transition
resets race positions, checkpoints, items, statistics and increments race ID.

## Server → client

```json
{"type":"welcome","id":"uuid","token":"opaque-rejoin-uuid","code":"STAR"}
{"type":"error","message":"Room full — two racers maximum."}
{"type":"state","code":"STAR","phase":"racing","track":0,"race":1,
 "now":1789308400000,"startAt":1789308390000,"laps":2,
 "players":[],"hazards":[],"events":[]}
```

Player snapshots include `id,name,racer,connected,ready,x,z,heading,speed,index,
progress,gate,lap,finish,rank,item,roulette,boost,stun,shield,charge,drifting,seq,
pickups,shots,hits,drifts,distance`. Finish is milliseconds since shared start,
zero until finished. Rank sorts finish time then unfinished progress. Maximum
race time 180 seconds, with a 20-second grace after the winner. DNF remains zero.

Positions are world x/z in track units; heading zero faces +z, positive turns
toward +x. Each of 240 course samples maps to 1/240 of a lap. Ordered gates every
30 samples require sixteen gate crossings to finish. Progress uses signed
nearest-track deltas, rejects jumps over eight samples/tick and does not advance
outside the road margin. Driving backward removes progress. Barriers constrain
large departures; grass reduces maximum speed.

Transient effects are time durations in seconds. Items cycle deterministically
through zap/comet/gum/bubble per pickup/race. Rotating cube rows lie at samples
24,84,144,204, with a per-lap/per-row guard and 2.8-second cooldown. Roulette lasts
1.1 seconds. Item effect ranges and drift thresholds live in the server
rules, never accepted from clients.

Racer handling (`RACERS`): 0 balanced, 1 higher acceleration/turning and lower
top speed, 2 higher top speed and lower acceleration/turning. Drift release uses
three tiers at 0.65/1.3/2.0 seconds of charge (boost 0.8/1.4/2.0 s) and emits
`drift` with `tier` 1–3. Dash panels at samples 12,72,132,192 boost for 1 second,
once per lap each, emitting `dash`. Gas held continuously from 0.2–2.0 s before
the shared start emits `rocket` (1.2 s boost); held longer emits `stall`
(0.6 s stun).

Events have monotonically increasing `id`, `kind`, `player`, and optional `target`,
`item`, `gate` or `time`. Last sixteen retained to avoid missed effects between
snapshots; clients consume each event once. Gum hazards have `x,z,owner,ttl`.
Guest reconnect token and private inputs are excluded from shared snapshots.

## Reconnect and cleanup

A `join` carrying the original guest token reclaims the same ID, current race
position, checkpoint progress and ordered-input sequence. An existing socket for
that ID is closed; its late disconnect event cannot mark the new socket offline.
The native app retains the token in memory and presents Reconnect after network
loss. Relaunching the process starts a new identity.

Disconnected karts stop processing motion and render translucent. An offline
lobby guest is removed after 30 seconds. Entire disconnected rooms expire after
60 seconds; no persistence across server restarts. Returning racers do not receive
teleports or artificial progress.

## Read-only diagnostics

`GET /health` returns server availability and room count.
`GET /rooms/CODE` returns the same token-free state as players receive, for local
test assertions. Neither endpoint can mutate racing state. Server stdout uses
JSONL events. No administrative score/finish forcing endpoint exists.
