#!/usr/bin/env node
// Sensitivity check for the normalized visual gate (gate.mjs) used by run.mjs.
//
// Re-evaluates the last captured reference/clone pairs with the gate (the
// recorded verdicts must be reproduced), then injects synthetic defects into
// each clone capture and asserts the gate FAILS for every one of them:
//   - a missing 16x16 and 24x24 logical-px element
//   - a text-sized 80x14 logical-px strip moved down 3 px and 4 px
//   - a 40x16 logical-px area recoloured
// Defects are placed on the highest-contrast content outside the masked
// regions, i.e. on real UI (icons, labels, borders), not on empty background.
// This proves the rasteriser allowances (box averaging, tolerance, 1-px
// placement shift, thin-line erosion) cannot hide content differences of the
// size the gate is designed to catch. Content whose own contrast is below the
// per-channel tolerance (very light secondary text) is out of the gate's reach
// by construction and is not exercised here; likewise a couple of missing
// letters of 11-px body text (~12x12 logical px) is below the guaranteed
// sensitivity — the placement allowance can match them against neighbouring
// glyphs — so the smallest element exercised is 16x16.
//
//   node test/visual/selftest.mjs            # uses evidence/diffs/visual-parity.json
//
// Exit 0 when every genuine pair reproduces its verdict and every injected
// defect fails.

import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { env } from '../lib/common.mjs';
import { decodePng } from '../lib/png.mjs';
import { describe, evaluate } from './gate.mjs';

const here = fileURLToPath(new URL('.', import.meta.url));
const root = resolve(here, '..', '..');
const EVIDENCE = resolve(env('PP_EVIDENCE_ROOT', join(root, '.devin', 'clone-this', 'panic-pantry', 'evidence')));
const summary = JSON.parse(readFileSync(join(EVIDENCE, 'diffs', 'visual-parity.json'), 'utf8'));

const copy = (img) => ({ width: img.width, height: img.height, data: Buffer.from(img.data) });

/** Copy of `img` with rect (physical px) filled from the pixel just outside it. */
function erase(img, { x, y, w, h }) {
  const out = copy(img);
  const src = ((y - 1) * img.width + (x - 1)) * 4;
  for (let yy = y; yy < y + h; yy++) {
    for (let xx = x; xx < x + w; xx++) {
      img.data.copy(out.data, (yy * img.width + xx) * 4, src, src + 3);
    }
  }
  return out;
}

/** Copy of `img` with rect (physical px) moved down by `dy`. */
function nudge(img, { x, y, w, h }, dy) {
  const out = copy(img);
  for (let yy = y + h - 1; yy >= y; yy--) {
    const from = (yy * img.width + x) * 4;
    out.data.copy(out.data, ((yy + dy) * img.width + x) * 4, from, from + w * 4);
  }
  return out;
}

/** Copy of `img` with rect (physical px) tinted towards a different hue. */
function tint(img, { x, y, w, h }) {
  const out = copy(img);
  for (let yy = y; yy < y + h; yy++) {
    for (let xx = x; xx < x + w; xx++) {
      const o = (yy * img.width + xx) * 4;
      out.data[o] = Math.max(0, img.data[o] - 90);
      out.data[o + 2] = Math.min(255, img.data[o + 2] + 60);
    }
  }
  return out;
}

/**
 * The `w`x`h` logical-px rectangle (outside the masks, clear of the edges)
 * with the most horizontal edges stronger than the gate's tolerance — that is,
 * the densest content the gate is expected to see.
 */
function busiest(img, dpr, w, h, masks, tolerance) {
  const W = Math.round(w * dpr);
  const H = Math.round(h * dpr);
  const step = Math.round(dpr);
  let best = { x: 0, y: 0, score: -1 };
  for (let y = 8; y + H < img.height - 8; y += 8) {
    for (let x = 8; x + W < img.width - 8; x += 8) {
      if (masks.some((m) => x < m.x + m.w + 8 && x + W > m.x - 8 && y < m.y + m.h + 8 && y + H > m.y - 8)) continue;
      let score = 0;
      for (let yy = y; yy < y + H; yy += 2) {
        for (let xx = x; xx < x + W; xx += 2) {
          const o = (yy * img.width + xx) * 4;
          const r = o + 4 * step;
          const d = Math.max(
            Math.abs(img.data[o] - img.data[r]),
            Math.abs(img.data[o + 1] - img.data[r + 1]),
            Math.abs(img.data[o + 2] - img.data[r + 2]),
          );
          if (d > tolerance + 20) score++;
        }
      }
      if (score > best.score) best = { x, y, score };
    }
  }
  return { x: best.x, y: best.y, w: W, h: H };
}

let failed = false;
const say = (ok, msg) => {
  console.log(`${ok ? 'PASS' : 'FAIL'} ${msg}`);
  if (!ok) failed = true;
};

const rows = summary.results.filter((r) => !r.error);
if (!rows.length) {
  console.log('FAIL: no captured pairs in visual-parity.json');
  process.exit(1);
}

for (const r of rows) {
  const ref = decodePng(readFileSync(r.raw.reference));
  const clone = decodePng(readFileSync(r.raw.clone));
  const { dpr } = r.view;
  const p = {
    block: r.normalized.block,
    tolerance: r.normalized.tolerance,
    shift: r.normalized.shift,
    maxBlocks: r.normalized.maxBlocks,
    maxCore: r.normalized.maxCore,
    maxCluster: r.normalized.maxCluster,
  };
  const run = (img) => evaluate(ref, img, dpr, r.masks, p);
  const tag = `${r.platform} ${r.state}:`;

  const genuine = run(clone);
  say(genuine.pass === r.pass, `${tag} gate reproduces recorded verdict (${describe(genuine)})`);
  if (!genuine.pass) continue; // injected defects prove nothing on a pair that already fails

  for (const size of [16, 24]) {
    const rect = busiest(clone, dpr, size, size, r.masks, p.tolerance);
    const res = run(erase(clone, rect));
    say(!res.pass, `${tag} erased ${size}x${size} logical px element at ${rect.x},${rect.y} is caught (${describe(res)})`);
  }
  const strip = busiest(clone, dpr, 80, 14, r.masks, p.tolerance);
  for (const px of [3, 4]) {
    const res = run(nudge(clone, strip, Math.round(px * dpr)));
    say(!res.pass, `${tag} 80x14 logical px strip at ${strip.x},${strip.y} moved ${px} px is caught (${describe(res)})`);
  }
  const button = busiest(clone, dpr, 40, 16, r.masks, p.tolerance);
  const res = run(tint(clone, button));
  say(!res.pass, `${tag} 40x16 logical px recolour at ${button.x},${button.y} is caught (${describe(res)})`);
}

console.log(failed ? 'FAIL: gate is not sensitive enough' : 'PASS: gate reproduces verdicts and catches every injected defect');
process.exit(failed ? 1 : 0);
