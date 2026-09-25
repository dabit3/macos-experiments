import { Easing, interpolate } from "remotion";

export const quint = Easing.bezier(0.83, 0, 0.17, 1);
export const outQuint = Easing.bezier(0.22, 1, 0.36, 1);
export const outCubic = Easing.bezier(0.33, 1, 0.68, 1);
export const inOutCubic = Easing.bezier(0.65, 0, 0.35, 1);

export const ramp = (f: number, a: number, b: number, ease: (t: number) => number = quint) =>
  interpolate(f, [a, b], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: ease });

export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

export type Pt = { x: number; y: number };

export type Move = { t0: number; t1: number; to: Pt; bend?: number };

export const cursorAt = (f: number, start: Pt, moves: Move[]): Pt => {
  let p = start;
  for (const m of moves) {
    if (f <= m.t0) return p;
    const t = ramp(f, m.t0, m.t1, inOutCubic);
    const dx = m.to.x - p.x;
    const dy = m.to.y - p.y;
    const bend = m.bend ?? 0.18;
    const cx = p.x + dx / 2 - dy * bend;
    const cy = p.y + dy / 2 + dx * bend;
    const u = 1 - t;
    const q = { x: u * u * p.x + 2 * u * t * cx + t * t * m.to.x, y: u * u * p.y + 2 * u * t * cy + t * t * m.to.y };
    if (f < m.t1) return q;
    p = m.to;
  }
  return p;
};

export const press = (f: number, clickAt: number) => {
  const d = f - clickAt;
  if (d < -3 || d > 8) return 0;
  return d < 0 ? (d + 3) / 3 : 1 - d / 8;
};
