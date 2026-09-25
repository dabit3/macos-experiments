// Director client: connects to a Voxelhearth server running with --test-mode
// and drives players through the JSON-over-WebSocket director channel.
import WebSocket from 'ws';

export class Director {
  constructor(url, key = 'voxelhearth-director') {
    this.url = url;
    this.key = key;
    this.ws = null;
    this.pending = new Map(); // drive id -> resolver
    this.hashWaiters = new Map(); // hash id -> resolver
    this.queryWaiters = [];
    this.events = [];
    this.listeners = new Set();
    this.seq = 0;
  }

  async connect() {
    this.ws = new WebSocket(this.url);
    await new Promise((res, rej) => {
      this.ws.once('open', res);
      this.ws.once('error', rej);
    });
    this.ws.on('message', (raw) => this._onMessage(JSON.parse(raw.toString())));
    const ok = new Promise((res, rej) => {
      const t = setTimeout(() => rej(new Error('director handshake timeout')), 5000);
      this.once((m) => m.t === 'director_ok', (m) => {
        clearTimeout(t);
        res(m);
      });
    });
    this.send({ t: 'director', key: this.key });
    return ok;
  }

  close() {
    this.ws?.close();
  }

  send(m) {
    this.ws.send(JSON.stringify(m));
  }

  once(pred, cb) {
    const l = (m) => {
      if (pred(m)) {
        this.listeners.delete(l);
        cb(m);
      }
    };
    this.listeners.add(l);
  }

  _onMessage(m) {
    for (const l of [...this.listeners]) l(m);
    if (m.t === 'hashes') {
      const w = this.hashWaiters.get(m.id);
      if (w) {
        this.hashWaiters.delete(m.id);
        w(m);
      }
      return;
    }
    if (m.t === 'director_event') {
      const e = m.event ?? {};
      this.events.push({ room: m.room, ...e });
      if (e.t === 'drive_done' && this.pending.has(e.id)) {
        const r = this.pending.get(e.id);
        this.pending.delete(e.id);
        r(e);
      } else if (e.t === 'query' && this.queryWaiters.length) {
        this.queryWaiters.shift()(e);
      }
    }
  }

  /** Drive one player; resolves with the client's drive_done result. */
  drive(player, action, { timeout = 30000, room } = {}) {
    const id = `d${++this.seq}`;
    return new Promise((res, rej) => {
      const t = setTimeout(() => {
        this.pending.delete(id);
        rej(new Error(`drive ${id} (${player}: ${action.t}) timed out after ${timeout}ms`));
      }, timeout);
      this.pending.set(id, (e) => {
        clearTimeout(t);
        res(e);
      });
      this.send({ t: 'drive', id, player, action, room });
    });
  }

  /** Drive and throw unless the client reported ok. */
  async must(player, action, opts) {
    const r = await this.drive(player, action, opts);
    if (!r.ok) throw new Error(`${player} ${action.t} failed: ${JSON.stringify(r)}`);
    return r;
  }

  /** Same action on many players in parallel. */
  all(players, action, opts) {
    return Promise.all(players.map((p) => this.must(p, action, opts)));
  }

  /** Ask every client in the room for its world/chat hashes. */
  hashes(room, region) {
    return new Promise((res, rej) => {
      const t = setTimeout(() => rej(new Error('hash_request timed out')), 12000);
      this.once((m) => m.t === 'hashes', (m) => {
        clearTimeout(t);
        res(m);
      });
      this.send({ t: 'hash_request', room, region });
    });
  }

  /** Server-side room snapshot; optional cmd is executed as the host. */
  query(room, { cmd, region } = {}) {
    return new Promise((res, rej) => {
      const t = setTimeout(() => rej(new Error('director_query timed out')), 8000);
      this.queryWaiters.push((e) => {
        clearTimeout(t);
        res(e);
      });
      this.send({ t: 'director_query', room, cmd, region });
    });
  }

  /** Wait for a director event matching pred. */
  waitEvent(pred, timeout = 30000, label = 'event') {
    const hit = this.events.find(pred);
    if (hit) return Promise.resolve(hit);
    return new Promise((res, rej) => {
      const t = setTimeout(() => {
        this.listeners.delete(l);
        rej(new Error(`timed out waiting for ${label}`));
      }, timeout);
      const l = (m) => {
        if (m.t !== 'director_event') return;
        const e = { room: m.room, ...(m.event ?? {}) };
        if (pred(e)) {
          clearTimeout(t);
          this.listeners.delete(l);
          res(e);
        }
      };
      this.listeners.add(l);
    });
  }

  /** Wait until the named player has joined a room. */
  waitJoined(name, timeout = 60000) {
    return this.waitEvent((e) => e.t === 'joined' && e.player === name, timeout, `${name} to join`);
  }

  waitPhase(room, phase, timeout = 60000) {
    return this.waitEvent((e) => e.t === 'phase' && e.room === room && e.phase === phase, timeout, `room ${room} phase=${phase}`);
  }
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
