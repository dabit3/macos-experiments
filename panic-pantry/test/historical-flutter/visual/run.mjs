#!/usr/bin/env node
// Panic Pantry — normalized cross-platform visual parity.
//
// The web build (Chromium via Playwright) is the visual reference. For every
// native client (iOS Simulator, Android emulator, macOS app) and every screen
// state, the harness puts both the native client and the web reference into
// the same deterministic state (same room code, seed, level, player name and
// light theme), sizes the web viewport to the native client's reported logical
// viewport (minus safe-area insets) at the native pixel ratio, captures both
// and compares them pixel by pixel.
//
// Normalization applied (recorded in the JSON report):
//   - crop native capture to the Flutter view inside the safe area
//   - web viewport = native logical size, deviceScaleFactor = native pixel ratio
//   - both clients forced to the light theme and the same player name
//   - the local player's device label ("web" vs "macos" etc.) is the one piece
//     of UI that differs by design; both clients report its exact rectangle
//     (PlatformMark) and that region is excluded, its text verified separately
//   - macOS rounds the window's bottom corners itself; those four corner
//     squares (PP_VISUAL_CORNER logical px, macOS only) are excluded
//   - rasteriser differences (CoreText / FreeType / Skia-on-Android stroke
//     weight and sub-pixel glyph placement) are removed by the three-pass gate
//     in gate.mjs (box-averaged blocks intersected with a logical-pixel pass,
//     plus morphological "core" and unshifted colour-density passes); see that file for the rules and the
//     PP_VISUAL_* knobs. Moved, missing or recoloured content forms a
//     contiguous group in at least one pass and fails; leftover rasteriser
//     noise is isolated pixels or 1-px-thin drift lines and passes.
//   - test/visual/selftest.mjs re-runs the gate on the captured pairs with
//     injected defects to prove it is still sensitive.
//
// Output (stable paths, referenced from the clone-this manifest):
//   evidence/reference/<state>-web-for-<platform>.png  raw reference capture
//   evidence/clone/<state>-<platform>.png              raw native capture (cropped)
//   evidence/reference/<state>-web-for-<platform>.normalized.png
//   evidence/clone/<state>-<platform>.normalized.png   the compared images
//   evidence/diffs/<state>-<platform>.png              full-res heat-map (red = differs)
//   evidence/diffs/<state>-<platform>.normalized.png   normalized heat-map (the gate)
//   evidence/diffs/visual-parity.json                  machine-readable results
//   evidence/diffs/visual-parity.log                   run log

import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { env, makeHttp, osascript, parkMouse, placeWindow, serveWeb, sh, sleep, waitFor, windowBounds } from '../lib/common.mjs';
import { crop, decodePng, diff, encodePng, resize } from '../lib/png.mjs';
import { describe, evaluate, paramsFromEnv } from './gate.mjs';

const here = fileURLToPath(new URL('.', import.meta.url));
const root = resolve(here, '..', '..');
const appDir = join(root, 'app');
const serverDir = join(root, 'server');
const runDir = join(root, '.devin', 'clone-this', 'panic-pantry');

const PLATFORMS = env('PP_PLATFORMS', 'ios android macos').split(/\s+/).filter(Boolean);
const STATES = env('PP_STATES', 'home lobby results').split(/\s+/).filter(Boolean);
const PORT = Number(env('PP_PORT', '8787'));
const WEB_PORT = Number(env('PP_WEB_PORT', '8080'));
const SEED = Number(env('PP_SEED', '23'));
const LEVEL = env('PP_LEVEL', 'corner-cafe');
const SPEED = Number(env('PP_RESULTS_SPEED', '8'));
const GATE = paramsFromEnv(env);
const TOLERANCE = GATE.tolerance;
const CORNER = Number(env('PP_VISUAL_CORNER', '20')); // macOS window corner radius, logical px
const MASK_PAD = 2; // logical px added around reported platform-specific regions
const IOS_UDID = env('PP_IOS_UDID', '');
const ANDROID_SERIAL = env('PP_ANDROID_SERIAL', '');
const ANDROID_SERVER = env('PP_ANDROID_SERVER', `ws://10.0.2.2:${PORT}/ws`);
const ANDROID_SDK = env('ANDROID_SDK_ROOT', env('ANDROID_HOME', join(process.env.HOME, 'Library', 'Android', 'sdk')));
const ADB = join(ANDROID_SDK, 'platform-tools', 'adb');
const JOIN_TIMEOUT = Number(env('PP_JOIN_TIMEOUT', '150')) * 1000;
const EVIDENCE = resolve(env('PP_EVIDENCE_ROOT', join(runDir, 'evidence')));
const IOS_BUNDLE = 'dev.panicpantry.panicPantry';
const ANDROID_PKG = 'dev.panicpantry.panic_pantry';
const NAME = 'Chef';
const WS_URL = `ws://localhost:${PORT}/ws`;
const ROOM = 'VIS1';

for (const d of ['reference', 'clone', 'diffs']) mkdirSync(join(EVIDENCE, d), { recursive: true });
const logFile = join(EVIDENCE, 'diffs', 'visual-parity.log');
const started = Date.now();
const lines = [];
function log(msg) {
  const line = `[${((Date.now() - started) / 1000).toFixed(1).padStart(6)}s] ${msg}`;
  lines.push(line);
  console.log(line);
  writeFileSync(logFile, lines.join('\n') + '\n');
}
const http = makeHttp(PORT);

const children = [];
function child(name, cmd, args, opts = {}) {
  const p = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'], ...opts });
  p.stdout.on('data', (d) => log(`${name}: ${String(d).trimEnd()}`));
  p.stderr.on('data', (d) => log(`${name}! ${String(d).trimEnd()}`));
  children.push(p);
  return p;
}

// --- Room lifecycle -----------------------------------------------------------
async function freshRoom() {
  try {
    await http('DELETE', `/test/rooms/${ROOM}`);
  } catch {}
  await http('POST', '/test/rooms', { code: ROOM, seed: SEED, level: LEVEL, speed: SPEED });
}

async function playerId(platform) {
  const r = await waitFor(
    `${platform} to join ${ROOM}`,
    async () => {
      const room = await http('GET', `/test/rooms/${ROOM}`);
      const p = room.players.find((x) => !x.bot && x.connected && x.platform === platform);
      return p?.id;
    },
    JOIN_TIMEOUT,
    1000,
  );
  return r;
}

async function report(id, wantScreen) {
  return waitFor(
    `${wantScreen} report from ${id}`,
    async () => {
      await http('POST', `/test/rooms/${ROOM}/players/${id}/command`, { cmd: 'report' });
      await sleep(400);
      const room = await http('GET', `/test/rooms/${ROOM}`);
      const rep = room.reports?.[id];
      // A screen counts as shown once the client has rendered several frames
      // of it: a build alone can be many seconds ahead of the display on a
      // software-rendered emulator, and the entry transition must finish.
      const painted = (rep?.framesSinceScreen ?? 0) >= 6 && (rep?.screenAgeMs ?? 0) >= 1500;
      return rep && rep.screen === wantScreen && rep.view?.width && painted ? rep : null;
    },
    JOIN_TIMEOUT,
    1000,
  );
}

/** Drives the room into the requested state and returns the client's report. */
async function reachState(state, id) {
  await http('POST', `/test/rooms/${ROOM}/players/${id}/command`, { cmd: 'theme', mode: 'light' });
  if (state === 'lobby') return report(id, 'lobby');
  if (state === 'results') {
    await http('POST', `/test/rooms/${ROOM}/bots`, { count: 3 });
    await http('POST', `/test/rooms/${ROOM}/start`, {});
    const rep = await report(id, 'results');
    await sleep(3500); // let the results reveal animation settle
    return report(id, 'results');
  }
  throw new Error(`unknown state ${state}`);
}

// --- Web reference ------------------------------------------------------------
let browser;
async function chromium() {
  if (browser) return browser;
  const { chromium } = await import('playwright');
  browser = await chromium.launch({ headless: true });
  return browser;
}

async function webCapture(state, view, joinRoom, shownServer) {
  const b = await chromium();
  const ctx = await b.newContext({
    viewport: { width: Math.round(view.width), height: Math.round(view.height) },
    deviceScaleFactor: view.dpr,
    colorScheme: 'light',
  });
  const page = await ctx.newPage();
  // The home screen shows the server URL, so the reference displays the same
  // string the native client was launched with (Android sees the host as
  // 10.0.2.2); connected states always talk to localhost.
  const q = new URLSearchParams({ server: joinRoom ? WS_URL : shownServer, name: NAME });
  if (joinRoom) {
    q.set('room', ROOM);
    q.set('auto', '1');
  }
  await page.goto(`http://127.0.0.1:${WEB_PORT}/?${q}`);
  await page.waitForLoadState('networkidle');
  let id;
  if (joinRoom) {
    id = await playerId('web');
    await reachState(state, id);
  } else {
    await page.waitForTimeout(3000);
  }
  await page.waitForTimeout(2000);
  const png = await page.screenshot({ type: 'png' });
  const regions = id ? ((await report(id, state)).platformRegions ?? {}) : {};
  await ctx.close();
  return { img: decodePng(png), regions };
}

/** Reported logical rectangles -> pixel rects inside the cropped capture. */
function maskRects(regions, padding, dpr) {
  return Object.entries(regions).map(([id, r]) => ({
    id,
    x: Math.floor((r.x - padding.left - MASK_PAD) * dpr),
    y: Math.floor((r.y - padding.top - MASK_PAD) * dpr),
    w: Math.ceil((r.w + 2 * MASK_PAD) * dpr),
    h: Math.ceil((r.h + 2 * MASK_PAD) * dpr),
  }));
}

/** True when (almost) every sampled pixel has the same colour as the first one. */
function isBlank(img) {
  const [r, g, b] = img.data;
  let other = 0;
  let total = 0;
  for (let o = 0; o < img.data.length; o += 4 * 7) {
    total++;
    if (Math.abs(img.data[o] - r) > 8 || Math.abs(img.data[o + 1] - g) > 8 || Math.abs(img.data[o + 2] - b) > 8) other++;
  }
  return other / total < 0.002;
}

// --- Native platforms -----------------------------------------------------------
const adbTarget = () => (ANDROID_SERIAL ? ['-s', ANDROID_SERIAL] : []);

function iosUdid() {
  if (IOS_UDID) return IOS_UDID;
  const out = sh('xcrun', ['simctl', 'list', 'devices', 'booted', '-j']).stdout;
  const devs = Object.values(JSON.parse(out).devices).flat();
  const d = devs.find((x) => x.state === 'Booted');
  if (!d) throw new Error('no booted iOS simulator (set PP_IOS_UDID)');
  return d.udid;
}

const native = {
  ios: {
    launch(vars) {
      const udid = iosUdid();
      this.udid = udid;
      sh('xcrun', ['simctl', 'ui', udid, 'appearance', 'light']);
      sh('xcrun', ['simctl', 'terminate', udid, IOS_BUNDLE]);
      const app = join(appDir, 'build', 'ios', 'iphonesimulator', 'Runner.app');
      if (!existsSync(app)) throw new Error(`missing ${app}`);
      if (!this.installed) sh('xcrun', ['simctl', 'install', udid, app]);
      this.installed = true;
      const envs = Object.fromEntries(Object.entries(vars).map(([k, v]) => [`SIMCTL_CHILD_${k}`, v]));
      const r = sh('xcrun', ['simctl', 'launch', udid, IOS_BUNDLE], { env: { ...process.env, ...envs } });
      if (r.status !== 0) throw new Error(`simctl launch failed: ${r.stderr}`);
    },
    capture(view) {
      const file = join(EVIDENCE, 'clone', 'ios-raw.png');
      sh('xcrun', ['simctl', 'io', this.udid, 'screenshot', '--type=png', file]);
      const img = decodePng(readFileSync(file));
      const p = view.padding;
      return crop(img, p.left * view.dpr, p.top * view.dpr, (view.width - p.left - p.right) * view.dpr, (view.height - p.top - p.bottom) * view.dpr);
    },
    stop() {
      if (this.udid) sh('xcrun', ['simctl', 'terminate', this.udid, IOS_BUNDLE]);
    },
  },
  android: {
    launch(vars) {
      if (!existsSync(ADB)) throw new Error(`adb not found at ${ADB}`);
      sh(ADB, [...adbTarget(), 'shell', 'cmd', 'uimode', 'night', 'no']);
      sh(ADB, [...adbTarget(), 'shell', 'am', 'force-stop', ANDROID_PKG]);
      const apk = ['app-release.apk', 'app-debug.apk']
        .map((f) => join(appDir, 'build', 'app', 'outputs', 'flutter-apk', f))
        .find(existsSync);
      if (!apk) throw new Error('missing Android APK');
      if (!this.installed) sh(ADB, [...adbTarget(), 'install', '-r', apk]);
      this.installed = true;
      const extras = Object.entries({ ...vars, PP_SERVER: vars.PP_SERVER ? ANDROID_SERVER : undefined })
        .filter(([, v]) => v !== undefined)
        .flatMap(([k, v]) => ['--es', k, v]);
      const r = sh(ADB, [...adbTarget(), 'shell', 'am', 'start', '-W', '-n', `${ANDROID_PKG}/.MainActivity`, ...extras]);
      if (r.status !== 0) throw new Error(`am start failed: ${r.stderr}`);
    },
    capture(view) {
      const raw = sh(ADB, [...adbTarget(), 'exec-out', 'screencap', '-p'], { encoding: 'buffer', maxBuffer: 64 << 20 }).stdout;
      const img = decodePng(raw);
      // The activity window frame (status/navigation bars are outside it on
      // pre-edge-to-edge Android; on edge-to-edge devices the safe-area
      // padding from the report is used instead).
      const dump = sh(ADB, [...adbTarget(), 'shell', 'dumpsys', 'window', 'windows']).stdout;
      const m = dump.match(new RegExp(`Window #\\d+ Window\\{[^}]*${ANDROID_PKG.replace(/\./g, '\\.')}[^}]*\\}:[\\s\\S]*?mFrame=\\[(\\d+),(\\d+)\\]\\[(\\d+),(\\d+)\\]`));
      const frame = m ? { x: +m[1], y: +m[2], w: +m[3] - +m[1], h: +m[4] - +m[2] } : { x: 0, y: 0, w: img.width, h: img.height };
      const p = view.padding;
      return crop(
        img,
        frame.x + p.left * view.dpr,
        frame.y + p.top * view.dpr,
        Math.min(frame.w, view.width * view.dpr) - (p.left + p.right) * view.dpr,
        Math.min(frame.h, view.height * view.dpr) - (p.top + p.bottom) * view.dpr,
      );
    },
    stop() {
      if (existsSync(ADB)) sh(ADB, [...adbTarget(), 'shell', 'am', 'force-stop', ANDROID_PKG]);
    },
  },
  macos: {
    launch(vars) {
      const app = join(appDir, 'build', 'macos', 'Build', 'Products', 'Debug', 'Panic Pantry.app');
      if (!existsSync(app)) throw new Error(`missing ${app}`);
      this.proc = child('macos', join(app, 'Contents', 'MacOS', 'Panic Pantry'), [], { env: { ...process.env, ...vars } });
      return waitFor(
        'macOS window',
        () => {
          const b = windowBounds('Panic Pantry');
          if (!b.w) return null;
          placeWindow('Panic Pantry', 120, 120, 960, 640);
          osascript('tell application "Panic Pantry" to activate');
          return b;
        },
        60000,
        1000,
      );
    },
    capture(view) {
      osascript('tell application "Panic Pantry" to activate');
      parkMouse();
      const b = windowBounds('Panic Pantry');
      const titleBar = b.h - view.height; // content view is the reported logical size
      const file = join(EVIDENCE, 'clone', 'macos-raw.png');
      const rect = [b.x, b.y + titleBar, view.width, view.height].map(Math.round).join(',');
      const r = sh('screencapture', ['-x', '-R', rect, file]);
      if (!existsSync(file)) throw new Error(`screencapture -R ${rect} failed: ${r.stderr || r.stdout}`);
      return decodePng(readFileSync(file));
    },
    stop() {
      this.proc?.kill('SIGINT');
      this.proc = undefined;
    },
    chrome(view) {
      const c = CORNER;
      return [
        { id: 'window-corner-tl', x: 0, y: 0, w: c, h: c },
        { id: 'window-corner-tr', x: view.width - c, y: 0, w: c, h: c },
        { id: 'window-corner-bl', x: 0, y: view.height - c, w: c, h: c },
        { id: 'window-corner-br', x: view.width - c, y: view.height - c, w: c, h: c },
      ];
    },
  },
};

// --- One comparison ---------------------------------------------------------------
const results = [];

async function compare(platform, state, launchVars, joinRoom, viewOverride) {
  const drv = native[platform];
  await freshRoom();
  await drv.launch(launchVars);
  let view = viewOverride;
  let nativeRegions = {};
  let id;
  if (joinRoom) {
    id = await playerId(platform);
    view = (await reachState(state, id)).view;
  } else {
    await sleep(platform === 'android' ? 12000 : 4000);
  }
  if (!view) throw new Error(`no viewport known for ${platform}`);
  // Software-emulated devices paint long after they report a screen change,
  // so wait until two captures a few seconds apart agree and the frame is
  // not still the blank pre-first-frame surface.
  let nativeImg = drv.capture(view);
  for (let i = 0; i < 24; i++) {
    await sleep(platform === 'android' ? 5000 : 2000);
    const again = drv.capture(view);
    const settled = diff(nativeImg, again, { tolerance: TOLERANCE }).ratio < 0.001;
    nativeImg = again;
    if (settled && !isBlank(nativeImg)) break;
  }
  if (isBlank(nativeImg)) throw new Error(`${platform} never painted ${state}`);
  // Region rectangles are read after the screen settled (entry animations
  // move widgets), from a report requested for the captured frame.
  if (id) nativeRegions = (await report(id, state)).platformRegions ?? {};
  drv.stop();

  // The web reference renders the same logical area (safe-area inset removed).
  const p = view.padding ?? { top: 0, bottom: 0, left: 0, right: 0 };
  const webView = { width: view.width - p.left - p.right, height: view.height - p.top - p.bottom, dpr: view.dpr };
  await freshRoom();
  const web = await webCapture(state, webView, joinRoom, platform === 'android' ? ANDROID_SERVER : WS_URL);
  const webImg = resize(web.img, nativeImg.width, nativeImg.height);

  // Platform-specific regions reported by either side are excluded, plus the
  // window corners the OS rounds on macOS.
  const masks = [
    ...maskRects(nativeRegions, p, view.dpr),
    ...maskRects(web.regions, { top: 0, left: 0 }, view.dpr),
    ...(drv.chrome?.(webView) ?? []).map((r) => ({
      id: r.id,
      x: Math.floor(r.x * view.dpr),
      y: Math.floor(r.y * view.dpr),
      w: Math.ceil(r.w * view.dpr),
      h: Math.ceil(r.h * view.dpr),
    })),
  ];

  const base = `${state}-${platform}`;
  const refPath = join(EVIDENCE, 'reference', `${state}-web-for-${platform}.png`);
  const clonePath = join(EVIDENCE, 'clone', `${base}.png`);
  const diffPath = join(EVIDENCE, 'diffs', `${base}.png`);
  writeFileSync(refPath, encodePng(webImg));
  writeFileSync(clonePath, encodePng(nativeImg));
  const raw = diff(webImg, nativeImg, { tolerance: TOLERANCE, masks });
  writeFileSync(diffPath, encodePng(raw.image));

  const gate = evaluate(webImg, nativeImg, view.dpr, masks, GATE);
  const refNPath = refPath.replace(/\.png$/, '.normalized.png');
  const cloneNPath = clonePath.replace(/\.png$/, '.normalized.png');
  const diffNPath = diffPath.replace(/\.png$/, '.normalized.png');
  const coreNPath = diffPath.replace(/\.png$/, '.core.png');
  const densityPath = diffPath.replace(/\.png$/, '.density.png');
  writeFileSync(refNPath, encodePng(gate.normalized.reference));
  writeFileSync(cloneNPath, encodePng(gate.normalized.clone));
  writeFileSync(diffNPath, encodePng(gate.blocks.image));
  writeFileSync(coreNPath, encodePng(gate.core.image));
  writeFileSync(densityPath, encodePng(gate.density.image));

  const { pass } = gate;
  const row = {
    platform,
    state,
    view: webView,
    fullView: view,
    masks,
    raw: {
      width: nativeImg.width,
      height: nativeImg.height,
      compared: raw.compared,
      differing: raw.differing,
      ratio: Number(raw.ratio.toFixed(5)),
      reference: refPath,
      clone: clonePath,
      diff: diffPath,
    },
    normalized: {
      ...GATE,
      width: gate.normalized.width,
      height: gate.normalized.height,
      blocks: {
        compared: gate.blocks.compared,
        differing: gate.blocks.differing,
        coarseOnly: gate.blocks.coarseOnly,
        largestCluster: gate.blocks.largestCluster,
        pass: gate.blocks.pass,
      },
      core: {
        compared: gate.core.compared,
        rawDiffering: gate.core.rawDiffering,
        differing: gate.core.differing,
        largestCluster: gate.core.largestCluster,
        pass: gate.core.pass,
      },
      density: {
        block: gate.density.block,
        tolerance: gate.density.tolerance,
        compared: gate.density.compared,
        differing: gate.density.differing,
        largestCluster: gate.density.largestCluster,
        pass: gate.density.pass,
      },
      reference: refNPath,
      clone: cloneNPath,
      diff: diffNPath,
      coreDiff: coreNPath,
      densityDiff: densityPath,
    },
    pass,
  };
  results.push(row);
  log(
    `${pass ? 'PASS' : 'FAIL'} ${platform.padEnd(7)} ${state.padEnd(7)} raw ${nativeImg.width}x${nativeImg.height} ` +
      `${(raw.ratio * 100).toFixed(2)}% differ; ${describe(gate)}; ${masks.length} mask(s)`,
  );
  return row;
}

// --- Main ---------------------------------------------------------------------------
let webServer;
async function cleanup() {
  for (const drv of Object.values(native)) {
    try {
      drv.stop();
    } catch {}
  }
  try {
    await browser?.close();
  } catch {}
  for (const p of children.reverse()) {
    try {
      p.kill('SIGINT');
    } catch {}
  }
  webServer?.close();
}
process.on('SIGINT', async () => {
  await cleanup();
  process.exit(130);
});

let failed = false;
try {
  child('server', 'dart', ['run', 'bin/server.dart', '--port', String(PORT), '--test-harness'], { cwd: serverDir });
  await waitFor('server /health', async () => (await http('GET', '/health')).ok, 60000);
  webServer = await serveWeb(join(appDir, 'build', 'web'), WEB_PORT);
  log(`server :${PORT}, web reference :${WEB_PORT}, platforms [${PLATFORMS.join(', ')}], states [${STATES.join(', ')}]`);

  for (const platform of PLATFORMS) {
    let lobbyView;
    try {
      // Connected states first: they tell us the device's logical viewport.
      for (const state of STATES.filter((s) => s !== 'home')) {
        const row = await compare(platform, state, { PP_SERVER: WS_URL, PP_ROOM: ROOM, PP_NAME: NAME, PP_AUTO: '1' }, true);
        lobbyView ??= row.fullView;
        failed ||= !row.pass;
      }
      if (STATES.includes('home')) {
        if (!lobbyView) throw new Error('home state needs a connected state first to learn the viewport');
        // The home screen is not connected (no report channel), so the viewport
        // learned from the connected capture of the same device is reused.
        const row = await compare(platform, 'home', { PP_SERVER: WS_URL, PP_NAME: NAME }, false, lobbyView);
        failed ||= !row.pass;
      }
    } catch (e) {
      failed = true;
      log(`FAIL ${platform}: ${e.message}`);
      results.push({ platform, error: e.message, pass: false });
      try {
        native[platform].stop();
      } catch {}
    }
  }
} catch (e) {
  failed = true;
  log(`FAIL: ${e.stack || e.message}`);
} finally {
  await cleanup();
}

const summary = {
  reference: 'web build (Chromium, Playwright) at the native client\'s logical viewport and pixel ratio',
  normalization: [
    'native capture cropped to the Flutter view inside the safe area',
    'web viewport sized to the native logical size, deviceScaleFactor = native pixel ratio',
    'light theme and identical player name/room/seed/level on both sides',
    'the local player\'s device label (the only UI that differs by design) is excluded using the rectangles both clients report via PlatformMark; its text is verified separately through the report channel',
    `macOS only: the ${CORNER}px window corners the OS rounds are excluded`,
    `block pass: box-average of ${GATE.block}x${GATE.block} logical px, per-channel tolerance ${GATE.tolerance}/255, placement allowance ${GATE.shift} block(s), intersected with a logical-pixel pass using the same tolerance and allowance; passes when differing blocks <= ${GATE.maxBlocks} and the largest connected group <= ${GATE.maxCluster}`,
    `core pass: logical-pixel comparison with the same tolerance and ${GATE.shift} px allowance, then morphological closing and one erosion (thin drift lines vanish, moved/missing/recoloured elements keep a core); passes when surviving pixels <= ${GATE.maxCore} and the largest connected group <= ${GATE.maxCluster}`,
    `density pass: ${GATE.block * 4}x${GATE.block * 4} logical px box averages, per-channel tolerance ${GATE.tolerance * 0.4}/255, no placement allowance; differing cells <= ${GATE.maxBlocks}, largest connected group <= ${GATE.maxCluster}`,
    'a pair passes only when all three passes pass; test/visual/selftest.mjs proves the gate catches injected defects on the captured pairs',
  ],
  gate: GATE,
  seed: SEED,
  level: LEVEL,
  finishedAt: new Date().toISOString(),
  pass: !failed,
  results,
};
writeFileSync(join(EVIDENCE, 'diffs', 'visual-parity.json'), JSON.stringify(summary, null, 2) + '\n');
log(`${failed ? 'FAIL' : 'PASS'}: ${results.filter((r) => r.pass).length}/${results.length} comparisons within threshold`);
process.exit(failed ? 1 : 0);
