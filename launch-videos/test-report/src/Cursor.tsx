import { interpolate } from "remotion";
import { quint } from "./theme";

export type CursorKey = { f: number; x: number; y: number };

export const cursorAt = (frame: number, keys: CursorKey[]) => {
  if (frame <= keys[0].f) return { x: keys[0].x, y: keys[0].y };
  for (let i = 0; i < keys.length - 1; i++) {
    const a = keys[i];
    const b = keys[i + 1];
    if (frame <= b.f) {
      const t = quint(interpolate(frame, [a.f, b.f], [0, 1]));
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const bend = Math.sin(Math.PI * t) * Math.hypot(dx, dy) * 0.12;
      const len = Math.hypot(dx, dy) || 1;
      return {
        x: a.x + dx * t + (-dy / len) * bend,
        y: a.y + dy * t + (dx / len) * bend,
      };
    }
  }
  const last = keys[keys.length - 1];
  return { x: last.x, y: last.y };
};

export const pressScale = (frame: number, clicks: number[]) => {
  let s = 1;
  for (const c of clicks) {
    const d = frame - c;
    if (d > -5 && d < 9) {
      s = Math.min(
        s,
        interpolate(d, [-5, 0, 9], [1, 0.86, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        }),
      );
    }
  }
  return s;
};

export const Cursor: React.FC<{
  x: number;
  y: number;
  scale?: number;
  size?: number;
  opacity?: number;
}> = ({ x, y, scale = 1, size = 20, opacity = 1 }) => {
  const w = (28 / 20) * size;
  const h = (32 / 20) * size;
  const hx = (6 / 28) * w;
  const hy = (4 / 32) * h;
  return (
    <svg
      viewBox="0 0 28 32"
      style={{
        position: "absolute",
        left: x - hx,
        top: y - hy,
        width: w,
        height: h,
        opacity,
        overflow: "visible",
        transform: `scale(${scale})`,
        transformOrigin: `${hx}px ${hy}px`,
        filter: "drop-shadow(0 1px 1.5px rgba(0,0,0,0.35))",
      }}
    >
      <path
        d="M6 4V21L10.5 16.5L14.5 24L17.5 22.5L13.5 15L20 14L6 4Z"
        fill="white"
        stroke="black"
        strokeWidth="1.2"
        strokeLinejoin="round"
      />
    </svg>
  );
};

export const ClickRing: React.FC<{ x: number; y: number; age: number; size?: number }> = ({
  x,
  y,
  age,
  size = 30,
}) => {
  if (age < 0 || age > 30) return null;
  const t = interpolate(age, [0, 30], [0, 1]);
  const r = size * (0.35 + 0.65 * (1 - Math.pow(1 - t, 3)));
  return (
    <div
      style={{
        position: "absolute",
        left: x - r,
        top: y - r,
        width: r * 2,
        height: r * 2,
        borderRadius: "50%",
        background: `rgba(51,125,244,${0.22 * (1 - t)})`,
        border: `1.2px solid rgba(51,125,244,${0.7 * (1 - t)})`,
      }}
    />
  );
};
