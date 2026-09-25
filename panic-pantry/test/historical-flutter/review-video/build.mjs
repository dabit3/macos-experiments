// Panic Pantry — programmatic review-video editor.
//
// Turns the raw artifacts left behind by the automated tests into an edited
// review reel instead of a bare screen recording:
//
//   * test/e2e/run.mjs       -> four-way-match.mov, e2e.log, summary.json, *-{lobby,gameplay,results}.png
//   * test/ui/smoke.mjs      -> browser-smoke.webm, smoke.log, summary.json, NN-*.png
//
// The cut is derived from the logs (every caption is a log line or a summary
// field, never hand-written for a specific run): title/chapter cards, clips of
// the recordings around each logged event with a caption band and a T+ time
// code, 2x2 per-platform screenshot boards, an assertion table comparing the
// final state reported by every client, the browser-smoke checks, and a
// verdict card. Cards and overlays are rendered from HTML with Playwright's
// Chromium (using the app's own Nunito/JetBrains Mono fonts) because this
// machine's ffmpeg has no drawtext filter; ffmpeg does the cutting, scaling,
// overlay, fades, concat and the GIF preview.
//
// Usage:
//   node test/review-video/build.mjs [--e2e <dir>] [--smoke <dir>] [--out <dir>] [--no-gif]
//
// Defaults: the newest .devin/clone-this/panic-pantry/evidence/e2e/<stamp> run,
// evidence/tests/ui-smoke, and output next to the e2e run:
//   <e2e>/review-video.mp4   the edited reel (1280x720, H.264, 30 fps)
//   <e2e>/review-video.gif   short sped-up preview
//   <e2e>/review-video.json  edit decision list (segments, sources, captions)
//   <e2e>/review-video.log   build log

import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, join, relative, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { env } from '../lib/common.mjs';

const here = fileURLToPath(new URL('.', import.meta.url));
const root = resolve(here, '..', '..');
const evidenceRoot = join(root, '.devin', 'clone-this', 'panic-pantry', 'evidence');
const fontsDir = join(root, 'app', 'assets', 'fonts');

const W = 1280;
const H = 720;
const FPS = 30;
const FADE = 0.35;

// --- args -------------------------------------------------------------------
const args = process.argv.slice(2);
function arg(name, dflt) {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : dflt;
}
function newestRun(dir) {
  if (!existsSync(dir)) return null;
  const runs = readdirSync(dir)
    .filter((f) => statSync(join(dir, f)).isDirectory() && existsSync(join(dir, f, 'summary.json')))
    .sort();
  return runs.length ? join(dir, runs[runs.length - 1]) : null;
}
const e2eDir = resolve(arg('e2e', env('PP_E2E_DIR', newestRun(join(evidenceRoot, 'e2e')) ?? '')));
const smokeDir = resolve(arg('smoke', env('PP_SMOKE_DIR', join(evidenceRoot, 'tests', 'ui-smoke'))));
const outDir = resolve(arg('out', env('PP_REVIEW_OUT', e2eDir)));
const wantGif = !args.includes('--no-gif') && env('PP_REVIEW_GIF', '1') === '1';
const FFMPEG = env('FFMPEG', 'ffmpeg');

if (!e2eDir || !existsSync(join(e2eDir, 'summary.json'))) {
  console.error('review-video: no e2e run found (pass --e2e <dir>)');
  process.exit(2);
}
mkdirSync(outDir, { recursive: true });

const lines = [];
function log(msg) {
  const line = `${new Date().toISOString()} ${msg}`;
  lines.push(line);
  console.log(line);
}
const rel = (p) => relative(root, p);

// --- inputs -----------------------------------------------------------------
const e2e = JSON.parse(readFileSync(join(e2eDir, 'summary.json'), 'utf8'));
const e2eLog = readFileSync(join(e2eDir, 'e2e.log'), 'utf8')
  .split('\n')
  .map((l) => /^\[\s*([\d.]+)s\]\s(.*)$/.exec(l))
  .filter(Boolean)
  .map((m) => ({ t: Number(m[1]), msg: m[2] }));
const findT = (re) => e2eLog.find((e) => re.test(e.msg))?.t;
const recording = ['four-way-match.mov', 'four-way-match.mp4'].map((f) => join(e2eDir, f)).find(existsSync);
const recStart = findT(/^screen recording ->/);
const platforms = e2e.joined.map((j) => j.platform);
// A run that aborted before results has no `results`/`problems`; keep the reel
// buildable so the failure is still reviewable.
e2e.results ??= {};
e2e.problems ??= e2e.error ? [e2e.error] : [];
e2e.passed ??= false;
const PLATFORM_LABEL = { web: 'Web · Chromium', ios: 'iOS Simulator', android: 'Android emulator', macos: 'macOS' };

const smoke = existsSync(join(smokeDir, 'summary.json')) ? JSON.parse(readFileSync(join(smokeDir, 'summary.json'), 'utf8')) : null;
const smokeLog = smoke
  ? readFileSync(join(smokeDir, 'smoke.log'), 'utf8')
      .split('\n')
      .map((l) => /^(\d{4}-\d\d-\d\dT[\d:.]+Z)\s(.*)$/.exec(l))
      .filter(Boolean)
      .map((m) => ({ at: Date.parse(m[1]), msg: m[2] }))
  : [];
const smokeVideo = smoke?.video && existsSync(join(smokeDir, smoke.video)) ? join(smokeDir, smoke.video) : null;
const smokeStart = smoke?.videoStartedAt ? Date.parse(smoke.videoStartedAt) : null;

// --- media probes -------------------------------------------------------------
function ff(argv) {
  const r = spawnSync(FFMPEG, ['-hide_banner', '-loglevel', 'error', '-y', ...argv], { encoding: 'utf8' });
  if (r.status !== 0) throw new Error(`ffmpeg failed (${r.status}): ${argv.join(' ')}\n${r.stderr}`);
}
function duration(file) {
  const r = spawnSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', file], { encoding: 'utf8' });
  const d = Number(r.stdout.trim());
  if (r.status !== 0 || !Number.isFinite(d) || d <= 0) {
    throw new Error(`Cannot read a positive media duration: ${file}`);
  }
  return d;
}

// --- HTML cards -------------------------------------------------------------
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const fontFace = (name, file, weight) =>
  `@font-face{font-family:'${name}';src:url('${pathToFileURL(join(fontsDir, file)).href}');font-weight:${weight};}`;
const CSS = `
${fontFace('Nunito', 'Nunito-Regular.ttf', 400)}
${fontFace('Nunito', 'Nunito-SemiBold.ttf', 600)}
${fontFace('Nunito', 'Nunito-Bold.ttf', 700)}
${fontFace('Nunito', 'Nunito-ExtraBold.ttf', 800)}
${fontFace('Nunito', 'Nunito-Black.ttf', 900)}
${fontFace('Mono', 'JetBrainsMono-Medium.ttf', 500)}
:root{--cream:#FFF7E7;--cream2:#F0E5CF;--ink:#102F35;--ink2:#193E44;--coin:#FFD363;--coin2:#C98A12;--paprika:#EF593D;--basil:#248875;--text:#102F35;--text2:#193E44;--text3:#6D736D}
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:${W}px;height:${H}px;overflow:hidden;font-family:'Nunito',sans-serif;color:var(--text)}
body.card{background:var(--cream);background-image:radial-gradient(circle at 12% 0%,rgba(242,181,49,.35),transparent 42%),radial-gradient(circle at 100% 100%,rgba(232,89,60,.22),transparent 48%)}
body.overlay{background:transparent}
.mono{font-family:'Mono',monospace}
.wordmark{display:inline-block;background:var(--paprika);color:#fff;font-weight:900;font-size:22px;letter-spacing:.5px;padding:6px 14px;border-radius:12px;transform:rotate(-3deg);box-shadow:0 4px 0 #9E2F25}
.chapter{position:absolute;top:22px;left:26px;display:flex;gap:10px;align-items:center}
.chip{background:var(--ink);color:#fff;font-weight:800;font-size:20px;padding:8px 16px;border-radius:999px;border:3px solid #fff;box-shadow:0 3px 0 rgba(0,0,0,.25)}
.chip.time{background:#1A1A22;font-family:'Mono',monospace;font-weight:500;font-size:18px}
.chip.pass{background:var(--basil)}
.chip.fail{background:var(--paprika)}
.step{position:absolute;top:22px;right:26px}
.caption{position:absolute;left:0;right:0;bottom:0;padding:22px 34px 26px;background:linear-gradient(180deg,rgba(20,26,40,0),rgba(20,26,40,.86) 35%);color:#fff}
.caption h2{display:flex;align-items:center;gap:14px;font-size:34px;font-weight:900;letter-spacing:-.5px;text-shadow:0 3px 0 rgba(0,0,0,.35)}
.caption h2 .chip{font-size:18px;padding:5px 14px;text-shadow:none}
.caption p{font-size:20px;font-weight:600;opacity:.92;margin-top:6px}
.title{position:absolute;inset:0;display:flex;flex-direction:column;justify-content:center;align-items:flex-start;padding:0 110px}
.title h1{font-size:78px;font-weight:900;letter-spacing:-2px;line-height:1;color:var(--ink);text-shadow:0 5px 0 rgba(36,74,122,.18)}
.title h1 span{color:var(--paprika)}
.title h3{font-size:30px;font-weight:800;color:var(--text2);margin-top:18px}
.title .meta{margin-top:34px;display:flex;gap:12px;flex-wrap:wrap}
.tag{background:#fff;border:2px solid var(--cream2);border-radius:999px;padding:8px 16px;font-weight:800;font-size:18px;color:var(--text2)}
.tag b{color:var(--ink)}
.heading{position:absolute;top:36px;left:60px;right:60px;display:flex;align-items:baseline;gap:18px}
.heading h1{font-size:44px;font-weight:900;color:var(--ink);letter-spacing:-1px}
.heading p{font-size:20px;font-weight:700;color:var(--text3)}
.board{position:absolute;top:104px;left:60px;right:60px;bottom:40px;display:grid;grid-template-columns:1fr 1fr;grid-template-rows:1fr 1fr;gap:18px}
.shot{background:#fff;border:3px solid var(--ink);border-radius:18px;overflow:hidden;position:relative;box-shadow:0 8px 0 rgba(36,74,122,.15)}
.shot img{width:100%;height:100%;object-fit:contain;background:#1A1A22;display:block}
.shot .label{position:absolute;top:10px;left:10px}
.shot .chip{font-size:16px;padding:5px 12px}
.table{position:absolute;top:110px;left:60px;right:60px;background:#fff;border:4px solid var(--ink);border-radius:24px;overflow:hidden;box-shadow:0 10px 0 rgba(36,74,122,.15)}
table{width:100%;border-collapse:collapse}
th,td{padding:9px 22px;text-align:left;font-size:20px;border-bottom:2px solid var(--cream2)}
th{background:var(--ink);color:#fff;font-weight:800;font-size:18px;letter-spacing:.5px;text-transform:uppercase}
td.num{font-family:'Mono',monospace;font-size:21px;color:var(--ink)}
tr.expected td{background:var(--cream);font-weight:800}
.verdict{position:absolute;left:60px;right:60px;bottom:34px;display:flex;align-items:center;gap:18px;font-size:22px;font-weight:800;color:var(--text2)}
.verdict .chip{font-size:26px;padding:12px 26px}
.checks{position:absolute;top:110px;left:60px;right:60px;display:grid;grid-template-columns:1fr 1fr;gap:12px 24px}
.check{display:flex;gap:12px;align-items:flex-start;background:#fff;border:2px solid var(--cream2);border-radius:14px;padding:12px 16px}
.check .dot{flex:none;width:30px;height:30px;border-radius:50%;color:#fff;font-weight:900;display:flex;align-items:center;justify-content:center;font-size:18px}
.check .dot.ok{background:var(--basil)}.check .dot.bad{background:var(--paprika)}
.check b{font-size:19px;display:block}.check small{font-size:15px;color:var(--text3)}
.stars{color:var(--coin);font-size:26px;letter-spacing:2px}
.stars .off{color:var(--cream2)}
.footer{position:absolute;left:60px;right:60px;bottom:24px;font-size:15px;color:var(--text3);font-family:'Mono',monospace}
`;

let browser;
let page;
const work = mkdtempSync(join(tmpdir(), 'pp-review-'));
let cardN = 0;
async function render(bodyClass, html, { transparent = false } = {}) {
  const file = join(work, `card-${String(++cardN).padStart(3, '0')}.html`);
  writeFileSync(file, `<!doctype html><html><head><meta charset="utf-8"><style>${CSS}</style></head><body class="${bodyClass}">${html}</body></html>`);
  await page.goto(pathToFileURL(file).href, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  const png = file.replace(/\.html$/, '.png');
  await page.screenshot({ path: png, omitBackground: transparent });
  return png;
}

const stars = (n, of = 3) =>
  `<span class="stars">${'★'.repeat(n)}<span class="off">${'★'.repeat(Math.max(0, of - n))}</span></span>`;
const chapterChip = (text, n, total) =>
  `<div class="chapter"><span class="chip">${esc(text)}</span>${n ? `<span class="chip time">${n}/${total}</span>` : ''}</div>`;
const overlay = ({ chapter, time, title, sub, badge }) =>
  `${chapterChip(chapter)}${time !== undefined ? `<div class="step"><span class="chip time">T+${time.toFixed(1)}s</span></div>` : ''}
   <div class="caption"><h2>${badge ? `<span class="chip ${badge.toLowerCase()}">${esc(badge)}</span>` : ''}<span>${esc(title)}</span></h2>${sub ? `<p>${esc(sub)}</p>` : ''}</div>`;

// --- segments ---------------------------------------------------------------
const edl = [];
let segN = 0;
const segFile = () => join(work, `seg-${String(++segN).padStart(3, '0')}.mp4`);
const vf = (dur, extra = '') => `${extra}fps=${FPS},format=yuv420p,fade=t=in:st=0:d=${FADE},fade=t=out:st=${Math.max(0, dur - FADE).toFixed(2)}:d=${FADE}`;
const enc = ['-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20', '-pix_fmt', 'yuv420p', '-an'];

async function still(kind, png, dur, meta = {}) {
  const out = segFile();
  ff(['-loop', '1', '-t', String(dur), '-i', png, '-vf', vf(dur), ...enc, out]);
  edl.push({ kind, duration: dur, ...meta });
  log(`segment ${basename(out)} ${kind} ${dur}s${meta.title ? ` — ${meta.title}` : ''}`);
  return out;
}

async function clip(src, start, dur, ov, meta = {}) {
  const total = duration(src);
  const s = Math.max(0, Math.min(start, Math.max(0, total - dur)));
  const d = Math.min(dur, Math.max(0.5, total - s));
  const png = await render('overlay', overlay(ov), { transparent: true });
  const out = segFile();
  const fit = `[0:v]scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0x1A1A22[b];[b][1:v]overlay=0:0,${vf(d)}`;
  ff(['-ss', s.toFixed(2), '-t', d.toFixed(2), '-i', src, '-i', png, '-filter_complex', fit, ...enc, out]);
  edl.push({ kind: 'clip', source: rel(src), sourceStart: Number(s.toFixed(2)), duration: Number(d.toFixed(2)), title: ov.title, sub: ov.sub, ...meta });
  log(`segment ${basename(out)} clip ${rel(src)} @${s.toFixed(1)}s +${d.toFixed(1)}s — ${ov.title}`);
  return out;
}

const board = (chapter, n, total, heading, sub, shots) =>
  `${chapterChip(chapter, n, total)}<div class="heading" style="top:80px"><h1>${esc(heading)}</h1><p>${esc(sub)}</p></div>
   <div class="board" style="top:150px">${shots
     .map(
       (s) =>
         `<div class="shot"><img src="${pathToFileURL(s.file).href}"><div class="label"><span class="chip">${esc(s.label)}</span></div></div>`,
     )
     .join('')}</div>`;

// Recording time for a log time (seconds into the e2e run).
const vt = (t) => (recStart === undefined ? t : t - recStart);

async function main() {
  const { chromium } = await import('playwright');
  browser = await chromium.launch({ headless: true });
  page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  log(`e2e run: ${rel(e2eDir)} (${e2e.passed ? 'PASS' : 'FAIL'}), smoke: ${smoke ? rel(smokeDir) : 'none'}, recording: ${recording ? rel(recording) : 'none'}`);

  const segs = [];
  const chapters = ['Lobby', 'Match', 'Results', 'Browser smoke', 'Verdict'];
  const total = platforms.length;

  // 1. Title
  const startedAt = new Date(e2e.startedAt);
  segs.push(
    await still(
      'title',
      await render(
        'card',
        `<div class="title"><span class="wordmark">PANIC PANTRY</span>
         <h1 style="margin-top:26px">Cross-platform<br>multiplayer <span>review</span></h1>
         <h3>${esc(platforms.map((p) => PLATFORM_LABEL[p]).join(' · '))} — one authoritative kitchen</h3>
         <div class="meta"><span class="tag">room <b>${esc(e2e.room)}</b></span><span class="tag">seed <b>${e2e.seed}</b></span><span class="tag">level <b>${esc(e2e.level)}</b></span><span class="tag">sim speed <b>${e2e.speed}x</b></span><span class="tag">${esc(startedAt.toISOString().replace('T', ' ').slice(0, 16))} UTC</span></div></div>
         <div class="footer">${esc(rel(e2eDir))}</div>`,
      ),
      4,
      { title: 'Title' },
    ),
  );

  // 2. Lobby
  const tLobby = findT(/^lobby:/) ?? findT(/screenshot \w+\/lobby/);
  const lobbyLine = e2eLog.find((e) => /^lobby:/.test(e.msg))?.msg ?? '';
  if (recording && tLobby !== undefined) {
    segs.push(
      await clip(recording, vt(tLobby) - 2, 6, {
        chapter: chapters[0],
        time: tLobby,
        title: `${total} clients joined room ${e2e.room}`,
        sub: lobbyLine.replace(/^lobby:\s*/, ''),
      }),
    );
  }
  const shotsOf = (state) => platforms.filter((p) => existsSync(e2e.screenshots[p]?.[state] ?? '')).map((p) => ({ file: e2e.screenshots[p][state], label: PLATFORM_LABEL[p] }));
  if (shotsOf('lobby').length) {
    segs.push(await still('board', await render('card', board(chapters[0], 1, 5, 'Same lobby, four devices', `join code ${e2e.room} · host picks ${e2e.level}`, shotsOf('lobby'))), 4, { title: 'Lobby board' }));
  }

  // 3. Match
  const tStart = findT(/^match started/);
  const planLine = e2eLog.find((e) => /^plan:/.test(e.msg))?.msg ?? '';
  if (recording && tStart !== undefined) {
    segs.push(
      await clip(recording, vt(tStart) - 1, 7, {
        chapter: chapters[1],
        time: tStart,
        title: 'Match started — countdown, then the scripted shift',
        sub: planLine.replace(/^plan:\s*/, ''),
      }),
    );
  }
  const mid = e2eLog.filter((e) => /^mid-match /.test(e.msg));
  if (mid.length) {
    const first = /tick=(\d+) score=(\d+)/.exec(mid[0].msg);
    const agree = mid.every((m) => m.msg.includes(`tick=${first?.[1]} score=${first?.[2]}`));
    if (recording) {
      segs.push(
        await clip(recording, vt(mid[0].t) - 6, 6, {
          chapter: chapters[1],
          time: mid[0].t,
          badge: agree ? 'PASS' : 'FAIL',
          title: `Mid-match: every client at tick ${first?.[1]}, score ${first?.[2]}`,
          sub: mid.map((m) => m.msg.replace(/^mid-match\s+/, '').replace(/ phase=\w+/, '')).join('   '),
        }),
      );
    }
    if (shotsOf('gameplay').length) {
      segs.push(await still('board', await render('card', board(chapters[1], 2, 5, 'Gameplay on every platform', `tick ${first?.[1]} · score ${first?.[2]} · ${agree ? 'all clients agree' : 'clients disagree'}`, shotsOf('gameplay'))), 4, { title: 'Gameplay board' }));
    }
  }
  const tLate = findT(/screenshot \w+\/gameplay-late/);
  if (recording && tLate !== undefined) {
    segs.push(await clip(recording, vt(tLate), 6, { chapter: chapters[1], time: tLate, title: 'Late shift — combos, tips and expiring tickets', sub: `expected ${e2e.expected.served} served, best combo x${e2e.expected.bestCombo}, ${e2e.expected.expired} expired` }));
  }

  // 4. Results
  const tResults = findT(/screenshot \w+\/results/);
  if (recording && tResults !== undefined) {
    segs.push(await clip(recording, vt(tResults) - 5, 7, { chapter: chapters[2], time: tResults, title: "Time's up — results on all four clients", sub: `score ${e2e.expected.score} · ${e2e.expected.stars} star(s) · ${e2e.expected.served} served · tips ${e2e.expected.tips}` }));
  }
  if (shotsOf('results').length) {
    segs.push(await still('board', await render('card', board(chapters[2], 3, 5, 'Results on every platform', 'identical report card expected everywhere', shotsOf('results'))), 4, { title: 'Results board' }));
  }
  const row = (name, r, cls = '') =>
    r
      ? `<tr class="${cls}"><td>${esc(name)}</td><td class="num">${r.score}</td><td>${stars(r.stars)}</td><td class="num">${r.served}</td><td class="num">${r.tips}</td><td class="num">x${r.bestCombo}</td><td class="num">${r.tick}</td></tr>`
      : `<tr class="${cls}"><td>${esc(name)}</td><td colspan="6" class="num">no results report</td></tr>`;
  const finalLine = e2eLog.find((e) => /^(PASS|FAIL)/.test(e.msg))?.msg ?? e2e.error ?? '';
  segs.push(
    await still(
      'assertion',
      await render(
        'card',
        `${chapterChip(chapters[2], 4, 5)}<div class="heading" style="top:80px"><h1>Final state, client by client</h1><p>${esc(`${e2e.problems.length} problem(s)`)}</p></div>
         <div class="table" style="top:150px"><table><tr><th>Client</th><th>Score</th><th>Stars</th><th>Served</th><th>Tips</th><th>Combo</th><th>Tick</th></tr>
         ${row('expected (plan)', e2e.expected, 'expected')}
         ${platforms.map((p) => row(`${e2e.joined.find((j) => j.platform === p)?.name} · ${p}`, e2e.results[p])).join('')}
         ${e2e.server ? row('server', e2e.server) : ''}</table></div>
         <div class="verdict"><span class="chip ${e2e.passed ? 'pass' : 'fail'}">${e2e.passed ? 'PASS' : 'FAIL'}</span><span>${esc(finalLine.replace(/^(PASS|FAIL):\s*/, ''))}</span></div>`,
      ),
      6,
      { title: 'Assertion table' },
    ),
  );

  // 5. Browser smoke (Playwright)
  if (smoke) {
    const checks = smoke.checks ?? [];
    const shotsInLog = smokeLog.filter((e) => /^screenshot /.test(e.msg));
    segs.push(
      await still(
        'title',
        await render(
          'card',
          `<div class="title"><span class="wordmark">PANIC PANTRY</span><h1 style="margin-top:26px">Browser <span>smoke</span> test</h1>
           <h3>Playwright drives the web client through home, how-to-play, join errors, host/leave and themes</h3>
           <div class="meta"><span class="tag">${checks.length} checks</span><span class="tag">viewport <b>${smoke.viewport.width}×${smoke.viewport.height}</b></span><span class="tag">${smokeVideo ? 'session recording' : 'screenshots only'}</span></div></div>
           <div class="footer">${esc(rel(smokeDir))}</div>`,
        ),
        3,
        { title: 'Browser smoke title' },
      ),
    );
    // One clip per check: the moments leading up to the check, captioned with
    // the check name/detail from the log. Falls back to the nearest screenshot.
    const checkLines = smokeLog.filter((e) => /^(PASS|FAIL) /.test(e.msg));
    for (let i = 0; i < checkLines.length; i++) {
      const c = checkLines[i];
      const m = /^(PASS|FAIL) (.*?)(?: — (.*))?$/.exec(c.msg);
      const t = smokeStart ? (c.at - smokeStart) / 1000 : null;
      const ov = { chapter: chapters[3], time: t ?? undefined, badge: m[1], title: m[2], sub: m[3] };
      if (smokeVideo && t !== null) {
        segs.push(await clip(smokeVideo, t - 2.2, 2.8, ov, { check: m[2] }));
      } else {
        const near = shotsInLog.filter((s) => s.at <= c.at).pop() ?? shotsInLog[0];
        if (near) {
          const file = join(smokeDir, near.msg.replace(/^screenshot /, ''));
          if (existsSync(file)) {
            const png = await render('overlay', overlay(ov), { transparent: true });
            const out = segFile();
            ff(['-loop', '1', '-t', '2.5', '-i', file, '-loop', '1', '-t', '2.5', '-i', png, '-filter_complex', `[0:v]scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0x1A1A22[b];[b][1:v]overlay=0:0,${vf(2.5)}`, ...enc, out]);
            edl.push({ kind: 'still-clip', source: rel(file), duration: 2.5, title: m[2], check: m[2] });
            segs.push(out);
          }
        }
      }
    }
    segs.push(
      await still(
        'assertion',
        await render(
          'card',
          `${chapterChip(chapters[3])}<div class="heading" style="top:80px"><h1>Smoke checks</h1><p>${checks.filter((c) => c.ok).length}/${checks.length} passed</p></div>
           <div class="checks" style="top:150px">${checks.map((c) => `<div class="check"><span class="dot ${c.ok ? 'ok' : 'bad'}">${c.ok ? '✓' : '✕'}</span><span><b>${esc(c.name)}</b>${c.detail ? `<small>${esc(c.detail)}</small>` : ''}</span></div>`).join('')}</div>`,
        ),
        5,
        { title: 'Smoke checks' },
      ),
    );
  }

  // 6. Verdict
  const smokeOk = smoke ? smoke.passed : null;
  segs.push(
    await still(
      'verdict',
      await render(
        'card',
        `<div class="title"><span class="wordmark">PANIC PANTRY</span><h1 style="margin-top:26px">${e2e.passed && smokeOk !== false ? 'All clear.' : 'Needs attention.'}</h1>
         <div class="meta" style="margin-top:28px">
           <span class="tag"><span class="chip ${e2e.passed ? 'pass' : 'fail'}" style="font-size:16px;padding:4px 12px">${e2e.passed ? 'PASS' : 'FAIL'}</span>&nbsp; 4-way match: ${esc(platforms.join(', '))} → score <b>${e2e.expected.score}</b>, ${stars(e2e.expected.stars)}</span>
           ${smoke ? `<span class="tag"><span class="chip ${smokeOk ? 'pass' : 'fail'}" style="font-size:16px;padding:4px 12px">${smokeOk ? 'PASS' : 'FAIL'}</span>&nbsp; browser smoke: <b>${smoke.checks.filter((c) => c.ok).length}/${smoke.checks.length}</b> checks</span>` : ''}
         </div>
         <h3 style="margin-top:30px">Deterministic seed ${e2e.seed}, server-authoritative simulation, ${e2e.expected.tick} ticks.<br>Every caption in this reel was generated from the test logs.</h3></div>
         <div class="footer">${esc(rel(e2eDir))} · generated ${new Date().toISOString()}</div>`,
      ),
      5,
      { title: 'Verdict' },
    ),
  );

  // Concat
  const list = join(work, 'concat.txt');
  writeFileSync(list, segs.map((s) => `file '${s.replace(/'/g, "'\\''")}'`).join('\n') + '\n');
  const mp4 = join(outDir, 'review-video.mp4');
  ff(['-f', 'concat', '-safe', '0', '-i', list, '-c', 'copy', '-movflags', '+faststart', mp4]);
  const dur = duration(mp4);
  log(`wrote ${rel(mp4)} (${dur.toFixed(1)}s, ${segs.length} segments)`);

  let gif = null;
  if (wantGif) {
    gif = join(outDir, 'review-video.gif');
    ff(['-i', mp4, '-vf', `setpts=PTS/4,fps=8,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=4`, gif]);
    log(`wrote ${rel(gif)} (4x speed preview)`);
  }

  const summary = {
    generatedAt: new Date().toISOString(),
    output: { video: rel(mp4), gif: gif ? rel(gif) : null, durationSeconds: Number(dur.toFixed(2)), size: `${W}x${H}`, fps: FPS },
    inputs: { e2e: rel(e2eDir), recording: recording ? rel(recording) : null, smoke: smoke ? rel(smokeDir) : null, smokeVideo: smokeVideo ? rel(smokeVideo) : null },
    e2ePassed: e2e.passed,
    smokePassed: smokeOk,
    segments: edl,
  };
  writeFileSync(join(outDir, 'review-video.json'), JSON.stringify(summary, null, 2));
  return true;
}

main()
  .then(() => {
    log('done');
  })
  .catch((e) => {
    log(`FAILED: ${e.stack || e}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await browser?.close();
    writeFileSync(join(outDir, 'review-video.log'), lines.join('\n') + '\n');
    if (env('PP_REVIEW_KEEP_WORK', '0') !== '1') rmSync(work, { recursive: true, force: true });
  });
