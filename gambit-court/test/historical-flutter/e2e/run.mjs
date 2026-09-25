#!/usr/bin/env node
// Four-platform multiplayer end-to-end orchestrator.
//
// Expects a Gambit Court server running with `--control --frozen-clocks
// --seed N`, the web build served over HTTP, and the native clients
// (ios / android / macos) already launched with GC_AUTOMATION=true and the
// client ids given below. It then drives every client through the server's
// test-control bridge, plays a complete scripted match with two platforms as
// players and two as spectators, and asserts that all four render the same
// game. Screenshots are written per platform and step.
//
//   node run.mjs --server http://127.0.0.1:8765 --web http://127.0.0.1:8770 \
//        --out ../../.devin/clone-this/gambit-court/evidence/tests/e2e \
//        --platforms web,ios,android,macos --white web --black ios
import { chromium } from 'playwright-core';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));

// --------------------------------------------------------------------- args
const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v = 'true'] = a.replace(/^--/, '').split('=');
    return [k, v];
  }),
);
const SERVER = args.server ?? 'http://127.0.0.1:8765';
const WEB = args.web ?? 'http://127.0.0.1:8770';
const OUT = resolve(args.out ?? join(here, 'out'));
const PLATFORMS = (args.platforms ?? 'web,ios,android,macos').split(',');
const WHITE = args.white ?? 'macos';
const BLACK = args.black ?? 'web';
const ANDROID_SERIAL = args.androidSerial ?? 'emulator-5554';
const HEADLESS = args.headless === 'true';
const WINDOW_ID_BIN = args.windowIdBin ?? join(here, 'window_id');
const TIME_CONTROL = { initialMs: 180_000, incrementMs: 2_000 };
const PYTHON = args.python ?? 'python3';
const LOBBY_HOLD_MS = Number(process.env.LOBBY_HOLD_MS ?? 3000);
const MOVE_HOLD_MS = Number(process.env.MOVE_HOLD_MS ?? 0);
const RESULTS_HOLD_MS = Number(process.env.RESULTS_HOLD_MS ?? 0);
const PRE_PARITY_HOLD_MS = Number(process.env.PRE_PARITY_HOLD_MS ?? 0);
for (const hold of [LOBBY_HOLD_MS, MOVE_HOLD_MS, RESULTS_HOLD_MS, PRE_PARITY_HOLD_MS]) {
  if (!Number.isFinite(hold) || hold < 0 || hold > 2_147_483_647) {
    throw new Error('Recording hold durations must be between 0 and 2147483647 milliseconds');
  }
}

// Normalized visual parity: the web build is re-rendered at each native
// client's logical content size (with the same bottom safe-area inset) and
// compared with the native capture after the native title/status bar is
// cropped. Scale and insets come from the native client's own view metrics.
const SPECTATORS = PLATFORMS.filter((p) => p !== WHITE && p !== BLACK);
mkdirSync(OUT, { recursive: true });

if (!PLATFORMS.includes(WHITE) || !PLATFORMS.includes(BLACK)) {
  fail(`players must be among ${PLATFORMS.join(',')}`);
}

// Stable identities; the native launchers use the same ids via --dart-define.
const CLIENT = {
  web: { id: 'web-e2e', name: 'Web Ada' },
  ios: { id: 'ios-e2e', name: 'iOS Bram' },
  android: { id: 'android-e2e', name: 'Android Cass' },
  macos: { id: 'macos-e2e', name: 'macOS Dov' },
};

// Morphy vs Duke of Brunswick & Count Isouard, Paris 1858 (public domain).
// 33 plies: captures, checks, queenside castling, a queen sacrifice and mate.
const SCRIPT =
  'e2e4 e7e5 g1f3 d7d6 d2d4 c8g4 d4e5 g4f3 d1f3 d6e5 f1c4 g8f6 f3b3 d8e7 ' +
  'b1c3 c7c6 c1g5 b7b5 c3b5 c6b5 c4b5 b8d7 e1c1 a8d8 d1d7 d8d7 h1d1 e7e6 ' +
  'b5d7 f6d7 b3b8 d7b8 d1d8';
const EXPECTED_FINAL_FEN =
  '1n1Rkb1r/p4ppp/4q3/4p1B1/4P3/8/PPP2PPP/2K5 b k - 1 17';
const EXPECTED_SAN = [
  'e4', 'e5', 'Nf3', 'd6', 'd4', 'Bg4', 'dxe5', 'Bxf3', 'Qxf3', 'dxe5', 'Bc4',
  'Nf6', 'Qb3', 'Qe7', 'Nc3', 'c6', 'Bg5', 'b5', 'Nxb5', 'cxb5', 'Bxb5+',
  'Nbd7', 'O-O-O', 'Rd8', 'Rxd7', 'Rxd7', 'Rd1', 'Qe6', 'Bxd7+', 'Nxd7',
  'Qb8+', 'Nxb8', 'Rd8#',
];

// ------------------------------------------------------------------ helpers
const log = (...m) => console.log(new Date().toISOString().slice(11, 23), ...m);
const results = { steps: [], assertions: [], screenshots: [], parity: [] };

function fail(message) {
  console.error(`FAIL: ${message}`);
  finish(1);
}

function finish(code) {
  results.passed = code === 0;
  writeFileSync(join(OUT, 'result.json'), JSON.stringify(results, null, 2));
  process.exit(code);
}

function assert(cond, label, detail) {
  results.assertions.push({ label, passed: !!cond, detail });
  if (!cond) fail(`${label}${detail ? ` — ${JSON.stringify(detail)}` : ''}`);
  log('  ok', label);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function control(path, body) {
  const res = await fetch(`${SERVER}${path}`, {
    method: body ? 'POST' : 'GET',
    headers: { 'content-type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`${path} → ${res.status} ${JSON.stringify(json)}`);
  return json;
}

async function ui(platform, command, timeoutMs = 15_000) {
  const report = await control(`/control/clients/${CLIENT[platform].id}/ui`, {
    ...command,
    timeoutMs,
  });
  if (!report.ok) {
    throw new Error(`${platform} ${command.action}: ${report.error ?? 'failed'}`);
  }
  return report;
}

const state = (platform) => ui(platform, { action: 'state' });

async function waitFor(label, predicate, timeoutMs = 60_000, every = 400) {
  const deadline = Date.now() + timeoutMs;
  let last;
  while (Date.now() < deadline) {
    last = await predicate();
    if (last) return last;
    await sleep(every);
  }
  throw new Error(`timeout waiting for ${label}`);
}

async function allStates() {
  const entries = await Promise.all(
    PLATFORMS.map(async (p) => [p, await state(p)]),
  );
  return Object.fromEntries(entries);
}

/// Waits until every client shows the same room sequence number and then
/// returns the per-platform states.
async function converged(label, expectSeq) {
  return waitFor(
    `convergence ${label}`,
    async () => {
      const states = await allStates();
      const seqs = new Set(Object.values(states).map((s) => s.seq));
      const fens = new Set(Object.values(states).map((s) => s.liveFen));
      if (seqs.size !== 1 || fens.size !== 1) return null;
      if (expectSeq != null && [...seqs][0] < expectSeq) return null;
      return states;
    },
    30_000,
    250,
  );
}

// ------------------------------------------------------------- screenshots
let page;
let webSafeBottomPx = 0;
const PARITY_NAME = 'Parity Pat';

function webUrl(safeBottom = 0) {
  const url = new URL(WEB);
  url.searchParams.set('client', CLIENT.web.id);
  url.searchParams.set('name', CLIENT.web.name);
  url.searchParams.set('automation', '1');
  url.searchParams.set('theme', 'dark');
  url.searchParams.set('server', SERVER.replace(/^http/, 'ws') + '/ws');
  if (safeBottom > 0) url.searchParams.set('safeBottom', String(safeBottom));
  return url;
}

/// Reloads the web client with the given bottom safe-area inset (a launch
/// option, so it needs a reload) and waits until it is back online.
async function webSafeBottom(px) {
  if (px === webSafeBottomPx) return;
  webSafeBottomPx = px;
  await page.goto(webUrl(px).toString(), { waitUntil: 'load' });
  await waitFor('web back online', async () => {
    const s = await state('web').catch(() => null);
    return s?.connection === 'online' ? s : null;
  }, 30_000, 300);
  await ui('web', { action: 'set_name', name: PARITY_NAME });
}
let macWindowId;

function macosWindowId() {
  if (macWindowId) return macWindowId;
  const out = spawnSync(WINDOW_ID_BIN, ['Gambit Court'], { encoding: 'utf8' });
  if (out.status !== 0) throw new Error('macOS window not found');
  macWindowId = out.stdout.trim();
  return macWindowId;
}

async function shoot(platform, step) {
  const file = join(OUT, `${platform}-${step}.png`);
  try {
    switch (platform) {
      case 'web':
        await page.screenshot({ path: file });
        break;
      case 'ios':
        execFileSync('xcrun', ['simctl', 'io', 'booted', 'screenshot', file], {
          stdio: 'ignore',
        });
        break;
      case 'android': {
        const png = execFileSync('adb', ['-s', ANDROID_SERIAL, 'exec-out', 'screencap', '-p'], {
          maxBuffer: 64 * 1024 * 1024,
        });
        writeFileSync(file, png);
        break;
      }
      case 'macos':
        execFileSync('screencapture', ['-x', '-o', '-l', macosWindowId(), file]);
        break;
    }
    results.screenshots.push({ platform, step, file });
  } catch (e) {
    log(`  screenshot ${platform}/${step} failed: ${e.message}`);
  }
}

async function shootAll(step) {
  await sleep(600); // let animations settle
  for (const p of PLATFORMS) await shoot(p, step);
}

/// Logical (1x) size of a raw native capture given its device pixel ratio.
function nativeLogicalSize(rawFile, scale) {
  const info = execFileSync('sips', ['-g', 'pixelWidth', '-g', 'pixelHeight', rawFile], { encoding: 'utf8' });
  const px = Number(info.match(/pixelWidth: (\d+)/)[1]);
  const py = Number(info.match(/pixelHeight: (\d+)/)[1]);
  return { width: Math.round(px / scale), height: Math.round(py / scale) };
}

/// Captures `platform` at 1x into `file`, returning its logical size.
function captureNative1x(platform, file, scale) {
  const raw = file.replace(/\.png$/, '-raw.png');
  switch (platform) {
    case 'ios':
      execFileSync('xcrun', ['simctl', 'io', 'booted', 'screenshot', raw], { stdio: 'ignore' });
      break;
    case 'android':
      writeFileSync(raw, execFileSync('adb', ['-s', ANDROID_SERIAL, 'exec-out', 'screencap', '-p'], {
        maxBuffer: 64 * 1024 * 1024,
      }));
      break;
    case 'macos':
      execFileSync('screencapture', ['-x', '-o', '-l', macosWindowId(), raw]);
      break;
  }
  const size = nativeLogicalSize(raw, scale);
  execFileSync('sips', ['-z', String(size.height), String(size.width), raw, '--out', file], { stdio: 'ignore' });
  return size;
}

/// Compares the web reference with a native capture of the same screen. The
/// native view metrics decide the scale, the system bar to crop (anything
/// above the Flutter view plus its top safe-area inset) and the bottom
/// safe-area inset the web client must reserve too.
async function parity(platform, screen, dir) {
  const view = (await ui(platform, { action: 'settle' })).view;
  await sleep(1200); // screen transition + toast fade
  const actual = join(dir, `${platform}-${screen}.png`);
  const size = captureNative1x(platform, actual, view.devicePixelRatio);
  const insetTop = Math.round(size.height - view.height + view.paddingTop);
  const content = { width: size.width, height: size.height - insetTop };
  await webSafeBottom(Math.round(view.paddingBottom));
  await page.setViewportSize(content);
  await ui('web', { action: 'settle' });
  await sleep(700);
  const reference = join(dir, `web-${screen}-${platform}.png`);
  await page.screenshot({ path: reference });
  const name = `${screen}-${platform}`;
  const out = spawnSync(PYTHON, [
    join(here, 'visual_parity.py'), '--name', name, '--reference', reference, '--actual', actual,
    '--out', dir, '--actual-crop-top', String(insetTop),
  ], { encoding: 'utf8' });
  const summary = (out.stdout + out.stderr).trim();
  const report = {
    platform, screen, name, size: content, scale: view.devicePixelRatio, insetTop,
    safeBottom: Math.round(view.paddingBottom), summary, status: out.status,
  };
  results.parity.push(report);
  assert(out.status === 0, `visual parity ${name} (web reference vs ${platform})`, summary);
}

// -------------------------------------------------------------------- main
async function main() {
  log(`players: ${WHITE} (white) vs ${BLACK} (black); spectators: ${SPECTATORS.join(', ')}`);

  // 1. Web client via Playwright.
  let browser;
  if (PLATFORMS.includes('web')) {
    browser = await chromium.launch({
      headless: HEADLESS,
      args: ['--window-size=1000,650', '--window-position=0,25'],
    });
    const context = await browser.newContext({
      viewport: { width: 1000, height: 560 },
      deviceScaleFactor: 1,
    });
    page = await context.newPage();
    const url = webUrl();
    log('opening', url.toString());
    await page.goto(url.toString(), { waitUntil: 'load' });
  }

  // 2. Everyone connected.
  results.steps.push('connect');
  const snapshot = await waitFor(
    'all clients connected',
    async () => {
      const s = await control('/control/state');
      const online = new Set(
        s.clients.filter((c) => c.connected).map((c) => c.clientId),
      );
      const missing = PLATFORMS.filter((p) => !online.has(CLIENT[p].id));
      if (missing.length) {
        log('  waiting for', missing.join(', '));
        return null;
      }
      return s;
    },
    180_000,
    2_000,
  );
  for (const p of PLATFORMS) {
    const c = snapshot.clients.find((c) => c.clientId === CLIENT[p].id);
    assert(c.platform === p, `${p} client reports platform=${c.platform}`);
  }
  const lobby = await allStates();
  for (const p of PLATFORMS) {
    assert(lobby[p].screen === 'lobby', `${p} starts in the lobby`, lobby[p].screen);
  }
  await shootAll('lobby');
  if (!HEADLESS) {
    log(`lobby ready — recording hold ${LOBBY_HOLD_MS}ms`);
    await sleep(LOBBY_HOLD_MS);
  }

  // 3. Create room, seat the second player, spectators join by code.
  results.steps.push('room');
  const created = await ui(WHITE, {
    action: 'create_room',
    side: 'white',
    isPublic: false,
    timeControl: TIME_CONTROL,
  });
  const code = created.roomCode;
  assert(/^[A-Z0-9]{6}$/.test(code), `room created with invite code ${code}`);
  assert(created.status === 'waiting', `${WHITE} is waiting for an opponent`, created.status);
  results.roomCode = code;
  await shoot(WHITE, 'waiting');

  const joined = await ui(BLACK, { action: 'join_room', code });
  assert(joined.mySide === 'b', `${BLACK} joined as black`, joined);
  for (const s of SPECTATORS) {
    const r = await ui(s, { action: 'join_room', code, asSpectator: true });
    assert(r.isSpectator === true, `${s} joined ${code} as spectator`, r);
  }
  const start = await converged('game start');
  for (const p of PLATFORMS) {
    assert(start[p].status === 'playing', `${p} sees the game as playing`, start[p].status);
    assert(start[p].roomCode === code, `${p} is in room ${code}`);
    assert(start[p].white === CLIENT[WHITE].name && start[p].black === CLIENT[BLACK].name,
      `${p} shows the right seats`, [start[p].white, start[p].black]);
    assert(start[p].spectators.length === SPECTATORS.length,
      `${p} lists ${SPECTATORS.length} spectators`, start[p].spectators);
  }
  await shootAll('start');

  // 4. Play the scripted game, checking convergence after every ply.
  results.steps.push('play');
  const moves = SCRIPT.split(' ');
  for (let i = 0; i < moves.length; i++) {
    const mover = i % 2 === 0 ? WHITE : BLACK;
    const uci = moves[i];
    const report = await ui(mover, { action: 'move', uci });
    const san = report.moves.at(-1);
    if (san !== EXPECTED_SAN[i]) fail(`ply ${i + 1}: expected ${EXPECTED_SAN[i]} got ${san}`);
    const states = await converged(`ply ${i + 1}`, report.seq);
    for (const p of PLATFORMS) {
      if (states[p].moveCount !== i + 1 || states[p].moves.at(-1) !== san) {
        fail(`${p} out of sync after ${san}`, states[p]);
      }
    }
    log(`  ply ${String(i + 1).padStart(2)} ${mover.padEnd(7)} ${san.padEnd(6)} seq=${report.seq}`);
    if (MOVE_HOLD_MS > 0) await sleep(MOVE_HOLD_MS);
    if (i === 11) await shootAll('midgame');
    if (i === 22) {
      // After O-O-O: spectator flips the board and browses history.
      const spec = SPECTATORS[0];
      if (spec) {
        await ui(spec, { action: 'flip' });
        const viewed = await ui(spec, { action: 'view_ply', ply: 4 });
        const browsing = await state(spec);
        assert(
          viewed.viewPly === 4 && browsing.fen !== browsing.liveFen && browsing.moveCount === 23,
          `${spec} can browse history while the live move list stays intact`,
          { viewPly: viewed.viewPly, fen: browsing.fen },
        );
        await shoot(spec, 'history');
        await ui(spec, { action: 'view_ply', ply: null });
        await ui(spec, { action: 'flip' });
      }
    }
  }

  // 5. Reconnection: a spectator drops and comes back to the same game.
  results.steps.push('reconnect');
  const dropper = SPECTATORS[1] ?? SPECTATORS[0] ?? BLACK;
  await ui(dropper, { action: 'drop_connection' });
  await sleep(300);
  await shoot(dropper, 'reconnecting');
  const back = await waitFor(
    `${dropper} reconnects`,
    async () => {
      try {
        const s = await state(dropper);
        return s.connection === 'online' && s.roomCode === code ? s : null;
      } catch {
        return null;
      }
    },
    30_000,
    500,
  );
  assert(back.moveCount === moves.length, `${dropper} resumed the same game`, back.moveCount);

  // 6. Final state identical everywhere.
  results.steps.push('results');
  const final = await converged('final');
  const ref = final[PLATFORMS[0]];
  for (const p of PLATFORMS) {
    const s = final[p];
    assert(s.status === 'finished', `${p} shows the game as finished`, s.status);
    assert(s.screen === 'results', `${p} shows the results overlay`, s.screen);
    assert(s.liveFen === EXPECTED_FINAL_FEN, `${p} final FEN matches`, s.liveFen);
    assert(JSON.stringify(s.moves) === JSON.stringify(EXPECTED_SAN), `${p} move list matches`);
    assert(s.score === '1-0', `${p} score is 1-0`, s.score);
    assert(s.result?.reason === 'checkmate', `${p} reason is checkmate`, s.result);
    assert(JSON.stringify(s.clocks) === JSON.stringify(ref.clocks), `${p} clocks match ${PLATFORMS[0]}`,
      [s.clocks, ref.clocks]);
  }
  results.final = Object.fromEntries(PLATFORMS.map((p) => [p, {
    fen: final[p].liveFen, moves: final[p].moves, score: final[p].score,
    result: final[p].result, clocks: final[p].clocks, seq: final[p].seq,
  }]));
  await shootAll('results');
  if (!HEADLESS) {
    log(`results ready — recording hold ${RESULTS_HOLD_MS}ms`);
    await sleep(RESULTS_HOLD_MS);
  }

  // 7. PGN export agrees across players and spectators.
  const pgns = await Promise.all(PLATFORMS.map((p) => ui(p, { action: 'export_pgn' })));
  const movetext = (pgn) => pgn.pgn.split('\n\n').at(-1).trim();
  const body = movetext(pgns[0]);
  assert(body.endsWith('1-0') && body.includes('17. Rd8#'), 'PGN movetext ends with mate and result', body);
  for (let i = 1; i < pgns.length; i++) {
    assert(movetext(pgns[i]) === body, `${PLATFORMS[i]} PGN matches ${PLATFORMS[0]}`);
  }
  results.pgn = pgns[0].pgn;

  // 8. Rematch handshake swaps colours and restarts the room for everyone.
  results.steps.push('rematch');
  await ui(BLACK, { action: 'offer_rematch' });
  const offered = await state(WHITE);
  assert(offered.offers?.rematch === 'b', `${WHITE} sees the rematch offer`, offered.offers);
  await ui(WHITE, { action: 'accept_rematch' });
  const again = await waitFor(
    'everyone in the rematch',
    async () => {
      const s = await allStates();
      return PLATFORMS.every((p) => s[p].roomCode === code && s[p].status === 'playing') ? s : null;
    },
    20_000,
  );
  assert(again[WHITE].mySide === 'b' && again[BLACK].mySide === 'w', 'rematch swapped colours');
  assert(again[WHITE].moveCount === 0, 'rematch starts from the initial position');
  await shootAll('rematch');

  // 9. Light theme parity screenshot for the visual-parity audit.
  await Promise.all(PLATFORMS.map((p) => ui(p, { action: 'set_theme', theme: 'light' })));
  await shootAll('light');
  await Promise.all(PLATFORMS.map((p) => ui(p, { action: 'set_theme', theme: 'dark' })));

  if (!HEADLESS) {
    log(`before parity — recording hold ${PRE_PARITY_HOLD_MS}ms`);
    await sleep(PRE_PARITY_HOLD_MS);
  }
  // 10. Normalized visual parity against the web reference: lobby and PGN
  // review of the game just played, every client under the same identity.
  const natives = PLATFORMS.filter((p) => p !== 'web');
  if (PLATFORMS.includes('web') && natives.length) {
    results.steps.push('parity');
    const dir = join(OUT, 'parity');
    mkdirSync(dir, { recursive: true });
    await Promise.all(PLATFORMS.map((p) => ui(p, { action: 'leave_room' })));
    await Promise.all(PLATFORMS.map((p) => ui(p, { action: 'set_name', name: PARITY_NAME })));
    const idle = await allStates();
    for (const p of PLATFORMS) {
      assert(idle[p].screen === 'lobby' && idle[p].roomCode == null, `${p} is back in the lobby`, idle[p]);
    }
    for (const p of natives) {
      await parity(p, 'lobby', dir);
      for (const q of ['web', p]) await ui(q, { action: 'import_pgn', pgn: results.pgn });
      await parity(p, 'review', dir);
      for (const q of ['web', p]) await ui(q, { action: 'close_review' });
    }
    await Promise.all(PLATFORMS.map((p) => ui(p, { action: 'set_name', name: CLIENT[p].name })));
  }

  log('all assertions passed');
  await browser?.close();
  finish(0);
}

main().catch((e) => {
  console.error(e);
  fail(e.message);
});
