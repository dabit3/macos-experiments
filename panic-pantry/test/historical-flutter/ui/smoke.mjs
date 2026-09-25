#!/usr/bin/env node
// Panic Pantry — navigation / state smoke test on the web client.
//
// Drives a single web client through the screens the four-way match does not
// visit (home, how-to-play sheet, join errors, host → lobby → leave, theme
// toggle) using the same test-command channel as the E2E harness, and
// screenshots each state. Reports and screenshots are written to
// .devin/clone-this/panic-pantry/evidence/tests/ui-smoke/.
//
// Usage: node test/ui/smoke.mjs   (expects app/build/web to exist; see test/ui-smoke.sh)

import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { env, makeHttp, serveWeb, sleep, waitFor } from '../lib/common.mjs';

const here = fileURLToPath(new URL('.', import.meta.url));
const root = resolve(here, '..', '..');
const appDir = join(root, 'app');
const serverDir = join(root, 'server');
const OUT = join(root, '.devin', 'clone-this', 'panic-pantry', 'evidence', 'tests', 'ui-smoke');

const PORT = Number(env('PP_PORT', '8791'));
const WEB_PORT = Number(env('PP_WEB_PORT', '8092'));
const TIMEOUT = Number(env('PP_JOIN_TIMEOUT', '60000'));
const VIEWPORT = { width: 800, height: 520 };

const http = makeHttp(PORT);
const lines = [];
const checks = [];
const children = [];
let browser;
let context;
let webServer;
let videoStartedAt = null;

function log(msg) {
  const line = `${new Date().toISOString()} ${msg}`;
  lines.push(line);
  console.log(line);
}

function check(name, ok, detail = '') {
  checks.push({ name, ok, detail });
  log(`${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ` — ${detail}` : ''}`);
}

async function startServer() {
  const p = spawn('dart', ['run', 'bin/server.dart', '--port', String(PORT), '--seed', '7', '--test-harness'], {
    cwd: serverDir,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  p.stdout.on('data', (d) => log(`server: ${String(d).trimEnd()}`));
  p.stderr.on('data', (d) => log(`server! ${String(d).trimEnd()}`));
  children.push(p);
  await waitFor('server /health', () => http('GET', '/health'), TIMEOUT, 500);
}

async function myId() {
  return waitFor(
    'web client to connect',
    async () => {
      const { clients } = await http('GET', '/test/clients');
      return clients.find((c) => c.platform === 'web' && c.id)?.id;
    },
    TIMEOUT,
    500,
  );
}

async function command(id, body) {
  await http('POST', `/test/clients/${id}/command`, body);
}

async function report(id, wantScreen, extra = () => true) {
  return waitFor(
    `${wantScreen} report`,
    async () => {
      await command(id, { cmd: 'report' });
      await sleep(400);
      const { clients } = await http('GET', '/test/clients');
      const rep = clients.find((c) => c.id === id)?.report;
      const painted = (rep?.framesSinceScreen ?? 0) >= 6 && (rep?.screenAgeMs ?? 0) >= 1200;
      return rep && rep.screen === wantScreen && painted && extra(rep) ? rep : null;
    },
    TIMEOUT,
    700,
  );
}

async function shot(page, name) {
  const file = join(OUT, `${name}.png`);
  await page.screenshot({ path: file });
  log(`screenshot ${name}.png`);
}

async function main() {
  mkdirSync(OUT, { recursive: true });
  await startServer();
  webServer = await serveWeb(join(appDir, 'build', 'web'), WEB_PORT);

  const { chromium } = await import('playwright');
  browser = await chromium.launch({ headless: true });
  // Playwright records the whole browser session; test/review-video cuts it
  // into the edited review reel using the timestamps in smoke.log.
  const videoDir = join(OUT, 'video');
  rmSync(videoDir, { recursive: true, force: true });
  context = await browser.newContext({ viewport: VIEWPORT, recordVideo: { dir: videoDir, size: VIEWPORT } });
  const page = await context.newPage();
  videoStartedAt = new Date().toISOString();
  log(`browser recording started -> ${join(OUT, 'browser-smoke.webm')}`);
  const consoleLog = [];
  page.on('console', (m) => {
    consoleLog.push(`[${m.type()}] ${m.text()}`);
    if (m.type() === 'error') log(`web console error: ${m.text().split('\n')[0]}`);
  });

  // Auto-join hosts a room so the client connects; leaving it lands on home
  // with a live socket, which is the state the home-screen checks need.
  const q = new URLSearchParams({ server: `ws://localhost:${PORT}/ws`, name: 'Smoke', auto: '1', level: 'training' });
  await page.goto(`http://127.0.0.1:${WEB_PORT}/?${q}`, { waitUntil: 'load' });
  const id = await myId();
  log(`web client id ${id}`);

  let rep = await report(id, 'lobby');
  check('auto-host lands in lobby', rep.code?.length === 4, `room ${rep.code}`);
  await command(id, { cmd: 'theme', mode: 'light' });
  await sleep(600);
  await shot(page, '01-lobby-light');

  await command(id, { cmd: 'leave' });
  rep = await report(id, 'home');
  check('leave returns to home', rep.screen === 'home' && !rep.code);
  const rooms = await http('GET', '/test/rooms');
  check('empty room is closed on leave', rooms.rooms.length === 0, `${rooms.rooms.length} room(s) left`);
  await shot(page, '02-home-light');

  await command(id, { cmd: 'howto' });
  await sleep(1500);
  await shot(page, '03-how-to-play');
  rep = await report(id, 'home');
  check('how-to-play sheet keeps the home route underneath', rep.screen === 'home');
  await command(id, { cmd: 'dismiss' });
  await sleep(900);
  await shot(page, '04-home-after-dismiss');

  await command(id, { cmd: 'join', code: 'ZZZZ' });
  rep = await report(id, 'home', (r) => typeof r.lastError === 'string' && r.lastError.length > 0);
  check('joining a missing room stays on home with an error', /room|kitchen|code/i.test(rep.lastError), rep.lastError);
  await sleep(300);
  await shot(page, '05-join-error-toast');

  await http('POST', '/test/rooms', { code: 'FULL', seed: 3, level: 'training', bots: 4 });
  await command(id, { cmd: 'join', code: 'FULL' });
  rep = await report(id, 'home', (r) => typeof r.lastError === 'string' && /full/i.test(r.lastError));
  check('joining a full room is rejected', /full/i.test(rep.lastError), rep.lastError);
  await http('DELETE', '/test/rooms/FULL');

  await command(id, { cmd: 'theme', mode: 'dark' });
  await sleep(900);
  await shot(page, '06-home-dark');
  await command(id, { cmd: 'howto' });
  await sleep(1500);
  await shot(page, '07-how-to-play-dark');
  await command(id, { cmd: 'dismiss' });
  await sleep(600);

  await command(id, { cmd: 'host', level: 'drift-deck' });
  rep = await report(id, 'lobby');
  const room = await http('GET', `/test/rooms/${rep.code}`);
  check('host from home opens a lobby on the requested level', room.level === 'drift-deck', `level ${room.level}`);
  await shot(page, '08-lobby-dark');
  await command(id, { cmd: 'theme', mode: 'light' });
  await command(id, { cmd: 'leave' });
  rep = await report(id, 'home');
  check('second leave returns to home', rep.screen === 'home');

  const errors = consoleLog.filter((l) => l.startsWith('[error]'));
  check('web console has no errors', errors.length === 0, errors.slice(0, 3).join(' | '));

  const failed = checks.filter((c) => !c.ok);
  const summary = {
    finishedAt: new Date().toISOString(),
    viewport: VIEWPORT,
    videoStartedAt,
    video: 'browser-smoke.webm',
    checks,
    passed: failed.length === 0,
  };
  writeFileSync(join(OUT, 'summary.json'), JSON.stringify(summary, null, 2));
  writeFileSync(join(OUT, 'web-console.log'), consoleLog.join('\n'));
  log(failed.length === 0 ? `PASS: ${checks.length}/${checks.length} smoke checks passed` : `FAIL: ${failed.length} of ${checks.length} smoke checks failed`);
  return failed.length === 0;
}

async function cleanup() {
  try {
    await context?.close();
    await browser?.close();
    const videoDir = join(OUT, 'video');
    const webm = existsSync(videoDir) ? readdirSync(videoDir).find((f) => f.endsWith('.webm')) : null;
    if (webm) {
      renameSync(join(videoDir, webm), join(OUT, 'browser-smoke.webm'));
      rmSync(videoDir, { recursive: true, force: true });
    }
  } catch {}
  webServer?.close();
  for (const c of children) c.kill('SIGTERM');
  writeFileSync(join(OUT, 'smoke.log'), lines.join('\n') + '\n');
}

main()
  .then(async (ok) => {
    await cleanup();
    process.exit(ok ? 0 : 1);
  })
  .catch(async (e) => {
    log(`ERROR ${e.stack || e}`);
    await cleanup();
    process.exit(1);
  });
