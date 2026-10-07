import test from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import { WebSocket } from "ws";
import { createPlayer, inputPlayer, resetRace, tick, driver, snapshot, useItem, trackPoint, tangent } from "./game.mjs";
const tangentAt = index => tangent(0, index);
import { startServer } from "./server.mjs";

function fixture(track = 0) {
  return {
    code: "TEST", track, race: 0, phase: "lobby", startAt: 0, eventID: 0, events: [], hazards: [],
    players: new Map([["a", createPlayer("a", "Pip", 0, "secret-a")], ["b", createPlayer("b", "Mochi", 1, "secret-b")]])
  };
}

for (const course of [0, 1]) test(`two input-driven racers finish course ${course}, collect and use items, drift and validate 16 gates`, () => {
  const room = fixture(course);
  resetRace(room, 0);
  const seen = new Set();
  for (let frame = 0; frame < 5400 && room.phase !== "results"; frame++) {
    const now = frame * 1000 / 30;
    for (const p of room.players.values()) {
      inputPlayer(p, { seq: frame, ...driver(course, p, now) }, now);
      if (p.item && !p.roulette) useItem(room, p);
    }
    tick(room, now);
    room.events.forEach(e => seen.add(e.kind));
  }
  assert.equal(room.phase, "results");
  const players = [...room.players.values()];
  for (const p of players) {
    assert.ok(p.finish > 20000 && p.finish < 120000, JSON.stringify(p));
    assert.equal(p.gate, 17);
    assert.ok(p.pickups >= 4);
    assert.ok(p.shots >= 4);
    assert.ok(p.drifts > 0);
    assert.ok(p.distance > 600);
  }
  assert.ok(seen.has("zap")); assert.ok(seen.has("checkpoint"));
  assert.deepEqual(players.map(p => p.rank).sort(), [1, 2]);
  const state = snapshot(room, 100000);
  assert.equal(JSON.stringify(state).includes("secret-"), false);
  resetRace(room, 100000);
  assert.equal(room.race, 2);
  assert.ok(players.every(p => p.finish === 0 && p.gate === 1 && p.shots === 0));
});

test("ordered input, expired input safety, invalid numbers and no checkpoint teleport", () => {
  const room = fixture();
  resetRace(room, 0);
  const p = room.players.get("a");
  assert.equal(inputPlayer(p, { seq: 5, steer: 1, throttle: 1 }, 4000), true);
  assert.equal(inputPlayer(p, { seq: 4, steer: -1, throttle: 1 }, 4001), false);
  assert.equal(inputPlayer(p, { seq: 6, steer: NaN, throttle: 1 }, 4002), false);
  p.speed = 30;
  tick(room, 5000);
  assert.ok(p.speed < 30);
  Object.assign(p, trackPoint(0, 120));
  tick(room, 5033);
  assert.equal(p.gate, 1);
  assert.equal(p.finish, 0);
});

test("zap affects opponent, shield consumes hit and braking slows actual motion", () => {
  const room = fixture(); resetRace(room, 0); room.phase = "racing";
  const a = room.players.get("a"), b = room.players.get("b");
  a.item = "zap"; b.speed = 30;
  useItem(room, a);
  assert.equal(a.hits, 1); assert.ok(b.stun > 0); assert.equal(b.speed, 12);
  b.shield = 3; b.stun = 0; a.item = "zap"; useItem(room, a);
  assert.equal(b.shield, 0); assert.equal(b.stun, 0);
  a.speed = 30; inputPlayer(a, { seq: 2, steer: 0, throttle: 0, brake: true }, 5000);
  tick(room, 5000); assert.ok(a.speed < 29);
});

function waitMessage(ws, predicate) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => { ws.off("message", listener); reject(new Error("WebSocket response timeout")); }, 3000);
    const listener = raw => { const msg = JSON.parse(raw); if (predicate(msg)) { clearTimeout(timeout); ws.off("message", listener); resolve(msg); } };
    ws.on("message", listener);
  });
}
const send = (ws, value) => ws.send(JSON.stringify(value));

test("real WebSocket room limits, shared countdown, token rejoin, stale socket protection", async () => {
  const host = startServer(0);
  await once(host.server, "listening");
  const url = `ws://127.0.0.1:${host.server.address().port}`;
  const peers = [];
  async function connect(name) {
    const ws = new WebSocket(url); peers.push(ws); await once(ws, "open");
    const response = waitMessage(ws, m => m.type === "welcome" || m.type === "error");
    send(ws, { type: "join", code: "LIVE", name }); return { ws, response: await response };
  }
  try {
    const a = await connect("Alice"), b = await connect("Bob"), c = await connect("Extra");
    assert.notEqual(a.response.id, b.response.id);
    assert.equal(c.response.type, "error");
    const countdown = waitMessage(b.ws, m => m.phase === "countdown");
    send(a.ws, { type: "ready" }); send(b.ws, { type: "ready" });
    const state = await countdown;
    assert.equal(state.players.length, 2); assert.ok(state.players.every(p => p.ready));
    const replacement = new WebSocket(url); peers.push(replacement); await once(replacement, "open");
    const welcome = waitMessage(replacement, m => m.type === "welcome");
    send(replacement, { type: "join", code: "LIVE", token: a.response.token });
    assert.equal((await welcome).id, a.response.id);
    const live = await waitMessage(replacement, m => m.type === "state");
    assert.equal(live.players.find(p => p.id === a.response.id).connected, true);
  } finally { peers.forEach(p => p.terminate()); await host.close(); }
});

test("rocket start rewards gas held from the 2 count and stalls gas held from the 3", () => {
  const room = fixture(); resetRace(room, 0);
  const a = room.players.get("a"), b = room.players.get("b");
  inputPlayer(a, { seq: 1, steer: 0, throttle: 1 }, 2200);
  inputPlayer(b, { seq: 1, steer: 0, throttle: 1 }, 600);
  inputPlayer(b, { seq: 2, steer: 0, throttle: 1 }, 3300);
  inputPlayer(a, { seq: 2, steer: 0, throttle: 1 }, 3400);
  tick(room, 3500);
  assert.equal(room.phase, "racing");
  assert.ok(a.boost > 1 && a.speed > 19, JSON.stringify(a));
  assert.ok(b.stun > 0 && b.boost === 0);
  assert.deepEqual(room.events.map(e => e.kind), ["rocket", "stall"]);
});

test("drift charge releases blue, orange and ultra turbo tiers with increasing boost", () => {
  const boosts = [0.8, 1.5, 2.2].map((seconds, n) => {
    const room = fixture(); resetRace(room, 0); room.phase = "racing";
    const p = room.players.get("a"); p.speed = 30;
    let now = 4000, seq = 1;
    for (; now < 4000 + seconds * 1000; now += 1000 / 30) {
      inputPlayer(p, { seq: seq++, steer: 0.3, throttle: 1, drift: true }, now); tick(room, now);
      Object.assign(p, trackPoint(0, 10), { heading: 0, index: 10 });
    }
    inputPlayer(p, { seq: seq++, steer: 0, throttle: 1, drift: false }, now); tick(room, now);
    assert.equal(room.events.find(e => e.kind === "drift").tier, n + 1);
    return p.boost;
  });
  assert.ok(boosts[0] < boosts[1] && boosts[1] < boosts[2], String(boosts));
});

test("dash panels boost once per lap and racer stats change real handling", () => {
  const room = fixture(); resetRace(room, 0); room.phase = "racing";
  const p = room.players.get("a");
  Object.assign(p, trackPoint(0, 11.6), { heading: tangentAt(11.6), index: 11, progress: 11, speed: 20 });
  inputPlayer(p, { seq: 1, steer: 0, throttle: 1 }, 5000); tick(room, 5000);
  assert.ok(p.boost > 0.9);
  assert.equal(room.events.filter(e => e.kind === "dash").length, 1);
  p.boost = 0; inputPlayer(p, { seq: 2, steer: 0, throttle: 1 }, 5033); tick(room, 5033);
  assert.equal(room.events.filter(e => e.kind === "dash").length, 1);
  const top = racer => {
    const r = fixture(); resetRace(r, 0); r.phase = "racing";
    const k = r.players.get("a"); k.racer = racer;
    for (let f = 0; f < 150; f++) {
      const now = 4000 + f * 1000 / 30;
      Object.assign(k, trackPoint(0, 40), { heading: tangentAt(40), index: 40, progress: 40 });
      inputPlayer(k, { seq: f + 1, steer: 0, throttle: 1 }, now); tick(r, now);
    }
    return k.speed;
  };
  assert.ok(top(2) > top(0) && top(0) > top(1), [top(0), top(1), top(2)].join());
});
