import React from "react";
import { Img, staticFile } from "remotion";
import { sans } from "./fonts";
import { Apple } from "./icons";
import { Game } from "./Game";
import { T } from "./timeline";
import { Rect, fadeIn } from "./anim";

export const DESK = { w: 872, h: 654 };
export const PHONE = { x: 334, y: 79, w: 239, h: 494 };
export const SCREEN = { x: 343.5, y: 88.5, w: 220, h: 476 };

export const deskToWin = (d: Rect, x: number, y: number) => {
  const k = d.w / DESK.w;
  return { x: d.x + x * k, y: d.y + y * k };
};

const ToolbarIcon: React.FC<{ d: string }> = ({ d }) => (
  <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="#E8E8E8" strokeWidth="1" strokeLinejoin="round" strokeLinecap="round">
    <path d={d} />
  </svg>
);

export const Simulator: React.FC<{ t: number }> = ({ t }) => {
  const appleA = fadeIn(t, T.boot + 0.15, 0.4);
  const gameA = fadeIn(t, T.titleScreen, 0.35);
  return (
    <>
      <div
        style={{
          position: "absolute",
          left: 330,
          top: 44,
          width: 248,
          height: 28,
          borderRadius: 14,
          background: "#262626",
          boxShadow: "0 0 0 0.6px rgba(255,255,255,0.12) inset, 0 2px 6px rgba(0,0,0,0.25)",
          display: "flex",
          alignItems: "center",
          padding: "0 10px",
          boxSizing: "border-box",
          fontFamily: sans,
        }}
      >
        {["#FF5F57", "#FEBC2E", "#28C840"].map((c) => (
          <div key={c} style={{ width: 7, height: 7, borderRadius: 4, background: c, marginRight: 5 }} />
        ))}
        <div style={{ marginLeft: 12, display: "flex", flexDirection: "column", lineHeight: "8px" }}>
          <span style={{ fontSize: 7.4, color: "#F2F2F2", fontWeight: 600 }}>iPhone 17</span>
          <span style={{ fontSize: 6, color: "#9A9A9A" }}>iOS 26.5</span>
        </div>
        <div style={{ flex: 1 }} />
        <div style={{ display: "flex", gap: 9, alignItems: "center" }}>
          <ToolbarIcon d="M2 5.5 6 2l4 3.5V10H7.3V7.4H4.7V10H2z" />
          <ToolbarIcon d="M1.5 4h2l1-1.5h3L8.5 4h2v6h-9z M6 5.2a1.6 1.6 0 1 0 0 3.2 1.6 1.6 0 0 0 0-3.2" />
          <ToolbarIcon d="M3 2.5h6v7H3z M5 1.5h4.5v6.5" />
        </div>
      </div>
      <div style={{ position: "absolute", left: PHONE.x - 3, top: PHONE.y + 92, width: 3, height: 26, borderRadius: 2, background: "#1A1A1A" }} />
      <div style={{ position: "absolute", left: PHONE.x - 3, top: PHONE.y + 128, width: 3, height: 44, borderRadius: 2, background: "#1A1A1A" }} />
      <div style={{ position: "absolute", left: PHONE.x + PHONE.w, top: PHONE.y + 140, width: 3, height: 60, borderRadius: 2, background: "#1A1A1A" }} />
      <div
        style={{
          position: "absolute",
          left: PHONE.x,
          top: PHONE.y,
          width: PHONE.w,
          height: PHONE.h,
          borderRadius: 42,
          background: "#0B0B0B",
          boxShadow: "0 0 0 1.4px #3A3A3A inset, 0 10px 30px rgba(0,0,0,0.35)",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: SCREEN.x,
          top: SCREEN.y,
          width: SCREEN.w,
          height: SCREEN.h,
          borderRadius: 33,
          overflow: "hidden",
          background: "#000",
        }}
      >
        <div style={{ position: "absolute", left: "50%", top: "50%", transform: "translate(-50%,-56%)", opacity: appleA }}>
          <Apple size={40} color="#FFFFFF" />
        </div>
        <div style={{ position: "absolute", inset: 0, opacity: gameA }}>{gameA > 0 ? <Game t={t} /> : null}</div>
        <div style={{ position: "absolute", left: "50%", top: 9, width: 70, height: 20, marginLeft: -35, borderRadius: 10, background: "#000" }} />
      </div>
    </>
  );
};

export const Desktop: React.FC<{ t: number; rect: Rect; clip: Rect; radius: number }> = ({ t, rect, clip, radius }) => {
  const k = rect.w / DESK.w;
  return (
    <div style={{ position: "absolute", left: clip.x, top: clip.y, width: clip.w, height: clip.h, overflow: "hidden", borderRadius: radius, background: "#0E0E0E" }}>
      <div
        style={{
          position: "absolute",
          left: rect.x - clip.x,
          top: rect.y - clip.y,
          width: DESK.w,
          height: DESK.h,
          transform: `scale(${k})`,
          transformOrigin: "0 0",
        }}
      >
        <Img src={staticFile("desktop.png")} style={{ position: "absolute", inset: 0, width: DESK.w, height: DESK.h }} />
        <Simulator t={t} />
      </div>
    </div>
  );
};
