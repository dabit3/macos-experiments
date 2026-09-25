// Single-client smoke run against a --test-mode server: home → lobby → game → results.
// usage: node smoke-web.mjs [webUrl] [wsUrl] [outDir]
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
import { Director, sleep } from './lib/director.mjs';

const webUrl = process.argv[2] ?? 'http://localhost:8790';
const wsUrl = process.argv[3] ?? 'ws://localhost:8787/ws';
const out = process.argv[4] ?? '/tmp/vh-smoke';
mkdirSync(out, { recursive: true });

const name = 'SmokeWeb';
const code = 'SMOKE';
const d = new Director(wsUrl);
await d.connect();

const browser = await chromium.launch({ channel: 'chrome', headless: false, args: ['--use-gl=angle', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
page.on('console', (m) => {
  if (m.type() === 'error' || m.type() === 'warning') console.log('[web]', m.type(), m.text().split('\n')[0]);
});
page.on('pageerror', (e) => console.log('[web pageerror]', e.message));
await page.goto(`${webUrl}/?name=${name}&server=${encodeURIComponent(wsUrl)}`);
await sleep(4000);
await page.screenshot({ path: `${out}/01-home.png` });

const step = async (label, fn) => {
  const t0 = Date.now();
  const r = await fn();
  console.log(`${label.padEnd(18)} ${Date.now() - t0}ms`, JSON.stringify(r).slice(0, 220));
  return r;
};

await step('screen', () => d.must(name, { t: 'screen' }));
await step('create_room', () => d.must(name, { t: 'create_room', code, name: 'Smoke world', seed: 1234, bots: 2, freezeTime: true, startTime: 6000 }));
await step('wait lobby', () => d.must(name, { t: 'wait_screen', screen: 'lobby' }));
await sleep(1200);
await page.screenshot({ path: `${out}/02-lobby.png` });
await step('start_match', () => d.must(name, { t: 'start_match' }));
await step('wait_game', () => d.must(name, { t: 'wait_game' }, { timeout: 45000 }));
await sleep(1500);
await page.screenshot({ path: `${out}/03-game.png` });
const st = await step('state', () => d.must(name, { t: 'state' }));
const bx = Math.floor(st.x), bz = Math.floor(st.z);
await step('give', () => d.must(name, { t: 'give', id: 1, count: 16, slot: 0 }));
await step('select_slot', () => d.must(name, { t: 'select_slot', slot: 0 }));
await sleep(300);
await step('look_at', () => d.must(name, { t: 'look_at', x: bx + 2, y: Math.floor(st.y) - 1, z: bz + 2 }));
await sleep(500);
await page.screenshot({ path: `${out}/04-game-look.png` });
await step('open_inventory', () => d.must(name, { t: 'open_inventory' }));
await sleep(800);
await page.screenshot({ path: `${out}/05-inventory.png` });
await step('close', () => d.must(name, { t: 'close_overlay' }));
await step('chat', () => d.must(name, { t: 'chat', text: 'hello from the web' }));
await step('toggle_chat', () => d.must(name, { t: 'toggle_chat', open: true }));
await sleep(800);
await page.screenshot({ path: `${out}/06-chat.png` });
await step('toggle_chat off', () => d.must(name, { t: 'toggle_chat', open: false }));
await step('pause', () => d.must(name, { t: 'pause', on: true }));
await sleep(600);
await page.screenshot({ path: `${out}/07-pause.png` });
await step('unpause', () => d.must(name, { t: 'pause', on: false }));
await step('end_match', () => d.must(name, { t: 'end_match' }));
await step('wait results', () => d.must(name, { t: 'wait_screen', screen: 'results' }));
await sleep(1500);
await page.screenshot({ path: `${out}/08-results.png` });
console.log('server view:', JSON.stringify((await d.query(code)).state).slice(0, 300));
await browser.close();
d.close();
