import { Pointer } from "./glyphs";
import { easeInOutCubic, easeOutCubic, ramp } from "../ease";
import { T } from "../timeline";

import { HOME } from "./Home";
import { TYPE_END } from "./typing";

type Key = { f: number; x: number; y: number };

const L = HOME.colLeft;
const PATH: { from: Key; to: Key }[] = [
  { from: { f: 222, x: 760, y: 560 }, to: { f: 256, x: L + 44, y: HOME.pickerY + 1 } },
  { from: { f: 276, x: L + 44, y: HOME.pickerY + 1 }, to: { f: 308, x: L + 52, y: HOME.pickerY + 7.4 + 24 + 21.7 * 1.5 + 1 } },
  { from: { f: 328, x: L + 52, y: HOME.pickerY + 7.4 + 24 + 21.7 * 1.5 + 1 }, to: { f: 360, x: L + 330, y: HOME.boxTop + 36 } },
  { from: { f: TYPE_END + 4, x: L + 350, y: HOME.boxTop + 60 }, to: { f: T.send - 6, x: L + 637, y: HOME.boxTop + 95 } },
];
const CLICKS = [T.envOpen, T.envPick, 364, T.send];

const along = (k: { from: Key; to: Key }, frame: number) => {
  const t = ramp(frame, k.from.f, k.to.f, easeInOutCubic);
  const dx = k.to.x - k.from.x;
  const dy = k.to.y - k.from.y;
  const cx = (k.from.x + k.to.x) / 2 - dy * 0.14;
  const cy = (k.from.y + k.to.y) / 2 + dx * 0.14;
  const x = (1 - t) ** 2 * k.from.x + 2 * (1 - t) * t * cx + t * t * k.to.x;
  const y = (1 - t) ** 2 * k.from.y + 2 * (1 - t) * t * cy + t * t * k.to.y;
  return { x, y };
};

export const Cursor: React.FC<{ frame: number }> = ({ frame }) => {
  if (frame > T.session + 30) return null;
  let seg = PATH[0];
  for (const p of PATH) if (frame >= p.from.f) seg = p;
  const { x, y } = along(seg, frame);
  const typingHide = frame > T.typeStart - 2 && frame < TYPE_END + 4 ? 0 : 1;
  const opacity =
    ramp(frame, 200, 222, easeOutCubic) * typingHide * (1 - ramp(frame, T.session + 6, T.session + 24, easeOutCubic));
  const press = CLICKS.reduce((acc, c) => acc + ramp(frame, c - 5, c, easeOutCubic) * (1 - ramp(frame, c, c + 8, easeOutCubic)), 0);
  return (
    <Pointer style={{
        position: "absolute",
        left: x - 6,
        top: y - 4,
        width: 28,
        height: 32,
        opacity,
        transform: `scale(${1 - 0.1 * press})`,
        transformOrigin: "6px 4px",
        pointerEvents: "none",
      }}
    />
  );
};
