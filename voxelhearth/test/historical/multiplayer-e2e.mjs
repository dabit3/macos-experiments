// Four-platform multiplayer end-to-end test.
//
// Expects a --test-mode server (see multiplayer-e2e.sh, which starts it and
// the emulators). Launches web (Playwright), iOS (simctl), Android (adb) and
// macOS (native binary), joins all of them to one room, plays a scripted
// match through the director channel, verifies shared world / chat / results
// across every client, and writes screenshots, a 2x2 recording and a report.
//
// env: VH_PLATFORMS=web,ios,android,macos  VH_OUT=<dir>  VH_WS=ws://localhost:8787/ws
//      VH_WEB=http://localhost:8787  VH_ANDROID_WS=ws://10.0.2.2:8787/ws
import { chromium } from 'playwright';
import { spawn, execFileSync, execSync } from 'node:child_process';
import { mkdirSync, writeFileSync, readdirSync, existsSync, rmSync, appendFileSync, readFileSync, renameSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Director, sleep } from './lib/director.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const platforms = (process.env.VH_PLATFORMS ?? 'web,ios,android,macos').split(',').map((s) => s.trim()).filter(Boolean);
const out = resolve(process.env.VH_OUT ?? join(root, '.devin/clone-this/voxelhearth/evidence/tests/e2e-latest'));
const wsUrl = process.env.VH_WS ?? 'ws://localhost:8787/ws';
const webUrl = process.env.VH_WEB ?? 'http://localhost:8787';
const androidWs = process.env.VH_ANDROID_WS ?? 'ws://10.0.2.2:8787/ws';
const ROOM = process.env.VH_ROOM ?? 'HEARTH';
const SEED = 1234;
const BUNDLE = 'com.voxelhearth.voxelhearth';
const macBin = join(root, 'app/build/macos/Build/Products/Debug/Voxelhearth.app/Contents/MacOS/Voxelhearth');
const iosApp = join(root, 'app/build/ios/iphonesimulator/Runner.app');
const apk = join(root, 'app/build/app/outputs/flutter-apk/app-debug.apk');
const androidSerial = process.env.ANDROID_SERIAL ?? 'emulator-5554';

for (const sub of ['screenshots', 'frames', 'video-web', 'visual']) {
  rmSync(join(out, sub), { recursive: true, force: true });
  mkdirSync(join(out, sub), { recursive: true });
}
const logPath = join(out, 'e2e.log');
rmSync(logPath, { force: true });
const report = { startedAt: new Date().toISOString(), platforms, room: ROOM, seed: SEED, steps: [], checks: [], failures: [] };
const log = (...a) => {
  const line = `[${new Date().toISOString().slice(11, 23)}] ${a.map((x) => (typeof x === 'string' ? x : JSON.stringify(x))).join(' ')}`;
  console.log(line);
  appendFileSync(logPath, line + '\n');
};
const check = (name, ok, detail) => {
  report.checks.push({ name, ok, detail });
  log(ok ? 'PASS' : 'FAIL', name, detail ?? '');
  if (!ok) report.failures.push(name);
};

// Player name per platform; the director can address `@platform` too.
const NAME = { web: 'Web', ios: 'iOS', android: 'Android', macos: 'Mac' };
const players = platforms.map((p) => NAME[p]);

// ----------------------------------------------------------------- launchers
const procs = [];
let browser, page;
let iosOrientation = 'LandscapeLeft';
const sh = (cmd, opts = {}) => execSync(cmd, { stdio: ['ignore', 'pipe', 'pipe'], encoding: 'utf8', ...opts }).trim();

const launch = {
  async web() {
    browser = await chromium.launch({ channel: 'chrome', headless: false, args: ['--use-gl=angle', '--enable-unsafe-swiftshader'] });
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 }, recordVideo: { dir: join(out, 'video-web'), size: { width: 1280, height: 800 } } });
    page = await ctx.newPage();
    page.on('pageerror', (e) => log('[web pageerror]', e.message));
    page.on('console', (m) => { if (m.type() === 'error') log('[web console]', m.text().split('\n')[0]); });
    await page.goto(`${webUrl}/?name=${NAME.web}&test=1&server=${encodeURIComponent(wsUrl)}`);
  },
  async macos() {
    try { sh('pkill -f Voxelhearth.app/Contents/MacOS/Voxelhearth'); } catch { /* none running */ }
    const p = spawn(macBin, [], { env: { ...process.env, VH_NAME: NAME.macos, VH_TEST: '1', VH_SERVER: wsUrl, VH_WINDOW: '1280x800' }, stdio: ['ignore', 'pipe', 'pipe'] });
    p.stdout.on('data', (d) => appendFileSync(join(out, 'macos.log'), d));
    p.stderr.on('data', (d) => appendFileSync(join(out, 'macos.log'), d));
    procs.push(p);
  },
  async ios() {
    const prefs = JSON.parse(sh('defaults export com.apple.iphonesimulator - | plutil -convert json -o - -'));
    iosOrientation = prefs.DevicePreferences?.[prefs.CurrentDeviceUDID]?.SimulatorWindowOrientation ?? iosOrientation;
    report.iosCaptureOrientation = iosOrientation;
    log('iOS capture orientation', iosOrientation);
    sh(`xcrun simctl terminate booted ${BUNDLE} || true`);
    sh(`xcrun simctl install booted "${iosApp}"`);
    sh(`SIMCTL_CHILD_VH_NAME=${NAME.ios} SIMCTL_CHILD_VH_TEST=1 SIMCTL_CHILD_VH_SERVER=${wsUrl} xcrun simctl launch booted ${BUNDLE}`);
  },
  async android() {
    sh(`adb -s ${androidSerial} wait-for-device`);
    sh(`adb -s ${androidSerial} install -r -t "${apk}"`, { timeout: 600000 });
    sh(`adb -s ${androidSerial} shell am start -W -n ${BUNDLE}/.MainActivity --es VH_NAME ${NAME.android} --es VH_TEST 1 --es VH_SERVER ${androidWs}`, { timeout: 300000 });
  },
};

// ----------------------------------------------------------------- screenshots
let macWin = null;
const winid = () => {
  if (macWin) return macWin;
  if (!existsSync('/tmp/vh-winid')) execFileSync('swiftc', ['-O', join(here, 'tools/winid.swift'), '-o', '/tmp/vh-winid']);
  const id = sh('/tmp/vh-winid Voxelhearth');
  if (id) macWin = id;
  return macWin;
};
// Normalize the portrait framebuffer using the device's landscape orientation.
const upright = (file, orientation = 'LandscapeLeft') => {
  const fd = readFileSync(file);
  if (fd.readUInt32BE(20) <= fd.readUInt32BE(16)) return;
  const transpose = orientation === 'LandscapeRight' ? 'transpose=1' : 'transpose=2';
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', file, '-vf', transpose, `${file}.rot.png`]);
  renameSync(`${file}.rot.png`, file);
};
const shot = {
  web: (file) => page.screenshot({ path: file }),
  macos: async (file) => { const id = winid(); if (id) sh(`screencapture -x -o -l ${id} "${file}"`); },
  ios: async (file) => { sh(`xcrun simctl io booted screenshot "${file}"`); upright(file, iosOrientation); },
  android: async (file) => { execSync(`adb -s ${androidSerial} exec-out screencap -p > "${file}"`, { timeout: 120000 }); upright(file); },
};
const snapAll = async (phase) => {
  for (const p of platforms) {
    const f = join(out, 'screenshots', `${p}-${phase}.png`);
    try { await shot[p](f); log('screenshot', f); } catch (e) { log('screenshot failed', p, phase, e.message); }
  }
};

// Periodic frames from every platform → 2x2 recording (ffmpeg) at the end.
let frameTimer = null, frameNo = 0, framing = false;
const frame = async () => {
  if (framing) return;
  framing = true;
  const n = String(frameNo++).padStart(4, '0');
  await Promise.all(platforms.map(async (p) => {
    const dir = join(out, 'frames', p);
    mkdirSync(dir, { recursive: true });
    try { await shot[p](join(dir, `${n}.png`)); } catch { /* skip frame */ }
  }));
  framing = false;
};
const startRecording = () => { frameTimer = setInterval(frame, 1200); };
// Chapter markers (frame index at the moment of the call) feed the edited review video.
const markers = [];
const mark = async (title, caption, ...notes) => {
  while (framing) await sleep(50);
  markers.push({ frame: frameNo, title, caption, notes });
  log('chapter', title);
};
const stopRecording = async () => {
  clearInterval(frameTimer);
  while (framing) await sleep(50);
  const inputs = [], filters = [];
  platforms.forEach((p, i) => {
    const dir = join(out, 'frames', p);
    if (!existsSync(dir) || readdirSync(dir).length === 0) return;
    inputs.push(`-framerate 1 -pattern_type glob -i "${dir}/*.png"`);
    filters.push(`[${filters.length}:v]scale=960:600:force_original_aspect_ratio=decrease,pad=960:600:(ow-iw)/2:(oh-ih)/2:color=0x101014[v${filters.length}]`);
  });
  // Tile order (row-major) follows VH_PLATFORMS; recorded in report.json.
  report.recordingLayout = platforms.filter((p) => existsSync(join(out, 'frames', p)));
  if (!inputs.length) return null;
  const n = filters.length;
  const layout = n === 1 ? '[v0]copy[out]'
    : n === 2 ? '[v0][v1]hstack=inputs=2[out]'
      : n === 3 ? '[v0][v1]hstack=inputs=2[top];[v2]pad=1920:600:480:0:color=0x101014[bot];[top][bot]vstack=inputs=2[out]'
        : '[v0][v1]hstack=inputs=2[top];[v2][v3]hstack=inputs=2[bot];[top][bot]vstack=inputs=2[out]';
  const mp4 = join(out, 'four-way-recording.mp4');
  const cmd = `ffmpeg -y -loglevel error ${inputs.join(' ')} -filter_complex "${filters.join(';')};${layout}" -map "[out]" -r 4 -pix_fmt yuv420p -shortest "${mp4}"`;
  try { sh(cmd, { timeout: 600000 }); log('recording', mp4); return mp4; } catch (e) { log('ffmpeg failed', e.message.split('\n')[0]); return null; }
};
// Edited review video (tools/review-video.mjs): title card, chapter cards from the
// markers above, captioned side-by-side frames of the first two platforms, check summary.
const LABEL = { web: 'Web (Chrome via Playwright)', ios: 'iOS Simulator', android: 'Android emulator', macos: 'macOS (native)' };
const editReview = async () => {
  if (process.env.VH_REVIEW === '0') return null;
  const recorded = platforms.filter((p) => existsSync(join(out, 'frames', p)) && readdirSync(join(out, 'frames', p)).length > 0);
  if (!recorded.length || !markers.length) return null;
  const shown = recorded.includes('web') && recorded.includes('ios') ? ['web', 'ios'] : recorded.slice(0, 2);
  const chapters = markers.map((m, i) => ({ title: m.title, caption: m.caption, notes: m.notes, from: m.frame, to: i + 1 < markers.length ? markers[i + 1].frame : frameNo }))
    .filter((c) => c.to > c.from);
  const scriptFile = join(out, 'review-script.json');
  writeFileSync(scriptFile, JSON.stringify({
    title: `Voxelhearth · ${shown.map((p) => NAME[p]).join(' × ')} multiplayer`,
    subtitle: `Automated e2e · room ${ROOM} · seed ${SEED} · ${report.startedAt.slice(0, 19).replace('T', ' ')}Z`,
    footer: `${report.failures.length ? 'FAILED' : 'PASSED'} · ${report.checks.filter((c) => c.ok).length}/${report.checks.length} checks · evidence ${out.split('/').slice(-1)[0]}`,
    fps: 1 / 1.2,
    sources: Object.fromEntries(shown.map((p) => [p, { frames: join(out, 'frames', p), label: LABEL[p] }])),
    chapters,
    checks: report.checks.map((c) => ({ name: c.name, ok: c.ok })),
  }, null, 2));
  const mp4 = join(out, 'review-video.mp4');
  try {
    execFileSync('node', [join(here, 'tools/review-video.mjs'), scriptFile, mp4], { stdio: ['ignore', 'pipe', 'pipe'], timeout: 900000 });
    log('review video', mp4);
    return mp4;
  } catch (e) { log('review video failed', String(e.stderr ?? e.message).split('\n').slice(-3).join(' ')); return null; }
};

// ----------------------------------------------------------------- helpers
const d = new Director(wsUrl);
const step = async (label, fn) => {
  const t0 = Date.now();
  try {
    const r = await fn();
    report.steps.push({ label, ms: Date.now() - t0, ok: true });
    log(label.padEnd(28), `${Date.now() - t0}ms`, typeof r === 'undefined' ? '' : JSON.stringify(r).slice(0, 200));
    return r;
  } catch (e) {
    report.steps.push({ label, ms: Date.now() - t0, ok: false, error: e.message });
    throw e;
  }
};
// Placement can be blocked by a wandering bot standing in the cell; retry a few times.
const placeAt = async (name, [x, y, z]) => {
  let last;
  for (let attempt = 0; attempt < 8; attempt++) {
    last = await d.drive(name, { t: 'place_at', x, y, z }, { timeout: 20000 });
    if (last.ok) return last;
    log(`${name} place_at ${x},${y},${z} blocked (attempt ${attempt + 1})`, JSON.stringify(last).slice(0, 160));
    await sleep(1500);
  }
  throw new Error(`${name} place_at ${x},${y},${z} failed: ${JSON.stringify(last)}`);
};
const same = (vals) => vals.every((v) => JSON.stringify(v) === JSON.stringify(vals[0]));
const waitConnected = async (name, timeoutMs) => {
  const deadline = Date.now() + timeoutMs;
  let last;
  while (Date.now() < deadline) {
    try {
      last = await d.drive(name, { t: 'screen' }, { timeout: 5000 });
      if (last.ok && last.connected) return last;
    } catch (e) { last = { error: e.message }; }
    await sleep(1000);
  }
  throw new Error(`${name} never connected: ${JSON.stringify(last)}`);
};

// ----------------------------------------------------------------- scenario
let recording = null;
try {
  await d.connect();
  log('director connected', wsUrl, 'platforms', platforms);

  for (const p of platforms) await step(`launch ${p}`, () => launch[p]());
  for (const p of platforms) await step(`connect ${NAME[p]}`, () => waitConnected(NAME[p], p === 'android' ? 600000 : 120000));
  startRecording();
  await snapAll('home');
  await mark('Join & Lobby', 'Every client joins the same room by code and readies up', `room ${ROOM} · seed ${SEED}`, ...platforms.map((p) => `${NAME[p]} on ${p}`));

  const host = players[0];
  await step('create room', () => d.must(host, { t: 'create_room', code: ROOM, name: 'Hearth e2e', seed: SEED, bots: 1, freezeTime: true, startTime: 6000, spawnMobs: false }));
  await step('host in lobby', () => d.must(host, { t: 'wait_screen', screen: 'lobby' }));
  for (const n of players.slice(1)) await step(`${n} joins`, () => d.must(n, { t: 'join_room', code: ROOM }));
  await step('all in lobby', () => d.all(players, { t: 'wait_screen', screen: 'lobby', timeout: 60 }, { timeout: 70000 }));
  await step('all ready', () => d.all(players, { t: 'ready', on: true }));
  await sleep(2500);
  await snapAll('lobby');
  const lobby = await d.query(ROOM);
  check('all players in one lobby', players.every((n) => lobby.state.players.some((p) => p.name === n)), lobby.state.players.map((p) => `${p.name}(${p.platform})`).join(', '));

  await step('start match', () => d.must(host, { t: 'start_match' }));
  await step('all in game', () => d.all(players, { t: 'wait_game', timeout: 180 }, { timeout: 200000 }));
  await mark('Gameplay', 'Match starts: frozen noon, deterministic world, one server bot', 'lobby → playing on every client');
  await sleep(3000);
  await snapAll('gameplay');

  // Shared structure: a row of blocks (one per player) on solid ground three
  // blocks in front of spawn, then a second row on top. Cells are chosen from
  // the server's view of the terrain so every player can see the support face.
  const st = await step('host state', () => d.must(host, { t: 'state' }));
  const bx = Math.floor(st.x), by = Math.floor(st.y), bz = Math.floor(st.z);
  const STONE = 9;
  const STONE_PICK = 111;
  const span = 4;
  const probe = await d.query(ROOM, { region: [bx - span, by - 1, bz + 3, bx + span, by + 1, bz + 3] });
  const w = 2 * span + 1;
  const at = (dx, dy) => probe.blocks[dy * w + (dx + span)]; // y-major, then x
  const cells = [];
  for (const dx of [0, 1, -1, 2, -2, 3, -3, 4, -4]) {
    if (at(dx, 0) !== 0 && at(dx, 1) === 0 && at(dx, 2) === 0) cells.push([bx + dx, by, bz + 3]);
    if (cells.length === players.length) break;
  }
  check('found a flat row for the shared structure', cells.length === players.length, JSON.stringify(cells));
  if (cells.length !== players.length) throw new Error('terrain in front of spawn is not flat enough');
  const upper = cells.map(([x, y, z]) => [x, y + 1, z]);
  await step('give blocks', () => d.all(players, { t: 'give', id: STONE, count: 8, slot: 3 }));
  await step('give picks', () => d.all(players, { t: 'give', id: STONE_PICK, count: 1, slot: 4 }));
  await step('select blocks', () => d.all(players, { t: 'select_slot', slot: 3 }));
  await mark('Shared structure', 'Each client places two stone blocks in one shared row', `cells ${JSON.stringify(cells)}`, 'placed on the server, echoed to every client');
  await sleep(600);
  for (let i = 0; i < players.length; i++) {
    const [x, y, z] = cells[i];
    await step(`${players[i]} places ${x},${y},${z}`, () => placeAt(players[i], cells[i]));
    await sleep(400);
  }
  for (let i = 0; i < players.length; i++) {
    const [x, y, z] = upper[i];
    await step(`${players[i]} places ${x},${y},${z}`, () => placeAt(players[i], upper[i]));
    await sleep(400);
  }
  await sleep(1500);
  // Step back so the whole structure is in frame for the screenshot, then return.
  const posts = await d.all(players, { t: 'state' });
  await d.all(players, { t: 'walk', dir: 'back', seconds: 0.9 });
  const mid = cells[0];
  await d.all(players, { t: 'look_at', x: mid[0], y: mid[1] + 1, z: mid[2] });
  await sleep(600);
  await snapAll('structure');
  await Promise.all(players.map((p, i) => d.drive(p, { t: 'teleport', x: posts[i].x, y: posts[i].y, z: posts[i].z })));
  await sleep(600);
  // Each player breaks the upper block placed by the next player round-robin.
  await step('select picks', () => d.all(players, { t: 'select_slot', slot: 4 }));
  await mark('Breaking & chat', 'Each client breaks the block placed by the next one, then chats', 'round-robin break', 'chat history compared on every client');
  await sleep(300);
  for (let i = 0; i < players.length; i++) {
    const [x, y, z] = upper[(i + 1) % players.length];
    await step(`${players[i]} breaks ${x},${y},${z}`, () => d.must(players[i], { t: 'break', x, y, z }, { timeout: 30000 }));
    await sleep(400);
  }
  for (let i = 0; i < players.length; i++) {
    await step(`${players[i]} chats`, () => d.must(players[i], { t: 'chat', text: `${players[i]} checking in from ${platforms[i]}` }));
    await sleep(300);
  }
  await step('open chat everywhere', () => d.all(players, { t: 'toggle_chat', open: true }));
  await sleep(2000);
  await snapAll('chat');
  await step('close chat', () => d.all(players, { t: 'toggle_chat', open: false }));
  await sleep(1500);

  // ---- reconnect: the first client drops its socket mid-match and must rejoin
  // the same room via its session token, then converge to the same state as
  // everyone else (verified by the hash checks below).
  await mark('Reconnect', `${players[0]} drops its socket mid-match and rejoins with its session token`, 'same room, same identity, converged state');
  const rc = await step(`${players[0]} drops connection and rejoins`, () => d.drive(players[0], { t: 'drop_connection', timeout: 30 }, { timeout: 40000 }));
  check('dropped client rejoined the same room', rc?.ok === true && rc.room === ROOM && rc.phase === 'playing', JSON.stringify(rc));
  await step('rejoined client is in-match again', () => d.must(players[0], { t: 'wait_game', timeout: 20 }, { timeout: 25000 }));
  await sleep(1500);

  // ---- verification while playing
  const xs = cells.map((c) => c[0]);
  const region = [Math.min(...xs), by, bz + 3, Math.max(...xs), by + 1, bz + 3];
  await mark('Verification', 'World, chat and structure hashes compared across clients and server', 'director hash request → every client answers');
  const h = await step('hashes', () => d.hashes(ROOM, region));
  check('every client answered the hash request', !h.timedOut && h.missing.length === 0, `missing=${JSON.stringify(h.missing)}`);
  const clientWorld = players.map((n) => h.clients[n]?.world);
  check('world hash identical on all clients + server', same([h.server.world, ...clientWorld]), JSON.stringify({ server: h.server.world, clients: Object.fromEntries(players.map((n) => [n, h.clients[n]?.world])) }));
  check('chat hash identical on all clients + server', same([h.server.chat, ...players.map((n) => h.clients[n]?.chat)]), JSON.stringify({ server: h.server.chat, clients: Object.fromEntries(players.map((n) => [n, h.clients[n]?.chat])) }));
  check('structure region identical on all clients', same(players.map((n) => h.clients[n]?.region)), JSON.stringify(h.clients[players[0]]?.region));
  const q = await d.query(ROOM, { region });
  const expected = [];
  for (const y of [by, by + 1]) for (let x = region[0]; x <= region[3]; x++) expected.push(y === by && xs.includes(x) ? STONE : 0);
  check('server structure matches script (lower row placed, upper row broken)', JSON.stringify(q.blocks) === JSON.stringify(expected), JSON.stringify(q.blocks));
  const logs = await Promise.all(players.map((n) => d.must(n, { t: 'chat_log' })));
  check('chat history identical on all clients', same(logs.map((l) => l.chat)), `${logs[0].chat.length} lines`);
  check('every player line present in chat', players.every((n) => logs[0].chat.some((c) => c.from === n && c.text.includes('checking in'))), '');
  const states = await Promise.all(players.map((n) => d.must(n, { t: 'state' })));
  report.fps = Object.fromEntries(players.map((n, i) => [n, states[i].fps]));
  log('measured fps', report.fps);
  report.gameplayState = Object.fromEntries(players.map((n, i) => [n, states[i]]));

  // ---- results
  await mark('Results', 'Host ends the match: identical scoreboard and fingerprints everywhere');
  await step('end match', () => d.must(host, { t: 'end_match' }));
  await step('all on results', () => d.all(players, { t: 'wait_screen', screen: 'results', timeout: 60 }, { timeout: 70000 }));
  await sleep(2500);
  await snapAll('results');
  const results = await Promise.all(players.map((n) => d.must(n, { t: 'results' })));
  const finalServer = await step('server results state', () => d.query(ROOM));
  report.authoritativeResults = { phase: finalServer.state.phase, worldHash: finalServer.worldHash, chatHash: finalServer.chatHash };
  check('server is in results phase', finalServer.state.phase === 'results', finalServer.state.phase);
  check('final scoreboard identical on all clients', same(results.map((r) => r.results)), JSON.stringify(results[0].results));
  check('final world/chat fingerprints identical on all clients', same(results.map((r) => [r.worldHash, r.chatHash])), JSON.stringify([results[0].worldHash, results[0].chatHash]));
  check('final world/chat fingerprints match server', results[0].worldHash === finalServer.worldHash && results[0].chatHash === finalServer.chatHash, JSON.stringify({ client: [results[0].worldHash, results[0].chatHash], server: [finalServer.worldHash, finalServer.chatHash] }));
  const humanRows = results[0].results.filter((r) => !r.bot);
  check('scoreboard credits 2 placed + 1 broken per player', humanRows.length === players.length && humanRows.every((r) => r.placed === 2 && r.broken === 1), JSON.stringify(humanRows.map((r) => [r.name, r.platform, r.score, r.placed, r.broken])));
  report.results = results[0];
  await mark('Visual parity fixtures', 'Every client renders identical fixture data; web is the layout baseline', 'lobby, results, home fixtures', 'text/icon nodes compared within 2 logical px');

  // ---- visual matrix: every client renders identical fixture data; web is the baseline.
  // Raw screenshots are rasterizer-dependent (font AA and glyph advances differ per
  // OS), so the parity check is structural: every text/icon node must match in
  // normalized text, position and size within 2 logical px. Layout-map and raw
  // pixel diffs are recorded alongside for disclosure.
  const visualDir = join(out, 'visual');
  const png = (args) => JSON.parse(sh(`python3 "${join(here, 'tools/pngcompare.py')}" ${args}`, { timeout: 600000 }).split('\n').pop());
  const pngTry = (args) => { try { return png(args); } catch (e) { return JSON.parse(e.stdout?.toString().trim().split('\n').pop() || '{"error":"tool failed"}'); } };
  report.visual = [];
  for (const screen of ['lobby', 'results', 'home']) {
    await step(`fixture ${screen}`, () => d.all(players, { t: 'fixture', screen }, { timeout: 30000 }));
    await sleep(1500);
    for (const p of platforms) {
      const f = join(visualDir, `${p}-${screen}.png`);
      try {
        await shot[p](f);
        if (p === 'macos') { sh(`mv "${f}" "${join(visualDir, `${p}-${screen}.window.png`)}"`); png(`crop "${join(visualDir, `${p}-${screen}.window.png`)}" "${f}" 800`); }
      } catch (e) { log('visual screenshot failed', p, screen, e.message); }
      const lay = await d.must(NAME[p], { t: 'layout' }, { timeout: 15000 });
      writeFileSync(join(visualDir, `${p}-${screen}.layout.json`), JSON.stringify(lay, null, 1));
      png(`layout "${join(visualDir, `${p}-${screen}.layout.json`)}" "${join(visualDir, `${p}-${screen}.layout.png`)}"`);
    }
    // Normalized layout maps: text boxes within 2 logical px of the web box are
    // drawn at the web box (glyph-advance jitter); everything else is drawn as-is.
    if (platforms.includes('web')) {
      for (const p of platforms.filter((x) => x !== 'web')) {
        png(`layout "${join(visualDir, `${p}-${screen}.layout.json`)}" "${join(visualDir, `${p}-${screen}.layout.normalized.png`)}" --snap-to "${join(visualDir, `web-${screen}.layout.json`)}" --tolerance 2`);
      }
    }
    if (!platforms.includes('web')) continue;
    for (const p of platforms.filter((x) => x !== 'web')) {
      const layoutRaw = pngTry(`diff "${join(visualDir, `web-${screen}.layout.png`)}" "${join(visualDir, `${p}-${screen}.layout.png`)}" "${join(visualDir, `${p}-${screen}.layout.raw.diff.png`)}"`);
      const layout = pngTry(`diff "${join(visualDir, `web-${screen}.layout.png`)}" "${join(visualDir, `${p}-${screen}.layout.normalized.png`)}" "${join(visualDir, `${p}-${screen}.layout.diff.png`)}"`);
      const raw = existsSync(join(visualDir, `${p}-${screen}.png`))
        ? pngTry(`diff "${join(visualDir, `web-${screen}.png`)}" "${join(visualDir, `${p}-${screen}.png`)}" "${join(visualDir, `${p}-${screen}.raw.diff.png`)}"`)
        : { error: 'no screenshot' };
      const nodes = pngTry(`nodes "${join(visualDir, `web-${screen}.layout.json`)}" "${join(visualDir, `${p}-${screen}.layout.json`)}" --tolerance 2`);
      writeFileSync(join(visualDir, `${p}-${screen}.nodes.json`), JSON.stringify(nodes, null, 1));
      // A phone-sized client renders the responsive phone layout; it is not
      // comparable to the 1280x800 desktop baseline and is recorded as such.
      const sameViewport = JSON.stringify(nodes.reference_viewport) === JSON.stringify(nodes.actual_viewport);
      report.visual.push({ screen, platform: p, baseline: 'web', viewport: nodes.actual_viewport, sameViewport, nodes, layout, layoutRaw, raw });
      const detail = sameViewport
        ? JSON.stringify({ nodes: `${nodes.matched}/${nodes.nodes}`, exact: nodes.exact, mismatched: nodes.mismatched_count, normalizedPx: layout.different_pixels, layoutPx: layoutRaw.different_pixels, rawPx: raw.different_pixels ?? raw.error, total: layout.total_pixels })
        : JSON.stringify({ viewport: nodes.actual_viewport, baseline: nodes.reference_viewport, note: 'phone layout family; not comparable to desktop baseline' });
      // Home intentionally shows a per-platform badge; phones use the responsive layout. Both are recorded, not asserted.
      if (p === 'macos' && screen !== 'home') check(`visual layout parity web→macos (${screen})`, nodes.ok === true && layout.different_pixels === 0, detail);
      else log(`visual ${p} ${screen} (recorded only)`, detail);
    }
  }
} catch (e) {
  log('ERROR', e.stack ?? e.message);
  report.failures.push(`exception: ${e.message}`);
  await snapAll('failure').catch(() => {});
} finally {
  recording = await stopRecording();
  report.recording = recording;
  report.markers = markers;
  report.reviewVideo = await editReview();
  report.finishedAt = new Date().toISOString();
  report.passed = report.failures.length === 0;
  writeFileSync(join(out, 'report.json'), JSON.stringify(report, null, 2));
  const md = [
    `# Voxelhearth four-platform multiplayer e2e — ${report.passed ? 'PASSED' : 'FAILED'}`,
    '',
    `Platforms: ${platforms.join(', ')} · room ${ROOM} · seed ${SEED} · ${report.startedAt} → ${report.finishedAt}`,
    '',
    '| check | result | detail |', '|---|---|---|',
    ...report.checks.map((c) => `| ${c.name} | ${c.ok ? 'pass' : 'FAIL'} | \`${String(c.detail ?? '').replace(/\|/g, '\\|').slice(0, 300)}\` |`),
    '',
    ...(report.visual?.length ? [
      '## Visual matrix (identical fixture data, web = baseline, 1280x800 logical)', '',
      '| screen | platform | nodes matched (±2px) | exact nodes | normalized layout px diff | raw layout px diff | raw screenshot px diff | asserted |', '|---|---|---|---|---|---|---|---|',
      ...report.visual.map((v) => v.sameViewport
        ? `| ${v.screen} | ${v.platform} | ${v.nodes.matched ?? '-'}/${v.nodes.nodes ?? '-'} | ${v.nodes.exact ?? '-'} | ${v.layout.different_pixels ?? v.layout.error} | ${v.layoutRaw.different_pixels ?? v.layoutRaw.error} | ${v.raw.different_pixels ?? v.raw.error} | ${v.platform === 'macos' && v.screen !== 'home' ? 'yes' : 'recorded only'} |`
        : `| ${v.screen} | ${v.platform} | n/a | n/a | n/a | n/a | n/a | phone layout ${v.viewport?.join('x')} — different layout family, not compared |`),
      '',
    ] : []),
    `Screenshots: \`${join(out, 'screenshots')}\``,
    recording ? `Recording: \`${recording}\`` : 'Recording: (not produced)',
    report.reviewVideo ? `Edited review video: \`${report.reviewVideo}\` (chapters in \`review-script.json\`)` : 'Edited review video: (not produced)',
    report.failures.length ? `\nFailures:\n${report.failures.map((f) => `- ${f}`).join('\n')}` : '',
  ].join('\n');
  writeFileSync(join(out, 'report.md'), md);
  log(report.passed ? 'E2E PASSED' : `E2E FAILED: ${report.failures.join('; ')}`);
  try {
    const video = page?.video();
    await page?.context().close();
    if (video) await video.saveAs(join(out, 'web-recording.webm'));
  } catch { /* no video */ }
  await browser?.close().catch(() => {});
  for (const p of procs) p.kill('SIGKILL');
  if (platforms.includes('ios')) sh(`xcrun simctl terminate booted ${BUNDLE} || true`);
  if (platforms.includes('android')) { try { sh(`adb -s ${androidSerial} shell am force-stop ${BUNDLE}`, { timeout: 60000 }); } catch { /* emulator gone */ } }
  d.close();
  process.exit(report.passed ? 0 : 1);
}
