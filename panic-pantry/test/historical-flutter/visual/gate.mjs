// The normalized visual-parity gate shared by run.mjs (which captures) and
// selftest.mjs (which proves the gate still catches injected defects).
//
// Inputs are two same-size physical-pixel captures of the same logical
// viewport plus the platform-specific rectangles to exclude. Three passes run on
// DPR-normalized images and the pair fails when EITHER pass finds contiguous
// differences:
//
//   1. block pass — both images box-averaged to `block` logical px, compared
//      with a per-channel `tolerance` and a placement allowance of `shift`
//      blocks, then intersected with a logical-pixel pass using the same
//      tolerance/allowance (`refine`). Averaging forgives rasteriser stroke
//      weight, the intersection forgives 1-px edge snapping of large shapes;
//      only content that differs at both scales survives. Catches thin missing
//      lines (borders, dividers) that the second pass cannot see.
//   2. core pass — logical-pixel comparison with the same tolerance and a
//      `shift` px allowance, then a morphological closing (dilate + erode) and
//      one more erosion. Sub-pixel drift of large glyph stems leaves 1-px-thin
//      lines that erode to nothing; moved, missing or recoloured elements leave
//      solid blobs whose core survives. Catches small text moved a few px that
//      averaging dilutes below the tolerance.
//   3. density pass — 8-logical-px box averages without placement allowance,
//      at 40% of the pixel tolerance. Checks the distribution of colour over
//      whole glyphs instead of matching their pixels against nearby strokes.
//
// A pair passes when block-pass differing blocks <= maxBlocks with largest
// 8-connected group <= maxCluster, AND core-pass surviving pixels <= maxCore
// with largest group <= maxCluster. The density pass uses the block limits.

import { diff, refine, resize } from '../lib/png.mjs';

export const DEFAULTS = {
  block: 2, // logical px per block
  tolerance: 80, // per-channel 0..255
  shift: 1, // placement allowance (blocks in pass 1, logical px in pass 2)
  maxBlocks: 2, // pass 1: differing blocks allowed
  maxCore: 2, // pass 2: surviving logical px allowed
  maxCluster: 3, // both passes: largest 8-connected group allowed
};

export function paramsFromEnv(env) {
  return {
    block: Number(env('PP_VISUAL_BLOCK', String(DEFAULTS.block))),
    tolerance: Number(env('PP_VISUAL_TOLERANCE', String(DEFAULTS.tolerance))),
    shift: Number(env('PP_VISUAL_SHIFT', String(DEFAULTS.shift))),
    maxBlocks: Number(env('PP_VISUAL_MAX_BLOCKS', String(DEFAULTS.maxBlocks))),
    maxCore: Number(env('PP_VISUAL_MAX_CORE', String(DEFAULTS.maxCore))),
    maxCluster: Number(env('PP_VISUAL_MAX_CLUSTER', String(DEFAULTS.maxCluster))),
  };
}

export const scaleRect = (m, k) => ({
  x: Math.floor(m.x / k),
  y: Math.floor(m.y / k),
  w: Math.ceil((m.x + m.w) / k) - Math.floor(m.x / k),
  h: Math.ceil((m.y + m.h) / k) - Math.floor(m.y / k),
});

const RED = [230, 40, 40];
const isRed = (img, x, y) => {
  if (x < 0 || y < 0 || x >= img.width || y >= img.height) return false;
  const o = (y * img.width + x) * 4;
  return img.data[o] === RED[0] && img.data[o + 1] === RED[1] && img.data[o + 2] === RED[2];
};

function grid(img) {
  const { width: w, height: h } = img;
  const g = new Uint8Array(w * h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) g[y * w + x] = isRed(img, x, y) ? 1 : 0;
  return { w, h, g };
}
const at = (m, x, y) => (x < 0 || y < 0 || x >= m.w || y >= m.h ? 0 : m.g[y * m.w + x]);
function morph(m, want) {
  const g = new Uint8Array(m.w * m.h);
  for (let y = 0; y < m.h; y++) {
    for (let x = 0; x < m.w; x++) {
      let all = 1;
      let any = 0;
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          const v = at(m, x + dx, y + dy);
          all &= v;
          any |= v;
        }
      }
      g[y * m.w + x] = want === 'any' ? any : all;
    }
  }
  return { w: m.w, h: m.h, g };
}
const dilate = (m) => morph(m, 'any');
const erode = (m) => morph(m, 'all');

function clusters(m) {
  const seen = new Uint8Array(m.w * m.h);
  let largest = 0;
  let total = 0;
  for (let i = 0; i < m.g.length; i++) {
    if (!m.g[i] || seen[i]) continue;
    let n = 0;
    const stack = [i];
    seen[i] = 1;
    while (stack.length) {
      const j = stack.pop();
      n++;
      const x = j % m.w;
      const y = (j / m.w) | 0;
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          const nx = x + dx;
          const ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= m.w || ny >= m.h) continue;
          const k = ny * m.w + nx;
          if (m.g[k] && !seen[k]) {
            seen[k] = 1;
            stack.push(k);
          }
        }
      }
    }
    total += n;
    if (n > largest) largest = n;
  }
  return { total, largest };
}

/** Heat-map of a logical-pixel diff with the surviving core drawn in red over the faded original. */
function coreImage(fineImg, m) {
  const data = Buffer.from(fineImg.data);
  for (let i = 0; i < m.g.length; i++) {
    const o = i * 4;
    if (m.g[i]) {
      data[o] = RED[0];
      data[o + 1] = RED[1];
      data[o + 2] = RED[2];
    } else if (isRed(fineImg, i % m.w, (i / m.w) | 0)) {
      data[o] = 250;
      data[o + 1] = 200;
      data[o + 2] = 120; // amber: differed but eroded away (thin drift)
    }
  }
  return { width: m.w, height: m.h, data };
}

/**
 * Runs the gate. `ref`/`clone` are same-size physical-pixel images, `dpr` the
 * pixel ratio, `masks` physical-pixel rectangles to ignore.
 */
export function evaluate(ref, clone, dpr, masks, p = DEFAULTS) {
  const k = p.block * dpr;
  const nw = Math.floor(clone.width / k);
  const nh = Math.floor(clone.height / k);
  const refN = resize(ref, nw, nh);
  const cloneN = resize(clone, nw, nh);
  const coarse = diff(refN, cloneN, { tolerance: p.tolerance, shift: p.shift, masks: masks.map((m) => scaleRect(m, k)) });
  const refL = resize(ref, nw * p.block, nh * p.block);
  const cloneL = resize(clone, nw * p.block, nh * p.block);
  const fine = diff(refL, cloneL, { tolerance: p.tolerance, shift: p.shift, masks: masks.map((m) => scaleRect(m, dpr)) });
  const blocks = refine(coarse, fine, p.block);

  const survived = erode(erode(dilate(grid(fine.image))));
  const core = clusters(survived);

  const densityBlock = p.block * 4;
  const densityScale = densityBlock * dpr;
  const densityWidth = Math.floor(clone.width / densityScale);
  const densityHeight = Math.floor(clone.height / densityScale);
  const densityTolerance = p.tolerance * 0.4;
  const density = diff(
    resize(ref, densityWidth, densityHeight),
    resize(clone, densityWidth, densityHeight),
    { tolerance: densityTolerance, shift: 0, masks: masks.map((m) => scaleRect(m, densityScale)) },
  );

  const blocksPass = blocks.differing <= p.maxBlocks && blocks.largestCluster <= p.maxCluster;
  const corePass = core.total <= p.maxCore && core.largest <= p.maxCluster;
  const densityPass = density.differing <= p.maxBlocks && density.largestCluster <= p.maxCluster;
  return {
    pass: blocksPass && corePass && densityPass,
    params: p,
    normalized: { width: nw, height: nh, reference: refN, clone: cloneN },
    blocks: {
      compared: blocks.compared,
      differing: blocks.differing,
      coarseOnly: coarse.differing - blocks.differing,
      largestCluster: blocks.largestCluster,
      pass: blocksPass,
      image: blocks.image,
    },
    core: {
      width: survived.w,
      height: survived.h,
      compared: fine.compared,
      rawDiffering: fine.differing,
      differing: core.total,
      largestCluster: core.largest,
      pass: corePass,
      image: coreImage(fine.image, survived),
    },
    density: {
      block: densityBlock,
      tolerance: densityTolerance,
      compared: density.compared,
      differing: density.differing,
      largestCluster: density.largestCluster,
      pass: densityPass,
      image: density.image,
    },
  };
}

export function describe(r) {
  const p = r.params;
  return (
    `blocks ${r.blocks.differing} <= ${p.maxBlocks} (group ${r.blocks.largestCluster} <= ${p.maxCluster}); ` +
    `core ${r.core.differing} <= ${p.maxCore} (group ${r.core.largestCluster} <= ${p.maxCluster}); ` +
    `density ${r.density.differing} <= ${p.maxBlocks} (group ${r.density.largestCluster} <= ${p.maxCluster})`
  );
}
