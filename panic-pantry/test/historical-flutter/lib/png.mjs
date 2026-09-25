// Minimal PNG codec (8-bit grey/RGB/RGBA, non-interlaced) used by the visual
// parity harness so it has no dependency beyond Node's zlib.

import { inflateSync, deflateSync } from 'node:zlib';

const SIG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

let crcTable;
function crc32(buf) {
  if (!crcTable) {
    crcTable = new Int32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      crcTable[n] = c;
    }
  }
  let crc = -1;
  for (let i = 0; i < buf.length; i++) crc = crcTable[(crc ^ buf[i]) & 0xff] ^ (crc >>> 8);
  return (crc ^ -1) >>> 0;
}

/** Decodes a PNG buffer into `{ width, height, data }` with RGBA8 pixels. */
export function decodePng(buf) {
  if (!buf.subarray(0, 8).equals(SIG)) throw new Error('not a PNG');
  let pos = 8;
  let width, height, depth, colorType, interlace;
  const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos);
    const type = buf.toString('latin1', pos + 4, pos + 8);
    const data = buf.subarray(pos + 8, pos + 8 + len);
    pos += 12 + len;
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      depth = data[8];
      colorType = data[9];
      interlace = data[12];
    } else if (type === 'IDAT') idat.push(data);
    else if (type === 'IEND') break;
  }
  if (depth !== 8) throw new Error(`unsupported PNG bit depth ${depth}`);
  if (interlace !== 0) throw new Error('interlaced PNG not supported');
  const channels = { 0: 1, 2: 3, 4: 2, 6: 4 }[colorType];
  if (!channels) throw new Error(`unsupported PNG color type ${colorType}`);
  const raw = inflateSync(Buffer.concat(idat));
  const stride = width * channels;
  const out = Buffer.alloc(width * height * 4);
  let prev = Buffer.alloc(stride);
  let ip = 0;
  for (let y = 0; y < height; y++) {
    const filter = raw[ip++];
    const line = Buffer.from(raw.subarray(ip, ip + stride));
    ip += stride;
    for (let i = 0; i < stride; i++) {
      const a = i >= channels ? line[i - channels] : 0;
      const b = prev[i];
      const c = i >= channels ? prev[i - channels] : 0;
      let v = line[i];
      switch (filter) {
        case 0:
          break;
        case 1:
          v += a;
          break;
        case 2:
          v += b;
          break;
        case 3:
          v += (a + b) >> 1;
          break;
        case 4: {
          const p = a + b - c;
          const pa = Math.abs(p - a);
          const pb = Math.abs(p - b);
          const pc = Math.abs(p - c);
          v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
          break;
        }
        default:
          throw new Error(`bad PNG filter ${filter}`);
      }
      line[i] = v & 0xff;
    }
    for (let x = 0; x < width; x++) {
      const o = (y * width + x) * 4;
      const s = x * channels;
      if (channels === 1) {
        out[o] = out[o + 1] = out[o + 2] = line[s];
        out[o + 3] = 255;
      } else if (channels === 2) {
        out[o] = out[o + 1] = out[o + 2] = line[s];
        out[o + 3] = line[s + 1];
      } else {
        out[o] = line[s];
        out[o + 1] = line[s + 1];
        out[o + 2] = line[s + 2];
        out[o + 3] = channels === 4 ? line[s + 3] : 255;
      }
    }
    prev = line;
  }
  return { width, height, data: out };
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'latin1'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}

/** Encodes RGBA8 pixels as a PNG buffer. */
export function encodePng({ width, height, data }) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  const stride = width * 4;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0;
    data.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
  }
  return Buffer.concat([SIG, chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}

/** Crops an RGBA image to the given rectangle (clamped). */
export function crop(img, x, y, w, h) {
  x = Math.max(0, Math.round(x));
  y = Math.max(0, Math.round(y));
  w = Math.min(Math.round(w), img.width - x);
  h = Math.min(Math.round(h), img.height - y);
  const data = Buffer.alloc(w * h * 4);
  for (let row = 0; row < h; row++) {
    img.data.copy(data, row * w * 4, ((y + row) * img.width + x) * 4, ((y + row) * img.width + x + w) * 4);
  }
  return { width: w, height: h, data };
}

/** Box-filter resample to `w`×`h` (used to bring different pixel ratios together). */
export function resize(img, w, h) {
  if (img.width === w && img.height === h) return img;
  const data = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    const sy0 = Math.floor((y * img.height) / h);
    const sy1 = Math.max(sy0 + 1, Math.floor(((y + 1) * img.height) / h));
    for (let x = 0; x < w; x++) {
      const sx0 = Math.floor((x * img.width) / w);
      const sx1 = Math.max(sx0 + 1, Math.floor(((x + 1) * img.width) / w));
      let r = 0,
        g = 0,
        b = 0,
        a = 0,
        n = 0;
      for (let sy = sy0; sy < sy1; sy++) {
        for (let sx = sx0; sx < sx1; sx++) {
          const o = (sy * img.width + sx) * 4;
          r += img.data[o];
          g += img.data[o + 1];
          b += img.data[o + 2];
          a += img.data[o + 3];
          n++;
        }
      }
      const o = (y * w + x) * 4;
      data[o] = Math.round(r / n);
      data[o + 1] = Math.round(g / n);
      data[o + 2] = Math.round(b / n);
      data[o + 3] = Math.round(a / n);
    }
  }
  return { width: w, height: h, data };
}

/**
 * Per-pixel comparison. Pixels inside any `mask` rect are ignored. A pixel
 * differs when any channel deviates by more than `tolerance`. With `shift` > 0
 * a deviating pixel is still accepted when a pixel within `shift` px in the
 * other image matches it (in both directions), which tolerates sub-pixel glyph
 * placement between rasterizers but not moved or missing content. Returns the
 * ratio of differing pixels, the size of the largest connected group of
 * differing pixels (real defects are contiguous; rasterizer noise is scattered)
 * and a heat-map image (red = differs, grey = masked).
 */
export function diff(a, b, { tolerance = 24, masks = [], shift = 0 } = {}) {
  if (a.width !== b.width || a.height !== b.height) {
    throw new Error(`size mismatch ${a.width}x${a.height} vs ${b.width}x${b.height}`);
  }
  const { width, height } = a;
  const out = Buffer.alloc(width * height * 4);
  let differing = 0;
  let compared = 0;
  const close = (p, q, i, j) =>
    Math.abs(p.data[i] - q.data[j]) <= tolerance &&
    Math.abs(p.data[i + 1] - q.data[j + 1]) <= tolerance &&
    Math.abs(p.data[i + 2] - q.data[j + 2]) <= tolerance;
  const nearMatch = (p, q, x, y, o) => {
    for (let dy = -shift; dy <= shift; dy++) {
      for (let dx = -shift; dx <= shift; dx++) {
        const nx = x + dx;
        const ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        if (close(p, q, o, (ny * width + nx) * 4)) return true;
      }
    }
    return false;
  };
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const o = (y * width + x) * 4;
      const masked = masks.some((m) => x >= m.x && x < m.x + m.w && y >= m.y && y < m.y + m.h);
      const grey = Math.round(0.3 * a.data[o] + 0.59 * a.data[o + 1] + 0.11 * a.data[o + 2]);
      const faded = 160 + (grey >> 2);
      if (masked) {
        out[o] = out[o + 1] = 190;
        out[o + 2] = 210;
        out[o + 3] = 255;
        continue;
      }
      compared++;
      const d = Math.max(
        Math.abs(a.data[o] - b.data[o]),
        Math.abs(a.data[o + 1] - b.data[o + 1]),
        Math.abs(a.data[o + 2] - b.data[o + 2]),
      );
      if (d > tolerance && !(shift > 0 && nearMatch(a, b, x, y, o) && nearMatch(b, a, x, y, o))) {
        differing++;
        out[o] = 230;
        out[o + 1] = 40;
        out[o + 2] = 40;
      } else {
        out[o] = out[o + 1] = out[o + 2] = faded;
      }
      out[o + 3] = 255;
    }
  }
  return {
    differing,
    compared,
    ratio: compared ? differing / compared : 0,
    largestCluster: largestCluster(out, width, height),
    image: { width, height, data: out },
  };
}

/**
 * Intersects a coarse (box-averaged) diff with a fine (full-resolution) diff:
 * a coarse block stays "differing" only when at least one fine pixel inside it
 * differs too. Stroke-weight noise fails only the fine pass, 1-px edge snapping
 * fails only the coarse pass; moved, missing or recoloured content fails both.
 * `k` is the fine pixels per coarse block. Returns the same shape as `diff`.
 */
export function refine(coarse, fine, k) {
  const { width, height } = coarse.image;
  const out = Buffer.from(coarse.image.data);
  let differing = 0;
  const fineDiffers = (x, y) => {
    const o = (y * fine.image.width + x) * 4;
    return fine.image.data[o] === 230 && fine.image.data[o + 1] === 40 && fine.image.data[o + 2] === 40;
  };
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const o = (y * width + x) * 4;
      if (!(out[o] === 230 && out[o + 1] === 40 && out[o + 2] === 40)) continue;
      let confirmed = false;
      for (let fy = y * k; fy < Math.min((y + 1) * k, fine.image.height) && !confirmed; fy++) {
        for (let fx = x * k; fx < Math.min((x + 1) * k, fine.image.width); fx++) {
          if (fineDiffers(fx, fy)) {
            confirmed = true;
            break;
          }
        }
      }
      if (confirmed) {
        differing++;
      } else {
        out[o] = 250;
        out[o + 1] = 200;
        out[o + 2] = 120; // amber: differed only after averaging (edge snapping)
      }
    }
  }
  return {
    differing,
    compared: coarse.compared,
    ratio: coarse.compared ? differing / coarse.compared : 0,
    largestCluster: largestCluster(out, width, height),
    image: { width, height, data: out },
  };
}

/** Size of the largest 8-connected group of differing (red) pixels in a heat-map. */
function largestCluster(data, width, height) {
  const isDiff = (x, y) => {
    const o = (y * width + x) * 4;
    return data[o] === 230 && data[o + 1] === 40 && data[o + 2] === 40;
  };
  const seen = new Uint8Array(width * height);
  let best = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (seen[y * width + x] || !isDiff(x, y)) continue;
      const stack = [[x, y]];
      seen[y * width + x] = 1;
      let size = 0;
      while (stack.length) {
        const [cx, cy] = stack.pop();
        size++;
        for (let dy = -1; dy <= 1; dy++) {
          for (let dx = -1; dx <= 1; dx++) {
            const nx = cx + dx;
            const ny = cy + dy;
            if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
            const i = ny * width + nx;
            if (seen[i] || !isDiff(nx, ny)) continue;
            seen[i] = 1;
            stack.push([nx, ny]);
          }
        }
      }
      if (size > best) best = size;
    }
  }
  return best;
}
