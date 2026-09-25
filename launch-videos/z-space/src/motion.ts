import { Easing, interpolate, spring } from "remotion";

export const FPS = 60;

export type Pose = { x: number; y: number; z: number; rx: number; ry: number; rz: number; s: number; o: number };

export const REST: Pose = { x: 0, y: 0, z: 0, rx: 0, ry: 0, rz: 0, s: 1, o: 1 };

export const pose = (p: Partial<Pose>): Pose => ({ ...REST, ...p });

export const mix = (a: Pose, b: Pose, t: number): Pose => ({
  x: a.x + (b.x - a.x) * t,
  y: a.y + (b.y - a.y) * t,
  z: a.z + (b.z - a.z) * t,
  rx: a.rx + (b.rx - a.rx) * t,
  ry: a.ry + (b.ry - a.ry) * t,
  rz: a.rz + (b.rz - a.rz) * t,
  s: a.s + (b.s - a.s) * t,
  o: a.o + (b.o - a.o) * t,
});

export const clamp01 = (v: number) => Math.min(1, Math.max(0, v));

export const settle = (frame: number, start: number, cfg?: { damping?: number; stiffness?: number; mass?: number }) =>
  spring({
    frame: frame - start,
    fps: FPS,
    config: { damping: cfg?.damping ?? 20, stiffness: cfg?.stiffness ?? 70, mass: cfg?.mass ?? 1 },
  });

export const quint = Easing.bezier(0.83, 0, 0.17, 1);
export const outQuint = Easing.bezier(0.22, 1, 0.36, 1);
export const inCubic = Easing.bezier(0.55, 0, 1, 0.45);

export const ramp = (frame: number, a: number, b: number, ease: (t: number) => number = quint) =>
  interpolate(frame, [a, b], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: ease });

export const transform = (p: Pose) =>
  `translate3d(${p.x}px, ${p.y}px, ${p.z}px) rotateX(${p.rx}deg) rotateY(${p.ry}deg) rotateZ(${p.rz}deg) scale(${p.s})`;

export const typed = (text: string, frame: number, start: number, seed = 7) => {
  let t = start;
  let n = 0;
  for (let i = 0; i < text.length; i++) {
    const r = Math.abs(Math.sin((i + 1) * 12.9898 * seed) * 43758.5453) % 1;
    const ch = text[i];
    let d = 2.1 + r * 1.6;
    if (ch === " ") d += 0.6;
    if (ch === "." || ch === ",") d += 4;
    if (text[i - 1] === ".") d += 3;
    t += d;
    if (frame >= t) n = i + 1;
  }
  return text.slice(0, n);
};

export const typedEnd = (text: string, start: number, seed = 7) => {
  let t = start;
  for (let i = 0; i < text.length; i++) {
    const r = Math.abs(Math.sin((i + 1) * 12.9898 * seed) * 43758.5453) % 1;
    const ch = text[i];
    let d = 2.1 + r * 1.6;
    if (ch === " ") d += 0.6;
    if (ch === "." || ch === ",") d += 4;
    if (text[i - 1] === ".") d += 3;
    t += d;
  }
  return t;
};
