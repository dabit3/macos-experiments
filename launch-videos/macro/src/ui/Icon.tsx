import React from "react";
import { Img, staticFile } from "remotion";

export const Icon: React.FC<{ n: string; s: number; h?: number; style?: React.CSSProperties }> = ({ n, s, h, style }) => (
  <Img src={staticFile(`svg/${n}.svg`)} style={{ width: s, height: h ?? s, display: "block", flexShrink: 0, ...style }} />
);

export const Btn: React.FC<{ size?: number; radius?: number; children: React.ReactNode; style?: React.CSSProperties }> = ({ size = 28, radius = 9999, children, style }) => (
  <div style={{ width: size, height: size, borderRadius: radius, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0, ...style }}>{children}</div>
);

export const DevinMark: React.FC<{ phase?: number }> = ({ phase = 0 }) => {
  const o = (k: number) => 0.35 + 0.65 * (0.5 + 0.5 * Math.cos(phase - k * 2.1));
  return (
    <div style={{ width: 17, height: 17, position: "relative", overflow: "hidden", flexShrink: 0 }}>
      <Icon n="star_36693" s={17} style={{ position: "absolute", left: 8.9, top: 5, opacity: o(0) }} />
      <Icon n="star_77232" s={17} style={{ position: "absolute", left: 1.96, top: 0.99, opacity: o(1) }} />
      <Icon n="star_d6448" s={16.491} style={{ position: "absolute", left: 2.05, top: 9.11, opacity: o(2) }} />
    </div>
  );
};

export const Cursor: React.FC<{ x: number; y: number; press?: number; opacity?: number }> = ({ x, y, press = 0, opacity = 1 }) => (
  <div style={{ position: "absolute", left: x, top: y, width: 12, height: 19, transform: `scale(${1 - 0.1 * press})`, transformOrigin: "1px 1px", opacity, pointerEvents: "none" }}>
    <Icon n="cursor_ec11e" s={12} h={19} />
  </div>
);

export const UbuntuIcon: React.FC = () => (
  <svg width={14} height={14} viewBox="0 0 14 14" style={{ display: "block", flexShrink: 0 }}>
    <circle cx={7} cy={7} r={4.2} fill="none" stroke="#E95420" strokeWidth={1.6} />
    {[180, 60, -60].map((a) => {
      const r = (a * Math.PI) / 180;
      return <circle key={a} cx={7 + 5.2 * Math.cos(r)} cy={7 - 5.2 * Math.sin(r)} r={1.45} fill="#E95420" stroke="#fff" strokeWidth={0.9} />;
    })}
  </svg>
);

export const WindowsIcon: React.FC = () => (
  <svg width={14} height={14} viewBox="0 0 14 14" style={{ display: "block", flexShrink: 0 }}>
    <rect x={0.5} y={0.5} width={6.2} height={6.2} fill="#F25022" />
    <rect x={7.3} y={0.5} width={6.2} height={6.2} fill="#7FBA00" />
    <rect x={0.5} y={7.3} width={6.2} height={6.2} fill="#00A4EF" />
    <rect x={7.3} y={7.3} width={6.2} height={6.2} fill="#FFB900" />
  </svg>
);

export const ProgressIcon: React.FC = () => (
  <svg width={16} height={16} viewBox="0 0 16 16" fill="none" style={{ display: "block" }}>
    <path d="M9.5 1.75H4.25C3.56 1.75 3 2.31 3 3v10c0 .69.56 1.25 1.25 1.25H6.5M9.5 1.75 13 5.25M9.5 1.75v3.5H13m0 0v1.5" stroke="#191919" strokeOpacity={0.9} strokeWidth={1.1} strokeLinecap="round" strokeLinejoin="round" />
    <circle cx={10.5} cy={10.75} r={2.25} stroke="#191919" strokeOpacity={0.9} strokeWidth={1.1} />
    <path d="m12.2 12.45 1.55 1.55" stroke="#191919" strokeOpacity={0.9} strokeWidth={1.1} strokeLinecap="round" />
  </svg>
);

export const DrawCheck: React.FC<{ p: number; bg: string; size?: number }> = ({ p, bg, size = 14 }) => {
  const len = 7;
  const c = Math.min(1, p * 2.2);
  const k = Math.max(0, Math.min(1, (p - 0.3) / 0.7));
  return (
    <svg width={size} height={size} viewBox="0 0 14 14" style={{ display: "block", flexShrink: 0 }}>
      <circle cx={7} cy={7} r={5.833} fill="#00A558" opacity={c} transform={`rotate(0 7 7)`} style={{ transformOrigin: "7px 7px", transform: `scale(${0.6 + 0.4 * c})` }} />
      <path d="M4.96 7.58 6.13 8.75 8.75 5.54" fill="none" stroke={bg} strokeWidth={0.9} strokeLinecap="round" strokeLinejoin="round" strokeDasharray={len} strokeDashoffset={len * (1 - k)} />
    </svg>
  );
};
