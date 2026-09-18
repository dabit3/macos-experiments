// Frame-by-frame renderer: headless Chromium (Playwright) -> PNG sequence -> ffmpeg (libx264, yuv420p, 30 fps, silent).
// Usage: node render.mjs            (full render + encode)
//        node render.mjs --stills 0 3.5 12 ...   (write single frames to out/still_<t>.png)
import { chromium } from 'playwright';
import { execSync } from 'node:child_process';
import { mkdirSync, rmSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.dirname(fileURLToPath(import.meta.url));
const url = 'file://' + path.join(root, 'index.html');
const args = process.argv.slice(2);

const browser = await chromium.launch({ args: ['--disable-gpu', '--force-device-scale-factor=1', '--allow-file-access-from-files'] });
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
await page.goto(url);
await page.evaluate(() => window.ready);
const cfg = await page.evaluate(() => ({ fps: window.CONFIG.fps, duration: window.CONFIG.duration }));
const total = Math.round(cfg.fps * cfg.duration);

mkdirSync(path.join(root, 'out'), { recursive: true });

if (args[0] === '--stills') {
  for (const ts of args.slice(1)) {
    const f = Math.round(parseFloat(ts) * cfg.fps);
    await page.evaluate((f) => window.setFrame(f), f);
    await page.screenshot({ path: path.join(root, 'out', `still_${ts}.png`), clip: { x: 0, y: 0, width: 1920, height: 1080 } });
    console.log('still', ts);
  }
  await browser.close();
  process.exit(0);
}

const seqDir = path.join(root, 'out', 'seq');
rmSync(seqDir, { recursive: true, force: true });
mkdirSync(seqDir, { recursive: true });
const t0 = Date.now();
for (let f = 0; f < total; f++) {
  await page.evaluate((f) => window.setFrame(f), f);
  await page.screenshot({ path: path.join(seqDir, `${String(f).padStart(5, '0')}.png`), clip: { x: 0, y: 0, width: 1920, height: 1080 } });
  if (f % 60 === 0) console.log(`frame ${f}/${total}  ${((Date.now() - t0) / 1000).toFixed(1)}s`);
}
await browser.close();

const outFile = path.join(root, 'out', 'swiss-grid-in-motion.mp4');
execSync(`ffmpeg -y -framerate ${cfg.fps} -i "${seqDir}/%05d.png" -c:v libx264 -pix_fmt yuv420p -r ${cfg.fps} -crf 17 -preset slow -movflags +faststart -an "${outFile}"`, { stdio: 'inherit' });
console.log('wrote', outFile);
