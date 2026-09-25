import React from "react";
import { Img, staticFile } from "remotion";
import { FOOTAGE } from "./theme";

export const FOOTAGE_FRAMES = 690;

const src = (n: number) => staticFile(`footage/${String(Math.max(1, Math.min(FOOTAGE_FRAMES, Math.round(n) + 1))).padStart(4, "0")}.jpg`);

/** Maps a composition frame to a source-footage frame index (30 fps source) via piecewise-linear keys. */
export const remap = (frame: number, keys: [number, number][]) => {
  if (frame <= keys[0][0]) return keys[0][1];
  for (let i = 0; i < keys.length - 1; i++) {
    const [f0, n0] = keys[i];
    const [f1, n1] = keys[i + 1];
    if (frame <= f1) return n0 + ((n1 - n0) * (frame - f0)) / (f1 - f0);
  }
  return keys[keys.length - 1][1];
};

/** A frame of the real cloud-Mac recording, drawn at `scale` with optional crop offset. */
export const FootageFrame: React.FC<{ n: number; scale: number; offsetX?: number; offsetY?: number; style?: React.CSSProperties }> = ({
  n,
  scale,
  offsetX = 0,
  offsetY = 0,
  style,
}) => (
  <Img
    src={src(n)}
    style={{
      position: "absolute",
      left: -offsetX * scale,
      top: -offsetY * scale,
      width: FOOTAGE.w * scale,
      height: FOOTAGE.h * scale,
      maxWidth: "none",
      ...style,
    }}
  />
);
