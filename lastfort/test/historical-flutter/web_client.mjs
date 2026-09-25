// Drives the Lastfort web client for the cross-platform multiplayer test.
//
//   node web_client.mjs <url> <controlDir> [x,y,w,h]
//
// Opens <url> in a headed Chromium window, then watches <controlDir> for
// request files written by multiplayer-e2e.sh:
//   shot-<n>.req   -> contents: absolute PNG path; screenshot the page there
//   start.req      -> send startMatch over this client's host connection
//   quit.req       -> close the browser and exit 0
// Each handled request is renamed to *.done so the shell can wait on it.
import { chromium } from 'playwright';
import { promises as fs } from 'node:fs';
import path from 'node:path';

const [url, controlDir, frame = '20,40,780,560'] = process.argv.slice(2);
if (!url || !controlDir) {
  console.error('usage: node web_client.mjs <url> <controlDir> [x,y,w,h]');
  process.exit(64);
}
const [x, y, w, h] = frame.split(',').map(Number);

const browser = await chromium.launch({
  headless: false,
  args: [
    `--window-position=${x},${y}`,
    `--window-size=${w},${h}`,
    '--disable-infobars',
    '--no-first-run',
    '--hide-scrollbars',
    '--disable-notifications',
  ],
});
const context = await browser.newContext({ viewport: null });
const page = await context.newPage();
let matchSocket;
await page.routeWebSocket('**/ws', (socket) => {
  matchSocket = socket.connectToServer();
});
page.on('console', (m) => {
  if (m.type() === 'error') console.error('[web console]', m.text());
});
page.on('pageerror', (e) => console.error('[web pageerror]', e.message));
await page.goto(url, { waitUntil: 'load' });
// Flutter web renders into a <flutter-view>; wait until it exists.
await page.waitForSelector('flutter-view, flt-glass-pane', { timeout: 120000 });
await fs.writeFile(path.join(controlDir, 'web-ready'), url);
console.log('web client ready', url);

let running = true;
while (running) {
  const entries = (await fs.readdir(controlDir)).filter((f) => f.endsWith('.req')).sort();
  for (const name of entries) {
    const file = path.join(controlDir, name);
    if (name === 'quit.req') {
      running = false;
      await fs.rename(file, file.replace(/\.req$/, '.done'));
      break;
    }
    if (name === 'start.req') {
      if (!matchSocket) throw new Error('host WebSocket is not connected');
      matchSocket.send(JSON.stringify({ t: 'startMatch', countdownMs: 3000 }));
      await fs.rename(file, file.replace(/\.req$/, '.done'));
      continue;
    }
    if (name.startsWith('shot-')) {
      const target = (await fs.readFile(file, 'utf8')).trim();
      try {
        await page.screenshot({ path: target });
        console.log('web screenshot', target);
      } catch (e) {
        console.error('web screenshot failed', e.message);
      }
      await fs.rename(file, file.replace(/\.req$/, '.done'));
    }
  }
  await new Promise((r) => setTimeout(r, 200));
}
await browser.close();
