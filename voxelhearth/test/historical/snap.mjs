// Quick visual check: open the web client and screenshot.
import { chromium } from 'playwright';
const url = process.argv[2] ?? 'http://localhost:8787/?name=WebPlayer';
const out = process.argv[3] ?? '/tmp/vh-web.png';
const browser = await chromium.launch({ channel: 'chrome', headless: false, args: ['--use-gl=angle', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
page.on('console', (m) => console.log('[console]', m.type(), m.text()));
page.on('pageerror', (e) => console.log('[pageerror]', e.message));
await page.goto(url);
await page.waitForTimeout(parseInt(process.argv[4] ?? '6000'));
await page.screenshot({ path: out });
console.log('saved', out);
await browser.close();
