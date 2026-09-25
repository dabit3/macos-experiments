import {Easing, interpolate} from 'remotion';
import {FPS} from './theme';

export const f = (seconds: number) => Math.round(seconds * FPS);

export const quint = Easing.bezier(0.83, 0, 0.17, 1);
export const expoOut = Easing.bezier(0.16, 1, 0.3, 1);
export const cubic = Easing.bezier(0.65, 0, 0.35, 1);
export const softOut = Easing.bezier(0.22, 1, 0.36, 1);

/** Eased 0..1 progress between two times (seconds) for the current frame. */
export const prog = (
  frame: number,
  start: number,
  end: number,
  easing: (t: number) => number = cubic,
) =>
  interpolate(frame, [f(start), f(end)], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing,
  });

export const mix = (a: number, b: number, t: number) => a + (b - a) * t;

/** Deterministic pseudo-random in [0,1). */
export const rand = (seed: number) => {
  const x = Math.sin(seed * 12.9898 + 78.233) * 43758.5453;
  return x - Math.floor(x);
};

/** Frame offsets (relative to start) at which each character of `text` appears. */
export const typingSchedule = (text: string, cps = 26) => {
  const times: number[] = [];
  let t = 0;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    const base = 1 / cps;
    let d = base * (0.6 + rand(i + 3) * 0.9);
    if (ch === ' ') d *= 1.25;
    if (i > 0 && '.,'.includes(text[i - 1])) d += 0.16;
    t += d;
    times.push(t);
  }
  return times;
};

export const typedCount = (frame: number, startSec: number, times: number[]) => {
  const t = frame / FPS - startSec;
  let n = 0;
  while (n < times.length && times[n] <= t) n++;
  return n;
};
