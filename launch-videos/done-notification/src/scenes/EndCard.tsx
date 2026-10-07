import { Img, staticFile, useCurrentFrame } from "remotion";
import { ramp } from "../anim";
import { inter } from "../fonts";
import { F } from "../timeline";
import { C } from "../tokens";

export const EndCard: React.FC = () => {
  const f = useCurrentFrame();
  const a = ramp(f, F.endStart + 20, F.endStart + 70);
  const b = ramp(f, F.endStart + 48, F.endStart + 96);
  const w = 300;
  return (
    <div style={{ position: "absolute", inset: 0, width: 1280, height: 720, background: C.bg, fontFamily: inter }}>
      <Img
        src={staticFile("brand/devin-lockup-black.png")}
        style={{
          position: "absolute",
          width: w,
          height: (w * 1024) / 2984,
          left: 640 - w / 2,
          top: 322 - (w * 1024) / 2984 / 2,
          opacity: a,
          transform: `translateY(${(1 - a) * 8}px) scale(${0.985 + a * 0.015})`,
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 0,
          width: 1280,
          top: 392,
          textAlign: "center",
          fontSize: 19,
          lineHeight: "26px",
          letterSpacing: -0.2,
          color: C.muted,
          opacity: b,
          transform: `translateY(${(1 - b) * 6}px)`,
        }}
      >
        Devin, now on macOS
      </div>
    </div>
  );
};
