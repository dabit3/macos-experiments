import { interpolate } from "remotion";

export const easeInOutCubic = (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
export const easeInOutQuint = (t: number) => (t < 0.5 ? 16 * t ** 5 : 1 - Math.pow(-2 * t + 2, 5) / 2);
export const easeOutCubic = (t: number) => 1 - Math.pow(1 - t, 3);
export const easeOutQuint = (t: number) => 1 - Math.pow(1 - t, 5);
export const easeInOutSine = (t: number) => -(Math.cos(Math.PI * t) - 1) / 2;

export const ramp = (frame: number, from: number, to: number, ease: (t: number) => number = easeInOutCubic) =>
  ease(interpolate(frame, [from, to], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }));

export const mix = (a: number, b: number, t: number) => a + (b - a) * t;
