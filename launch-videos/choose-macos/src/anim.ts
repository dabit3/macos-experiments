import { Easing, interpolate } from "remotion";

export const easeInOut = Easing.bezier(0.83, 0, 0.17, 1); // ease-in-out-quint
export const easeInOutSoft = Easing.bezier(0.65, 0, 0.35, 1); // ease-in-out-cubic
export const easeOut = Easing.bezier(0.22, 1, 0.36, 1); // ease-out-quint

export const clamp01 = (v: number) => Math.max(0, Math.min(1, v));

/** Eased 0..1 progress between two frames. */
export const prog = (frame: number, start: number, end: number, ease: (t: number) => number = easeInOut) =>
  ease(clamp01((frame - start) / (end - start)));

export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

export const fadeIn = (frame: number, start: number, dur = 18) => prog(frame, start, start + dur, easeOut);

export type CamKey = { f: number; x: number; y: number; z: number; ease?: (t: number) => number };

/** Camera keyframes: holds between keys, eases between consecutive keys. Zoom interpolated in log space. */
export const camAt = (frame: number, keys: CamKey[]) => {
  if (frame <= keys[0].f) return keys[0];
  for (let i = 0; i < keys.length - 1; i++) {
    const a = keys[i];
    const b = keys[i + 1];
    if (frame <= b.f) {
      const t = (b.ease ?? easeInOut)(clamp01((frame - a.f) / (b.f - a.f)));
      return { f: frame, x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t), z: Math.exp(lerp(Math.log(a.z), Math.log(b.z), t)) };
    }
  }
  return keys[keys.length - 1];
};

export type CursorKey = { f: number; x: number; y: number; bend?: number };

/** Cursor position along gently curved (quadratic bezier) eased paths between keys. */
export const cursorAt = (frame: number, keys: CursorKey[]) => {
  if (frame <= keys[0].f) return { x: keys[0].x, y: keys[0].y };
  for (let i = 0; i < keys.length - 1; i++) {
    const a = keys[i];
    const b = keys[i + 1];
    if (frame <= b.f) {
      const t = easeInOutSoft(clamp01((frame - a.f) / (b.f - a.f)));
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const bend = b.bend ?? 0.18;
      const cx = (a.x + b.x) / 2 - dy * bend;
      const cy = (a.y + b.y) / 2 + dx * bend;
      const u = 1 - t;
      return { x: u * u * a.x + 2 * u * t * cx + t * t * b.x, y: u * u * a.y + 2 * u * t * cy + t * t * b.y };
    }
  }
  const last = keys[keys.length - 1];
  return { x: last.x, y: last.y };
};

/** Press amount (0..1) for a click at frame `at`. */
export const pressAt = (frame: number, at: number) =>
  interpolate(frame, [at - 5, at, at + 9], [0, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

/** Deterministic, human-feeling typing schedule: returns the frame each character appears. */
export const typingSchedule = (text: string, start: number, seed = 7) => {
  let s = seed;
  const rand = () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
  const times: number[] = [];
  let f = start;
  for (let i = 0; i < text.length; i++) {
    times.push(f);
    const ch = text[i];
    let d = 1.2 + rand() * 1.3;
    if (ch === " ") d += 0.4 + rand() * 1.0;
    if (ch === "." || ch === ",") d += 8 + rand() * 3;
    f += d;
  }
  return { times, end: f };
};

export const typedCount = (frame: number, times: number[]) => {
  let n = 0;
  while (n < times.length && times[n] <= frame) n++;
  return n;
};
