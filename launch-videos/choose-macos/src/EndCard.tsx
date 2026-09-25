import React from "react";
import { Img, staticFile } from "remotion";
import { C, FONT } from "./theme";
import { easeOut, prog } from "./anim";

/** Final lockup card, laid out in output pixels (1920x1080). */
export const EndCard: React.FC<{ frame: number; start: number }> = ({ frame, start }) => {
  const logo = prog(frame, start, start + 50, easeOut);
  const line = prog(frame, start + 22, start + 72, easeOut);
  return (
    <div style={{ position: "absolute", inset: 0, background: C.bg, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", fontFamily: FONT }}>
      <Img
        src={staticFile("lockup.png")}
        style={{ width: 640, height: (640 * 1024) / 2984, opacity: logo, transform: `translateY(${(1 - logo) * 14}px) scale(${0.985 + 0.015 * logo})` }}
      />
      <div style={{ marginTop: 18, fontSize: 34, lineHeight: "44px", letterSpacing: -0.5, color: "rgba(25,25,25,0.56)", opacity: line, transform: `translateY(${(1 - line) * 10}px)` }}>
        Now on macOS
      </div>
    </div>
  );
};
