// Programmatic review-video editor.
//
// Turns raw evidence (per-platform frame sequences captured by the e2e, or a
// screen-recording MP4) into an edited review: title card, chapter cards,
// captioned side-by-side web | iOS segments, a chapter timeline, a check
// summary card and fades between every cut. Overlays are rendered from HTML
// with Playwright (transparent PNGs) and composited with ffmpeg, so no
// drawtext/freetype build of ffmpeg is required.
//
// Usage: node review-video.mjs <script.json> <out.mp4>
//
// script.json:
// {
//   "title": "Voxelhearth — web × iOS multiplayer", "subtitle": "...",
//   "fps": 0.67,                       // playback rate for frame sequences (frames captured every 1.5s → realtime)
//   "sources": {                       // 1–2 sources shown side by side
//     "web": { "frames": "<dir of NNNN.png>", "label": "Web (Chrome)" },
//     "ios": { "frames": "<dir>", "label": "iOS Simulator" }
//     // or: "screen": { "video": "recording.mp4", "label": "Computer-use run" }
//   },
//   "chapters": [ { "title": "Lobby", "caption": "...", "from": <frame|seconds>, "to": <frame|seconds>, "notes": ["..."] } ],
//   "checks": [ { "name": "...", "ok": true } ],
//   "footer": "run id · date"
// }
import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const [scriptPath, outPath] = process.argv.slice(2);
if (!scriptPath || !outPath) {
  console.error('usage: node review-video.mjs <script.json> <out.mp4>');
  process.exit(2);
}
const script = JSON.parse(readFileSync(scriptPath, 'utf8'));
const W = 1920, H = 1080, OUT_FPS = 24;
const work = join(dirname(resolve(outPath)), '.review-work');
rmSync(work, { recursive: true, force: true });
mkdirSync(work, { recursive: true });
const ff = (args, timeout = 600000) => execFileSync('ffmpeg', ['-y', '-loglevel', 'error', ...args], { stdio: ['ignore', 'pipe', 'pipe'], timeout });
const fontPath = resolve(here, '../../app/assets/fonts/Outfit-Variable.ttf');
const fontFace = existsSync(fontPath)
  ? `@font-face{font-family:HearthUi;src:url('https://review.voxelhearth.local/Outfit.ttf')}`
  : '';
const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

// ---------------------------------------------------------------- layout
// Video windows inside the 1920x1080 canvas; the overlay leaves them transparent.
const sourceIds = Object.keys(script.sources ?? {}).slice(0, 2);
const frameList = (dir) => readdirSync(dir).filter((f) => f.endsWith('.png')).sort();
const probe = (src) => {
  const file = src.video ?? join(src.frames, frameList(src.frames)[0]);
  const [w, h] = execFileSync('ffprobe', ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height', '-of', 'csv=p=0', file], { encoding: 'utf8' }).trim().split(',').map(Number);
  return w / h;
};
// Windows share the 1920x800 band between the bars; widths follow each source's
// aspect ratio (a portrait phone gets a narrow column, a landscape one a wide one).
const windows = {};
{
  const band = { x: 40, y: 150, w: 1840, h: 800, gap: 40 };
  const aspects = sourceIds.map((id) => probe(script.sources[id]));
  const natural = aspects.map((a) => a * band.h);
  const scale = Math.min(1, (band.w - band.gap * (sourceIds.length - 1)) / natural.reduce((s, w) => s + w, 0));
  const widths = natural.map((w) => Math.round(w * scale));
  const h = Math.round(band.h * scale);
  let x = Math.round(band.x + (band.w - widths.reduce((s, w) => s + w, 0) - band.gap * (sourceIds.length - 1)) / 2);
  sourceIds.forEach((id, i) => {
    windows[id] = { x, y: band.y + Math.round((band.h - h) / 2), w: widths[i], h };
    x += widths[i] + band.gap;
  });
}

const css = `
${fontFace}
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:${W}px;height:${H}px;background:transparent;overflow:hidden;font-family:HearthUi,sans-serif;color:#fff4dc}
.bar{position:absolute;left:0;right:0;background:rgba(7,30,43,.96)}
.top{top:0;height:130px;border-bottom:2px solid #4e7986}
.bottom{top:970px;height:110px;border-top:2px solid #4e7986}
.title{position:absolute;left:40px;top:22px;font-size:44px;font-weight:800;letter-spacing:1px;white-space:nowrap;max-width:1450px;overflow:hidden;text-overflow:ellipsis}
.sub{position:absolute;left:40px;top:80px;font-size:24px;color:#a0a0a0;white-space:nowrap}
.chip{position:absolute;right:40px;top:30px;font-size:22px;color:#ffcc75;border:1px solid #ffcc75;border-radius:10px;padding:8px 16px}
.caption{position:absolute;left:40px;top:14px;font-size:30px;text-shadow:3px 3px 0 #3f3f3f;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.notes{position:absolute;left:40px;top:64px;font-size:20px;color:#a0a0a0;white-space:nowrap;overflow:hidden}
.timeline{position:absolute;right:40px;top:22px;display:flex;gap:6px}
.tl{height:14px;background:#404040;border:2px solid #202020}
.tl.done{background:#70e2c4}.tl.now{background:#ffcc75}
.tlabel{position:absolute;right:40px;top:52px;font-size:20px;color:#a0a0a0}
.win{position:absolute;border:4px solid #000;box-shadow:0 0 0 4px #8b8b8b inset}
.wlabel{position:absolute;font-size:22px;background:rgba(0,0,0,.8);padding:4px 12px;color:#fff}
.card{position:absolute;inset:0;background:radial-gradient(ellipse at 80% 20%,#326758 0%,transparent 65%),repeating-linear-gradient(45deg,transparent 0px,transparent 79px,#ffffff07 80px,#ffffff07 81px),#071e2b;}
.card .shade{position:absolute;inset:0;background:linear-gradient(0deg,#071e2baa,transparent);border:24px solid #ffffff05}
.big{position:absolute;left:80px;right:80px;top:300px;text-align:center;font-weight:800;font-size:96px;line-height:1.15;letter-spacing:-3px}
.mid{position:absolute;left:120px;right:120px;top:560px;text-align:center;font-size:40px;color:#a0a0a0;line-height:1.4}
.small{position:absolute;left:0;right:0;top:960px;text-align:center;font-size:22px;color:#707070}
.ctitle{position:absolute;left:0;right:0;top:120px;text-align:center;font-size:28px;color:#70e2c4;letter-spacing:5px;text-transform:uppercase}
.cbig{position:absolute;left:80px;right:80px;top:210px;text-align:center;font-weight:800;font-size:110px;line-height:1.1;letter-spacing:-3px}
.ccap{position:absolute;left:160px;right:160px;top:440px;text-align:center;font-size:40px;color:#c6c6c6;line-height:1.4}
.cnotes{position:absolute;left:260px;right:260px;top:660px;font-size:30px;color:#a0a0a0;line-height:1.6}
.checks{position:absolute;left:200px;right:200px;top:250px;font-size:28px;line-height:1.65}
.checks div{display:flex;gap:24px;align-items:baseline}
.ok{color:#70e2c4;min-width:110px}.fail{color:#ff887d;min-width:110px}
.summary{position:absolute;left:0;right:0;top:120px;text-align:center;font-size:72px;text-shadow:6px 6px 0 #3f3f3f}
`;

// The timeline never grows past ~1/3 of the frame; captions get the rest.
const chapterCount = (script.chapters ?? []).length;
const tlSegment = Math.max(6, Math.min(34, Math.floor(640 / Math.max(1, chapterCount)) - 6));
const tlWidth = chapterCount * (tlSegment + 10);
const textMax = W - 40 - 40 - tlWidth - 60;
const timeline = (idx) => `<div class="timeline">${(script.chapters ?? []).map((_, i) => `<div class="tl ${i < idx ? 'done' : i === idx ? 'now' : ''}" style="width:${tlSegment}px"></div>`).join('')}</div>
<div class="tlabel">chapter ${idx + 1} / ${chapterCount}</div>`;

const overlayHtml = (chapter, idx) => `<!doctype html><html><head><style>${css}</style></head><body>
<div class="bar top"><div class="title">${esc(script.title)}</div><div class="sub">${esc(script.subtitle ?? '')}</div><div class="chip">${esc(chapter.title)}</div></div>
${sourceIds.map((id) => { const w = windows[id]; return `<div class="win" style="left:${w.x - 4}px;top:${w.y - 4}px;width:${w.w + 8}px;height:${w.h + 8}px"></div><div class="wlabel" style="left:${w.x}px;top:${w.y + w.h - 40}px">${esc(script.sources[id].label ?? id)}</div>`; }).join('')}
<div class="bar bottom"><div class="caption" style="max-width:${textMax}px">${esc(chapter.caption ?? '')}</div><div class="notes" style="max-width:${textMax}px">${esc((chapter.notes ?? []).join('   ·   '))}</div>${timeline(idx)}</div>
</body></html>`;

const titleHtml = () => `<!doctype html><html><head><style>${css}</style></head><body><div class="card"><div class="shade"></div>
<div class="big">${esc(script.title)}</div><div class="mid">${esc(script.subtitle ?? '')}</div>
<div class="small">${esc(script.footer ?? '')} · edited programmatically by test/tools/review-video.mjs</div></div></body></html>`;

const chapterHtml = (chapter, idx) => `<!doctype html><html><head><style>${css}</style></head><body><div class="card"><div class="shade"></div>
<div class="ctitle">Chapter ${idx + 1} of ${script.chapters.length}</div><div class="cbig">${esc(chapter.title)}</div>
<div class="ccap">${esc(chapter.caption ?? '')}</div>
<div class="cnotes">${(chapter.notes ?? []).map((n) => `<div>· ${esc(n)}</div>`).join('')}</div></div></body></html>`;

const summaryHtml = () => {
  const checks = script.checks ?? [];
  const passed = checks.filter((c) => c.ok).length;
  const rows = checks.slice(0, 18).map((c) => `<div><span class="${c.ok ? 'ok' : 'fail'}">${c.ok ? 'PASS' : 'FAIL'}</span><span>${esc(c.name)}</span></div>`).join('');
  const more = checks.length > 18 ? `<div><span class="ok"></span><span>… ${checks.length - 18} more in report.md</span></div>` : '';
  return `<!doctype html><html><head><style>${css}</style></head><body><div class="card"><div class="shade"></div>
<div class="summary">${passed} / ${checks.length} checks passed</div><div class="checks">${rows}${more}</div>
<div class="small">${esc(script.footer ?? '')}</div></div></body></html>`;
};

// ---------------------------------------------------------------- render overlays
const browser = await chromium.launch({ channel: 'chrome', headless: true });
const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
await page.route('https://review.voxelhearth.local/Outfit.ttf', route =>
  route.fulfill({ path: fontPath, contentType: 'font/ttf', headers: { 'access-control-allow-origin': '*' } }));
const renderPng = async (html, file, transparent) => {
  await page.setContent(html, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: file, omitBackground: transparent, type: 'png' });
};

// ---------------------------------------------------------------- clips
const clips = [];
const still = async (html, file, seconds) => {
  const png = `${file}.png`;
  await renderPng(html, png, false);
  ff(['-loop', '1', '-framerate', String(OUT_FPS), '-t', String(seconds), '-i', png,
    '-vf', `fade=t=in:st=0:d=0.4,fade=t=out:st=${Math.max(0, seconds - 0.4)}:d=0.4,format=yuv420p`,
    '-r', String(OUT_FPS), '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20', file]);
  clips.push(file);
};

const fps = script.fps ?? 1 / 1.5;

const segment = async (chapter, idx, file) => {
  const overlay = join(work, `overlay-${idx}.png`);
  await renderPng(overlayHtml(chapter, idx), overlay, true);
  const inputs = [];
  const filters = [`color=c=0x0b0b0d:s=${W}x${H}:r=${OUT_FPS}[bg]`];
  let last = 'bg';
  let dur = 0;
  sourceIds.forEach((id, i) => {
    const src = script.sources[id];
    const win = windows[id];
    if (src.frames) {
      const files = frameList(src.frames);
      const from = Math.max(0, Math.min(files.length - 1, Math.floor(chapter.from ?? 0)));
      const to = Math.max(from + 1, Math.min(files.length, Math.ceil(chapter.to ?? files.length)));
      const list = join(work, `list-${idx}-${id}.txt`);
      writeFileSync(list, files.slice(from, to).map((f) => `file '${join(src.frames, f)}'\nduration ${1 / fps}`).join('\n') + `\nfile '${join(src.frames, files[to - 1])}'\n`);
      inputs.push('-f', 'concat', '-safe', '0', '-i', list);
      dur = Math.max(dur, (to - from) / fps);
    } else if (src.video) {
      inputs.push('-ss', String(chapter.from ?? 0), '-to', String(chapter.to ?? 1e9), '-i', src.video);
      dur = Math.max(dur, (chapter.to ?? 0) - (chapter.from ?? 0));
    }
    filters.push(`[${i}:v]fps=${OUT_FPS},scale=${win.w}:${win.h}:force_original_aspect_ratio=decrease:flags=neighbor,crop='min(iw,${win.w})':'min(ih,${win.h})',pad=${win.w}:${win.h}:(ow-iw)/2:(oh-ih)/2:color=0x000000,setsar=1[s${i}]`);
    filters.push(`[${last}][s${i}]overlay=${win.x}:${win.y}:shortest=0:eof_action=repeat[l${i}]`);
    last = `l${i}`;
  });
  inputs.push('-loop', '1', '-i', overlay);
  filters.push(`[${last}][${sourceIds.length}:v]overlay=0:0:shortest=0[ov]`);
  filters.push(`[ov]trim=duration=${Math.max(1, dur).toFixed(3)},fade=t=in:st=0:d=0.3,fade=t=out:st=${Math.max(0, dur - 0.3).toFixed(3)}:d=0.3,format=yuv420p[out]`);
  ff([...inputs, '-filter_complex', filters.join(';'), '-map', '[out]', '-r', String(OUT_FPS), '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20', '-t', Math.max(1, dur).toFixed(3), file]);
  clips.push(file);
};

await still(titleHtml(), join(work, 'c00-title.mp4'), 3.5);
for (let i = 0; i < (script.chapters ?? []).length; i++) {
  const ch = script.chapters[i];
  await still(chapterHtml(ch, i), join(work, `c${String(i + 1).padStart(2, '0')}-card.mp4`), 2.5);
  await segment(ch, i, join(work, `c${String(i + 1).padStart(2, '0')}-seg.mp4`));
}
await still(summaryHtml(), join(work, 'c99-summary.mp4'), 6);
await browser.close();

// ---------------------------------------------------------------- concat
const concat = join(work, 'concat.txt');
writeFileSync(concat, clips.map((c) => `file '${c}'`).join('\n') + '\n');
ff(['-f', 'concat', '-safe', '0', '-i', concat, '-c', 'copy', '-movflags', '+faststart', resolve(outPath)]);
const edl = { title: script.title, output: resolve(outPath), clips: clips.map((c) => c.replace(work + '/', '')), chapters: script.chapters, sources: script.sources, checks: script.checks?.length };
writeFileSync(resolve(outPath).replace(/\.mp4$/, '.edl.json'), JSON.stringify(edl, null, 2));
rmSync(work, { recursive: true, force: true });
console.log('review video', resolve(outPath));
