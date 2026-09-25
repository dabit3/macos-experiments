import React from "react";
import { C, INTER } from "../theme";
import { Icon, AppleLogo, UbuntuLogo, WindowsLogo, Star, Tick } from "../icons";
import { Btn, Caret, DevinMark, Text } from "./common";

export const HOME = {
  logo: { x: 262, y: 237, w: 100, h: 36 },
  toggle: { x: 828.6, y: 240.5, w: 111.2, h: 28 },
  card: { x: 257.8, y: 284.4, w: 688.2, h: 120.8 },
  controls: { x: 269.8, y: 365.2, w: 664.4, h: 28 },
  env: { x: 264, y: 417.6, w: 120, h: 24 },
  menu: { x: 267, y: 439.6, w: 221.4, h: 125 },
};

export const HomeBase: React.FC = () => (
  <div style={{ position: "absolute", inset: 0, background: C.page }}>
    <div style={{ position: "absolute", left: 11.3, top: 7.5 }}>
      <Btn icon="sidebar" radius={6} />
    </div>
  </div>
);

export const HomeLogo: React.FC = () => (
  <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", gap: 0 }}>
    <DevinMark size={30} style={{ marginLeft: -0.2, marginRight: -0.2 }} />
    <Text size={23.1} lh={30} weight={600} track={-0.5}>
      Devin
    </Text>
  </div>
);

export const HomeToggle: React.FC = () => (
  <div
    style={{
      position: "absolute",
      inset: 0,
      borderRadius: 9999,
      background: "rgba(0,0,0,0.035)",
      display: "flex",
      alignItems: "center",
      padding: 1.5,
    }}
  >
    <div
      style={{
        height: 25,
        width: 60,
        borderRadius: 9999,
        background: "#FDFDFD",
        boxShadow: "0 0 0 0.8px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.04)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <Text size={13} lh={18}>Agent</Text>
    </div>
    <div style={{ flex: 1, display: "flex", justifyContent: "center" }}>
      <Text size={13} lh={18} color={C.muted}>
        Ask
      </Text>
    </div>
  </div>
);

const PLACEHOLDER = "Ask Devin to build features, fix bugs, or work on your code";

export const HomeCard: React.FC<{ text: string; focused: boolean; frame: number }> = ({ text, focused, frame }) => (
  <div
    style={{
      position: "absolute",
      inset: 0,
      borderRadius: 20,
      background: C.card,
      boxShadow: "inset 0 0 0 0.8px rgba(0,0,0,0.13)",
    }}
  >
    <div style={{ position: "absolute", left: 16.9, top: 17, right: 16, fontFamily: INTER, fontSize: 14, lineHeight: "20px", letterSpacing: -0.06 }}>
      {text.length === 0 ? (
        <span style={{ color: "rgba(25,25,25,0.58)" }}>
          {focused ? <Caret frame={frame} h={18} /> : null}
          {PLACEHOLDER}
        </span>
      ) : (
        <span style={{ color: C.text }}>
          {text}
          <Caret frame={frame} h={18} />
        </span>
      )}
    </div>
  </div>
);

export const HomeControls: React.FC<{ active: boolean; pressed: number }> = ({ active, pressed }) => (
  <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center" }}>
    <Btn icon="plus" />
    <div style={{ width: 1 }} />
    <Btn icon="slash" />
    <div style={{ width: 1 }} />
    <div style={{ position: "relative" }}>
      <Btn icon="sliders" />
      <div style={{ position: "absolute", left: 19, top: 3, width: 6, height: 6, borderRadius: 9999, background: "#317CFF" }} />
    </div>
    <div style={{ width: 12 }} />
    <Text size={13} lh={18} color={C.muted}>
      Fusion
    </Text>
    <div style={{ flex: 1 }} />
    <Btn icon="mic" />
    <Btn icon="voice" />
    <div style={{ width: 4 }} />
    <div
      style={{
        height: 27,
        width: 54,
        borderRadius: 9999,
        background: active ? "#1F1F1F" : "#818181",
        display: "flex",
        alignItems: "center",
        transform: `scale(${1 - 0.06 * pressed})`,
      }}
    >
      <div style={{ width: 28, display: "flex", justifyContent: "center" }}>
        <Icon name="send" size={18} />
      </div>
      <div style={{ width: 0.8, height: 27, background: "rgba(255,255,255,0.14)" }} />
      <div style={{ flex: 1, display: "flex", justifyContent: "center", paddingRight: 2 }}>
        <Icon name="chevron-down" size={16} />
      </div>
    </div>
  </div>
);

export const EnvPicker: React.FC<{ mac: boolean }> = ({ mac }) => (
  <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", gap: 5.5, paddingLeft: 3.5 }}>
    {mac ? <AppleLogo size={14} /> : <UbuntuLogo size={14} />}
    <Text size={14.2} lh={18}>{mac ? "macOS" : "Ubuntu"}</Text>
    <svg width={14} height={14} viewBox="0 0 16 16" style={{ marginLeft: -1 }}>
      <path d="M4 6l4 4 4-4" fill="none" stroke="rgba(25,25,25,0.75)" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  </div>
);

const Row: React.FC<{ y: number; hover: number; icon: React.ReactNode; label: string; star?: "filled" | "outline"; badge?: boolean; checked?: boolean }> = ({
  y,
  hover,
  icon,
  label,
  star,
  badge,
  checked,
}) => (
  <div
    style={{
      position: "absolute",
      left: 4.6,
      right: 4.6,
      top: y,
      height: 30,
      borderRadius: 8,
      background: `rgba(0,0,0,${0.055 * hover})`,
      display: "flex",
      alignItems: "center",
      paddingLeft: 11.6,
      gap: 6,
    }}
  >
    <div style={{ width: 16, display: "flex", justifyContent: "center" }}>{icon}</div>
    <Text size={14.2} lh={18}>{label}</Text>
    {star ? <Star size={15} filled={star === "filled"} style={{ marginLeft: 3 }} /> : null}
    {badge ? (
      <div
        style={{
          marginLeft: 2,
          height: 18,
          padding: "0 6px",
          borderRadius: 5,
          background: C.badgeBg,
          display: "flex",
          alignItems: "center",
        }}
      >
        <Text size={11} lh={14} weight={500} color="#2563EB" track={0}>
          New
        </Text>
      </div>
    ) : null}
    <div style={{ flex: 1 }} />
    {checked ? <Tick size={16} style={{ marginRight: 10 }} /> : null}
  </div>
);

export const EnvMenu: React.FC<{ hoverMac: number; mac: boolean }> = ({ hoverMac, mac }) => (
  <div
    style={{
      position: "absolute",
      inset: 0,
      borderRadius: 12,
      background: C.card,
      boxShadow: "0 0 0 0.8px rgba(0,0,0,0.09), 0 4px 12px rgba(0,0,0,0.05), 0 12px 24px rgba(0,0,0,0.035)",
    }}
  >
    <div style={{ position: "absolute", left: 12.3, top: 8.8 }}>
      <Text size={12.4} lh={18} color={C.muted}>
        Hosted
      </Text>
    </div>
    <Row y={30.3} hover={0} icon={<UbuntuLogo size={15} />} label="Ubuntu" star="filled" checked={!mac} />
    <Row y={60.2} hover={hoverMac} icon={<AppleLogo size={15} />} label="macOS" badge checked={mac} />
    <Row y={90.1} hover={0} icon={<WindowsLogo size={14} />} label="Windows" star="outline" />
  </div>
);
