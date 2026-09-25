// Launches the Swapmate web client in headless-or-headed Chromium and keeps it
// alive until SIGTERM. Screenshots are taken on demand by writing a path to the
// FIFO/env-configured trigger; simplest path: poll a "shot" file.
//
//   node web_client.mjs --url http://localhost:8787/?testId=web --shots /tmp/shots/web
//
// Every time `<shots>.request` exists, its contents (a name) are used to write
// `<shots>-<name>.png` and the request file is deleted.
import { chromium } from 'playwright';
import fs from 'node:fs';

const args = Object.fromEntries(
  process.argv.slice(2).reduce((acc, a, i, arr) => {
    if (a.startsWith('--')) acc.push([a.slice(2), arr[i + 1]]);
    return acc;
  }, []),
);
const url = args.url ?? 'http://localhost:8787/?testId=web';
const shots = args.shots ?? '/tmp/swapmate-web';
const width = Number(args.width ?? 1280);
const height = Number(args.height ?? 860);
const dpr = Number(args.dpr ?? 1);
const headless = args.headed !== '1';

const browser = await chromium.launch({ headless });
const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: dpr });
page.on('console', (m) => {
  if (m.type() === 'error') console.error('[web console]', m.text());
});
await page.goto(url, { waitUntil: 'load' });
console.log(`[web] ready ${url}`);

const request = `${shots}.request`;
const tick = async () => {
  if (fs.existsSync(request)) {
    const name = fs.readFileSync(request, 'utf8').trim();
    fs.rmSync(request);
    const out = `${shots}-${name}.png`;
    await page.screenshot({ path: out });
    console.log(`[web] shot ${out}`);
  }
};
const timer = setInterval(() => tick().catch((e) => console.error(e)), 250);

const stop = async () => {
  clearInterval(timer);
  await browser.close();
  process.exit(0);
};
process.on('SIGTERM', stop);
process.on('SIGINT', stop);
