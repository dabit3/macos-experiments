import type { ReactNode } from "react";
import { Img, staticFile } from "remotion";
import { font } from "./theme";

/** Desktop capture is 872 x 654 px; all geometry below is in that space. */
export const DESK = { w: 872, h: 654 };
export const PHONE = { x: 316, y: 65, w: 239, h: 495 };
export const SCREEN = { x: 323.5, y: 72, w: 224, h: 481 };
export const TITLEBAR = { x: 311, y: 30, w: 250, h: 30 };

const Dot = ({ x }: { x: number }) => <circle cx={x} cy={15} r={3.6} fill="#5A5A5E" />;

const SimChrome = () => (
  <div style={{ position: "absolute", left: TITLEBAR.x, top: TITLEBAR.y, width: TITLEBAR.w, height: TITLEBAR.h, borderRadius: 15, background: "#232325", boxShadow: "0 0 0 0.6px rgba(255,255,255,0.14) inset, 0 6px 18px rgba(0,0,0,0.35)" }}>
    <svg width={TITLEBAR.w} height={TITLEBAR.h} style={{ position: "absolute", inset: 0 }}>
      <Dot x={15} />
      <Dot x={27} />
      <Dot x={39} />
      <g stroke="#9A9AA0" strokeWidth={1} fill="none" strokeLinejoin="round">
        <path d="M188 17.5v-4.5l4-3.4 4 3.4v4.5z" />
        <rect x="209" y="10" width="9" height="7.5" rx="1.5" />
        <circle cx="213.5" cy="13.7" r="1.8" />
        <path d="M232 10.5h4.5v7h-7v-4.5" />
      </g>
    </svg>
    <div style={{ position: "absolute", left: 60, top: 6.5, fontFamily: font.sans, fontSize: 6.6, fontWeight: 600, color: "#C9C9CE", lineHeight: "8px" }}>iPhone 17</div>
    <div style={{ position: "absolute", left: 60, top: 15, fontFamily: font.sans, fontSize: 5.2, color: "#7D7D83", lineHeight: "7px" }}>iOS 27.0</div>
  </div>
);

const Bezel = ({ children }: { children: ReactNode }) => (
  <div style={{ position: "absolute", left: PHONE.x, top: PHONE.y, width: PHONE.w, height: PHONE.h }}>
    {[
      { top: 88, h: 20, left: -2.2 },
      { top: 120, h: 34, left: -2.2 },
      { top: 162, h: 34, left: -2.2 },
      { top: 140, h: 52, left: PHONE.w - 0.6 },
    ].map((b, i) => (
      <div key={i} style={{ position: "absolute", left: b.left, top: b.top, width: 2.8, height: b.h, borderRadius: 2, background: "#2B2B2E" }} />
    ))}
    <div style={{ position: "absolute", inset: 0, borderRadius: 40, background: "#1B1B1D", boxShadow: "0 0 0 1px #3C3C40 inset, 0 0 0 2.2px #111113 inset, 0 12px 30px rgba(0,0,0,0.28)" }} />
    <div style={{ position: "absolute", left: SCREEN.x - PHONE.x, top: SCREEN.y - PHONE.y, width: SCREEN.w, height: SCREEN.h, borderRadius: 33, overflow: "hidden", background: "#000" }}>
      {children}
      <div style={{ position: "absolute", left: SCREEN.w / 2 - 34, top: 9, width: 68, height: 20, borderRadius: 12, background: "#000" }} />
    </div>
  </div>
);

export const AppleBoot = ({ o }: { o: number }) => (
  <div style={{ position: "absolute", inset: 0, background: "#000", display: "flex", alignItems: "center", justifyContent: "center" }}>
    <svg width="44" height="52" viewBox="0 0 24 28" style={{ opacity: o }}>
      <path fill="#FFF" d="M16.37 14.62c-.02-2.35 1.92-3.48 2.01-3.54-1.1-1.6-2.8-1.82-3.4-1.85-1.44-.15-2.82.85-3.55.85-.74 0-1.86-.83-3.06-.81-1.57.02-3.02.92-3.83 2.33-1.64 2.84-.42 7.03 1.17 9.33.78 1.13 1.7 2.39 2.91 2.35 1.17-.05 1.61-.76 3.03-.76 1.41 0 1.81.76 3.05.73 1.26-.02 2.06-1.14 2.82-2.28.9-1.31 1.26-2.59 1.28-2.66-.03-.01-2.45-.94-2.43-3.69zM14.05 7.73c.64-.78 1.08-1.86.96-2.94-.93.04-2.06.62-2.72 1.4-.6.69-1.12 1.8-.98 2.86 1.04.08 2.1-.53 2.74-1.32z" />
    </svg>
  </div>
);

/** macOS desktop with the iOS Simulator window, rendered in desktop px. */
export const Desktop = ({ sim, screen, overlay, dim = 0 }: { sim: number; screen: ReactNode; overlay?: ReactNode; dim?: number }) => (
  <div style={{ position: "absolute", left: 0, top: 0, width: DESK.w, height: DESK.h, overflow: "hidden" }}>
    <Img src={staticFile("macos-desktop.jpg")} style={{ position: "absolute", inset: 0, width: DESK.w, height: DESK.h }} />
    {dim > 0 ? <div style={{ position: "absolute", inset: 0, background: `rgba(249,249,249,${dim})` }} /> : null}
    <div style={{ opacity: sim, transform: `scale(${0.96 + 0.04 * sim})`, transformOrigin: "436px 300px", position: "absolute", inset: 0 }}>
      <SimChrome />
      <Bezel>{screen}</Bezel>
      {overlay}
    </div>
  </div>
);
