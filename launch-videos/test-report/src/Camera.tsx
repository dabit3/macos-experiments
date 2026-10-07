import { interpolate } from "remotion";
import { quint } from "./theme";

export const STAGE_W = 1228.8;
export const STAGE_H = 691.2;
export const PX = 1920 / STAGE_W;

export type CamKey = { f: number; x: number; y: number; s: number };

export const camAt = (frame: number, keys: CamKey[]) => {
  if (frame <= keys[0].f) return keys[0];
  for (let i = 0; i < keys.length - 1; i++) {
    const a = keys[i];
    const b = keys[i + 1];
    if (frame <= b.f) {
      const t = quint(interpolate(frame, [a.f, b.f], [0, 1]));
      const ls = Math.log(a.s) + (Math.log(b.s) - Math.log(a.s)) * t;
      return {
        f: frame,
        x: a.x + (b.x - a.x) * t,
        y: a.y + (b.y - a.y) * t,
        s: Math.exp(ls),
      };
    }
  }
  return keys[keys.length - 1];
};

export const Camera: React.FC<{
  cam: { x: number; y: number; s: number };
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ cam, children, style }) => {
  const s = cam.s * PX;
  const tx = 960 - cam.x * s;
  const ty = 540 - cam.y * s;
  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden", ...style }}>
      <div
        style={{
          position: "absolute",
          left: 0,
          top: 0,
          width: STAGE_W,
          height: STAGE_H,
          transformOrigin: "0 0",
          transform: `translate(${tx}px, ${ty}px) scale(${s})`,
        }}
      >
        {children}
      </div>
    </div>
  );
};
