import { Easing, interpolate } from "remotion";

export const easeInOut = Easing.bezier(0.65, 0, 0.35, 1);
export const easeInOutQuint = Easing.bezier(0.83, 0, 0.17, 1);
export const easeOut = Easing.bezier(0.22, 1, 0.36, 1);

export type Key = readonly [number, number];

export const track = (f: number, keys: readonly Key[], ease = easeInOut): number => {
  if (f <= keys[0][0]) return keys[0][1];
  for (let i = 0; i < keys.length - 1; i++) {
    const [f0, v0] = keys[i];
    const [f1, v1] = keys[i + 1];
    if (f <= f1) {
      return interpolate(f, [f0, f1], [v0, v1], { easing: ease, extrapolateLeft: "clamp", extrapolateRight: "clamp" });
    }
  }
  return keys[keys.length - 1][1];
};

export const ramp = (f: number, a: number, b: number, ease = easeOut): number =>
  interpolate(f, [a, b], [0, 1], { easing: ease, extrapolateLeft: "clamp", extrapolateRight: "clamp" });

export type Cam = { x: number; y: number; z: number };

export const camTrack = (f: number, keys: readonly (readonly [number, Cam])[], ease = easeInOut): Cam => ({
  x: track(f, keys.map(([k, c]) => [k, c.x] as const), ease),
  y: track(f, keys.map(([k, c]) => [k, c.y] as const), ease),
  z: Math.exp(track(f, keys.map(([k, c]) => [k, Math.log(c.z)] as const), ease)),
});

export const camStyle = (c: Cam): React.CSSProperties => ({
  position: "absolute",
  left: 0,
  top: 0,
  width: 1280,
  height: 720,
  transformOrigin: "0 0",
  transform: `translate(640px, 360px) scale(${c.z}) translate(${-c.x}px, ${-c.y}px)`,
});

export const typedCount = (f: number, start: number, text: string, cps = 26): number => {
  let t = start;
  for (let i = 0; i < text.length; i++) {
    const seed = Math.sin((i + 1) * 12.9898) * 43758.5453;
    const jitter = seed - Math.floor(seed);
    const ch = text[i];
    const pause = ch === " " ? 1.35 : ch === "." || ch === "," ? 2.4 : 1;
    t += (60 / cps) * (0.7 + jitter * 0.6) * pause;
    if (f < t) return i;
  }
  return text.length;
};

export const typingEnd = (start: number, text: string, cps = 26): number => {
  let t = start;
  for (let i = 0; i < text.length; i++) {
    const seed = Math.sin((i + 1) * 12.9898) * 43758.5453;
    const jitter = seed - Math.floor(seed);
    const ch = text[i];
    const pause = ch === " " ? 1.35 : ch === "." || ch === "," ? 2.4 : 1;
    t += (60 / cps) * (0.7 + jitter * 0.6) * pause;
  }
  return t;
};

export type Waypoint = { f: number; x: number; y: number };

export const cursorAt = (f: number, pts: readonly Waypoint[], bend = 0.18): { x: number; y: number } => {
  if (f <= pts[0].f) return { x: pts[0].x, y: pts[0].y };
  for (let i = 0; i < pts.length - 1; i++) {
    const a = pts[i];
    const b = pts[i + 1];
    if (f <= b.f) {
      const t = easeInOut(Math.min(1, Math.max(0, (f - a.f) / (b.f - a.f))));
      const mx = (a.x + b.x) / 2 - (b.y - a.y) * bend;
      const my = (a.y + b.y) / 2 + (b.x - a.x) * bend;
      const u = 1 - t;
      return { x: u * u * a.x + 2 * u * t * mx + t * t * b.x, y: u * u * a.y + 2 * u * t * my + t * t * b.y };
    }
  }
  const l = pts[pts.length - 1];
  return { x: l.x, y: l.y };
};

export const pressAt = (f: number, clicks: readonly number[]): number => {
  let p = 0;
  for (const c of clicks) {
    const d = f - c;
    if (d >= -4 && d <= 8) p = Math.max(p, d < 0 ? (d + 4) / 4 : 1 - d / 8);
  }
  return p;
};
