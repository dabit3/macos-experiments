import { Easing } from "remotion";

export const clamp01 = (v: number) => Math.min(1, Math.max(0, v));
export const mix = (a: number, b: number, p: number) => a + (b - a) * p;

export const easeInOut = Easing.bezier(0.65, 0, 0.35, 1);
export const easeOut = Easing.bezier(0.16, 1, 0.3, 1);
export const easeQuint = Easing.bezier(0.83, 0, 0.17, 1);
export const easeSoft = Easing.bezier(0.45, 0, 0.2, 1);

export const prog = (t: number, start: number, dur: number, ease: (v: number) => number = easeInOut) =>
  ease(clamp01((t - start) / dur));

export const fadeIn = (t: number, start: number, dur = 0.35) => prog(t, start, dur, easeOut);

export const hash = (n: number) => {
  const x = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
};

export type Rect = { x: number; y: number; w: number; h: number };
export const mixRect = (a: Rect, b: Rect, p: number): Rect => ({
  x: mix(a.x, b.x, p),
  y: mix(a.y, b.y, p),
  w: mix(a.w, b.w, p),
  h: mix(a.h, b.h, p),
});
