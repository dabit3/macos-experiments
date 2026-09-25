export const clamp01 = (v: number) => Math.min(1, Math.max(0, v));

export const ease = {
  inOutCubic: (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
  inOutQuint: (t: number) => (t < 0.5 ? 16 * t ** 5 : 1 - Math.pow(-2 * t + 2, 5) / 2),
  outCubic: (t: number) => 1 - Math.pow(1 - t, 3),
  outQuint: (t: number) => 1 - Math.pow(1 - t, 5),
  outBack: (t: number) => {
    const k = 1.4;
    return 1 + (k + 1) * Math.pow(t - 1, 3) + k * Math.pow(t - 1, 2);
  },
};

type Easing = (t: number) => number;

/** Progress 0..1 between two frames with easing. */
export const prog = (f: number, start: number, dur: number, e: Easing = ease.inOutCubic) =>
  e(clamp01((f - start) / dur));

export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

/** Fade in at `start`, optionally fade out at `end`. */
export const fade = (f: number, start: number, dur = 18, end?: number, outDur = 18) => {
  const inn = prog(f, start, dur, ease.outCubic);
  const out = end === undefined ? 1 : 1 - prog(f, end, outDur, ease.inOutCubic);
  return Math.min(inn, out);
};

export type Key = { f: number; [k: string]: number };

/** Piecewise keyframe interpolation, each segment eased in/out. */
export const keys = (f: number, ks: Key[], prop: string, e: Easing = ease.inOutQuint) => {
  if (f <= ks[0].f) return ks[0][prop];
  for (let i = 0; i < ks.length - 1; i++) {
    const a = ks[i];
    const b = ks[i + 1];
    if (f <= b.f) return lerp(a[prop], b[prop], e((f - a.f) / (b.f - a.f)));
  }
  return ks[ks.length - 1][prop];
};

/** Deterministic per-character typing schedule: returns chars shown at frame f. */
export const typedChars = (text: string, f: number, start: number, base = 2.3) => {
  let t = start;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    const jitter = ((Math.sin(i * 12.9898) * 43758.5453) % 1 + 1) % 1;
    let d = base * (0.6 + jitter * 0.8);
    if (ch === " ") d += 0.8;
    if (text[i - 1] === ".") d += 7;
    t += d;
    if (f < t) return i;
  }
  return text.length;
};

export const typingEnd = (text: string, start: number, base = 2.3) => {
  let n = start;
  while (typedChars(text, n, start, base) < text.length) n++;
  return n;
};

export type Pt = { x: number; y: number };

/** Curved cursor move from a to b, with a perpendicular arc. */
export const curve = (a: Pt, b: Pt, t: number, bend = 0.18): Pt => {
  const mx = (a.x + b.x) / 2;
  const my = (a.y + b.y) / 2;
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const cx = mx - dy * bend;
  const cy = my + dx * bend;
  const u = 1 - t;
  return { x: u * u * a.x + 2 * u * t * cx + t * t * b.x, y: u * u * a.y + 2 * u * t * cy + t * t * b.y };
};

export type Move = { f: number; d: number; to: Pt; bend?: number };

export const cursorAt = (f: number, start: Pt, moves: Move[]): Pt => {
  let p = start;
  for (const m of moves) {
    if (f < m.f) return p;
    const t = ease.inOutCubic(clamp01((f - m.f) / m.d));
    if (t < 1) return curve(p, m.to, t, m.bend ?? 0.16);
    p = m.to;
  }
  return p;
};
