// Screenshot-driven design pass for the web client: home, create/join, lobby,
// live gameplay (HUD, inventory, workbench, pause, chat) and results.
// Usage: node design-pass.mjs [outDir] [WxH]
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { Director, sleep } from './lib/director.mjs';

const out = process.argv[2] ?? '/tmp/vh-design';
const [w, h] = (process.argv[3] ?? '1280x800').split('x').map(Number);
mkdirSync(out, { recursive: true });
const name = 'Designer';
const d = new Director('ws://localhost:8787/ws');
await d.connect();
const browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--use-gl=angle', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: w, height: h } });
page.on('pageerror', (e) => console.log('[pageerror]', e.message));
const shot = async (n) => { await sleep(500); await page.screenshot({ path: join(out, `${n}.png`) }); console.log('shot', n); };
await page.goto(`http://localhost:8787/?name=${name}&server=ws%3A%2F%2Flocalhost%3A8787%2Fws`);
await sleep(4000);
await shot('01-home');
for (const s of ['home', 'lobby', 'results']) {
  await d.must(name, { t: 'fixture', screen: s });
  await shot(`02-fixture-${s}`);
}
await page.reload();
await sleep(4000);
await d.must(name, { t: 'create_room', code: 'DSGN', seed: 1234, bots: 2, freezeTime: true, startTime: 6000 });
await d.must(name, { t: 'wait_screen', screen: 'lobby' });
await shot('03-lobby-live');
await d.must(name, { t: 'start_match' });
await d.must(name, { t: 'wait_game' });
await sleep(1500);
await shot('04-game');
await d.drive(name, { t: 'give', id: 9, count: 16, slot: 0 });
await d.drive(name, { t: 'give', id: 4, count: 7, slot: 1 });
await d.drive(name, { t: 'chat', text: 'hello from the design pass' });
await sleep(600);
await shot('05-game-chat');
await page.keyboard.press('e');
await shot('06-inventory');
await page.keyboard.press('Escape');
await sleep(300);
await page.keyboard.press('Escape');
await shot('07-pause');
await page.keyboard.press('Escape');
await sleep(300);
await page.keyboard.press('t');
await sleep(300);
await page.keyboard.type('open chat');
await shot('08-chat');
await page.keyboard.press('Escape');
await page.keyboard.down('Tab');
await shot('09-tab-roster');
await page.keyboard.up('Tab');
await d.query('DSGN', { cmd: 'end' }).catch(() => {});
try { await d.must(name, { t: 'wait_screen', screen: 'results', timeout: 20 }, { timeout: 25000 }); await shot('10-results'); } catch (e) { console.log('results skipped', e.message); }
await browser.close();
d.close();
