import React from "react";
import { C } from "./tokens";
import { sans } from "./fonts";
import { Apple, Check, Chevron, DevinMark, Star, Ubuntu, Windows } from "./icons";
import { T } from "./timeline";
import { easeOut, fadeIn, prog } from "./anim";

export const HOME = {
  box: { x: 257.7, y: 285.2, w: 688.6, h: 120.2 },
  envY: 430.3,
  envX: 273.7,
  drop: { x: 267, y: 440.5, w: 221 },
};

const Toggle: React.FC = () => (
  <div
    style={{
      position: "absolute",
      left: 829,
      top: 241,
      width: 111,
      height: 27,
      borderRadius: 999,
      background: C.fill,
      display: "flex",
      alignItems: "center",
      padding: 2,
      boxSizing: "border-box",
      fontFamily: sans,
      fontSize: 13,
      letterSpacing: "-0.065px",
    }}
  >
    <div
      style={{
        height: 23,
        width: 61,
        borderRadius: 999,
        background: C.white,
        boxShadow: "0 0 0 0.8px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.06)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        color: C.ink,
      }}
    >
      Agent
    </div>
    <div style={{ flex: 1, textAlign: "center", color: C.muted }}>Ask</div>
  </div>
);

const Row: React.FC<{ icon: React.ReactNode; label: string; star?: "filled" | "outline"; selected?: boolean; hover?: number; badge?: boolean }> = ({
  icon,
  label,
  star,
  selected,
  hover = 0,
  badge,
}) => (
  <div
    style={{
      height: 30.3,
      borderRadius: 6,
      display: "flex",
      alignItems: "center",
      padding: "0 8px 0 9px",
      gap: 9,
      background: `rgba(0,0,0,${0.055 * Math.max(selected ? 1 : 0, hover)})`,
      fontSize: 13.5,
      color: C.ink,
    }}
  >
    <div style={{ width: 14, display: "flex", justifyContent: "center" }}>{icon}</div>
    <span>{label}</span>
    {badge ? (
      <span
        style={{
          fontSize: 10.5,
          lineHeight: "15px",
          padding: "0 5px",
          borderRadius: 4,
          background: C.badgeBg,
          color: C.badgeInk,
          fontWeight: 500,
        }}
      >
        New
      </span>
    ) : null}
    {star ? <Star size={13} filled={star === "filled"} color="rgba(25,25,25,0.5)" /> : null}
    <div style={{ flex: 1 }} />
    {selected ? <Check size={14} color={C.ink} stroke={1.4} /> : null}
  </div>
);

export const HomeChrome: React.FC<{ t: number }> = ({ t }) => {
  const out = prog(t, T.toSession, 0.45, easeOut);
  const macos = t >= T.macClick;
  const openP = fadeIn(t, T.envClick + 0.04, 0.2) * (1 - fadeIn(t, T.dropClose, 0.16));
  const hoverMac = prog(t, T.macClick - 0.32, 0.12);
  return (
    <div style={{ position: "absolute", inset: 0, opacity: 1 - out, transform: `translateY(${-10 * out}px)`, fontFamily: sans }}>
      <div style={{ position: "absolute", left: 266.4, top: 243.4, display: "flex", alignItems: "center", gap: 7 }}>
        <DevinMark size={22.4} />
        <span style={{ fontSize: 26, fontWeight: 500, letterSpacing: "-0.03em", color: "#0A0A0A", lineHeight: "24px" }}>Devin</span>
      </div>
      <Toggle />
      <div
        style={{
          position: "absolute",
          left: HOME.envX - 1,
          top: HOME.envY - 9,
          height: 18,
          display: "flex",
          alignItems: "center",
          gap: 6,
          fontSize: 13,
          color: C.ink,
          letterSpacing: "-0.065px",
        }}
      >
        {macos ? <Apple size={13} /> : <Ubuntu size={13} />}
        <span>{macos ? "macOS" : "Ubuntu"}</span>
        <Chevron size={13} color={C.muted} stroke={1.4} />
      </div>
      {openP > 0 ? (
        <div
          style={{
            position: "absolute",
            left: HOME.drop.x,
            top: HOME.drop.y,
            width: HOME.drop.w,
            padding: 4,
            boxSizing: "border-box",
            borderRadius: 10,
            background: C.white,
            boxShadow: "0 0 0 0.8px rgba(0,0,0,0.08), 0 8px 24px rgba(0,0,0,0.08)",
            opacity: openP,
            transform: `translateY(${(1 - openP) * -4}px) scale(${0.98 + 0.02 * openP})`,
            transformOrigin: "top left",
          }}
        >
          <div style={{ height: 26, display: "flex", alignItems: "center", paddingLeft: 9, fontSize: 12, color: C.muted }}>Hosted</div>
          <Row icon={<Ubuntu size={13} />} label="Ubuntu" star="filled" selected={!macos} />
          <Row icon={<Apple size={13} />} label="macOS" badge star="outline" selected={macos} hover={hoverMac} />
          <Row icon={<Windows size={12} />} label="Windows" />
        </div>
      ) : null}
    </div>
  );
};
