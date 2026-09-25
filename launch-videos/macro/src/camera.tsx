import React from "react";
import { AbsoluteFill, Easing, interpolate } from "remotion";
import { BASE, H, W } from "./theme";

export type Cam = { x: number; y: number; z: number };
export type Key = Cam & { f: number; ease?: (t: number) => number };

export const quint = Easing.bezier(0.83, 0, 0.17, 1);
export const cubic = Easing.bezier(0.65, 0, 0.35, 1);
export const outQuint = Easing.bezier(0.22, 1, 0.36, 1);

export const FULL: Cam = { x: W / 2, y: H / 2, z: 1 };

export const track = (f: number, keys: Key[]): Cam => {
  if (f <= keys[0].f) return keys[0];
  for (let i = 1; i < keys.length; i++) {
    const a = keys[i - 1];
    const b = keys[i];
    if (f <= b.f) {
      const e = (b.ease ?? cubic)((f - a.f) / (b.f - a.f));
      const lz = Math.log(a.z) + (Math.log(b.z) - Math.log(a.z)) * e;
      return { x: a.x + (b.x - a.x) * e, y: a.y + (b.y - a.y) * e, z: Math.exp(lz) };
    }
  }
  return keys[keys.length - 1];
};

export const Camera: React.FC<{ cam: Cam; children: React.ReactNode }> = ({ cam, children }) => {
  const blur = interpolate(cam.z, [1.15, 2.5, 6], [0, 2.2, 3.6], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const s = BASE * cam.z;
  return (
    <AbsoluteFill style={{ overflow: "hidden", background: "#F9F9F9" }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: W, height: H, transformOrigin: "0 0", transform: `translate(960px, 540px) scale(${s}) translate(${-cam.x}px, ${-cam.y}px)` }}>{children}</div>
      {blur > 0.05 ? (
        <AbsoluteFill
          style={{
            backdropFilter: `blur(${blur}px)`,
            WebkitBackdropFilter: `blur(${blur}px)`,
            maskImage: "radial-gradient(ellipse 46% 50% at 50% 50%, transparent 38%, black 100%)",
            WebkitMaskImage: "radial-gradient(ellipse 46% 50% at 50% 50%, transparent 38%, black 100%)",
          }}
        />
      ) : null}
    </AbsoluteFill>
  );
};

export const pulse = (f: number, at: number, down = 5, up = 10) =>
  interpolate(f, [at, at + down, at + down + up], [0, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: cubic });

export const bez = (t: number, p0: [number, number], p1: [number, number], p2: [number, number]) => {
  const u = 1 - t;
  return { x: u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0], y: u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1] };
};
