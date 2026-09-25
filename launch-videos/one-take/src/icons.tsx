import React from "react";
import { Img, staticFile } from "remotion";

export const FIcon: React.FC<{ name: string; size: number; style?: React.CSSProperties }> = ({ name, size, style }) => (
  <Img src={staticFile(`icons/${name}.svg`)} style={{ width: size, height: size, display: "block", ...style }} />
);

type P = { size?: number; color?: string; stroke?: number; style?: React.CSSProperties };

const S: React.FC<P & { children: React.ReactNode; vb?: number }> = ({ size = 18, color = "rgba(25,25,25,0.56)", stroke = 1.35, style, children, vb = 18 }) => (
  <svg width={size} height={size} viewBox={`0 0 ${vb} ${vb}`} fill="none" stroke={color} strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" style={{ display: "block", ...style }}>
    {children}
  </svg>
);

export const ArrowUp: React.FC<P> = (p) => (
  <S {...p}>
    <path d="M9 14.25V3.75M4.5 8.25 9 3.75l4.5 4.5" />
  </S>
);
export const Chevron: React.FC<P & { dir?: "down" | "right" }> = ({ dir = "down", ...p }) => (
  <S {...p}>{dir === "down" ? <path d="m5.25 7.125 3.75 3.75 3.75-3.75" /> : <path d="m7.125 5.25 3.75 3.75-3.75 3.75" />}</S>
);
export const Sliders: React.FC<P> = (p) => (
  <S {...p}>
    <circle cx="5.25" cy="5.25" r="1.9" />
    <path d="M5.25 7.15v8.1M12.75 2.75v8.1" />
    <circle cx="12.75" cy="12.75" r="1.9" />
  </S>
);
export const Check: React.FC<P> = (p) => (
  <S {...p}>
    <path d="m3.75 9.4 3.4 3.35 7.1-7.5" />
  </S>
);
export const Star: React.FC<P & { filled?: boolean }> = ({ filled, ...p }) => (
  <S {...p}>
    <path
      d="M9 2.4l1.95 4.1 4.45.55-3.28 3.08.84 4.42L9 12.4l-3.96 2.15.84-4.42L2.6 7.05l4.45-.55L9 2.4z"
      fill={filled ? p.color ?? "rgba(25,25,25,0.56)" : "none"}
    />
  </S>
);
export const Laptop: React.FC<P> = (p) => (
  <S {...p}>
    <rect x="3.4" y="3.6" width="11.2" height="7.9" rx="1.2" />
    <path d="M1.9 14.2h14.2" />
    <path d="M6.3 14.2l.5-1.4h4.4l.5 1.4" />
  </S>
);
export const SidebarLeft: React.FC<P> = (p) => (
  <S {...p}>
    <rect x="2.25" y="3" width="13.5" height="12" rx="2.25" />
    <path d="M6.75 3v12" />
  </S>
);
export const ListIcon: React.FC<P> = (p) => (
  <S {...p}>
    <circle cx="3.6" cy="5.1" r="1.2" />
    <circle cx="3.6" cy="12.9" r="1.2" />
    <path d="M7.5 5.1h7.5M7.5 12.9h7.5M7.5 9h5.25" />
  </S>
);
export const Flag: React.FC<P> = (p) => (
  <S {...p}>
    <path d="M3.75 15.75V3.1s1.1-.85 3.4-.85c2.3 0 3.4 1.6 5.7 1.6 1.4 0 2.4-.4 2.4-.4v7.9s-1 .45-2.4.45c-2.3 0-3.4-1.6-5.7-1.6-2.3 0-3.4.85-3.4.85" />
  </S>
);
export const More: React.FC<P> = ({ color = "rgba(25,25,25,0.56)", ...p }) => (
  <S {...p} color={color}>
    <circle cx="3.6" cy="9" r=".6" fill={color} />
    <circle cx="9" cy="9" r=".6" fill={color} />
    <circle cx="14.4" cy="9" r=".6" fill={color} />
  </S>
);
export const ProgressIcon: React.FC<P> = (p) => (
  <S {...p} vb={16}>
    <rect x="2.6" y="2.3" width="10.8" height="11.8" rx="1.6" />
    <path d="M5.3 5.6h5.4M5.3 8.2h5.4M5.3 10.8h2.6" />
    <circle cx="11.4" cy="11.4" r="2.1" fill="#F9F9F9" />
    <path d="m12.9 12.9 1.4 1.4" />
  </S>
);
export const ArrowLeft: React.FC<P> = (p) => (
  <S {...p}>
    <path d="M14.25 9H3.75M8.25 4.5 3.75 9l4.5 4.5" />
  </S>
);
export const ArrowRight: React.FC<P> = (p) => (
  <S {...p}>
    <path d="M3.75 9h10.5M9.75 4.5l4.5 4.5-4.5 4.5" />
  </S>
);
export const Unhand: React.FC<P> = (p) => (
  <S {...p}>
    <path d="M6.2 9.4V4.1a1.05 1.05 0 0 1 2.1 0v4.2M8.3 7.9V3.3a1.05 1.05 0 0 1 2.1 0v4.9M10.4 8V4.4a1.05 1.05 0 0 1 2.1 0v5.5a4.8 4.8 0 0 1-4.8 4.8h-.4a4.4 4.4 0 0 1-3.6-1.9L2.2 9.9a1 1 0 0 1 1.5-1.3l2.5 2.1" />
    <path d="M2.4 2.4l13.2 13.2" />
  </S>
);
export const Popout: React.FC<P> = (p) => (
  <S {...p}>
    <rect x="2.4" y="5.2" width="10.4" height="10.4" rx="2" />
    <path d="M9.4 2.4h6.2v6.2M15.6 2.4 8.6 9.4" />
  </S>
);
export const Branch: React.FC<P> = (p) => (
  <S {...p}>
    <circle cx="5" cy="4.2" r="1.6" />
    <circle cx="5" cy="13.8" r="1.6" />
    <circle cx="13" cy="6.2" r="1.6" />
    <path d="M5 5.8v6.4M13 7.8c0 3.2-8 1.6-8 4.4" />
  </S>
);

export const Apple: React.FC<{ size?: number; color?: string }> = ({ size = 14, color = "#0A0A0A" }) => (
  <svg width={size} height={size} viewBox="0 0 384 470" style={{ display: "block" }}>
    <path
      fill={color}
      d="M318.7 250.7c-.6-63.3 51.7-93.7 54-95.2-29.4-43-75.2-48.9-91.5-49.6-39-4-76 22.9-95.8 22.9-19.7 0-50.2-22.3-82.5-21.7C60.5 107.7 21.4 132.4-.4 171.2c-44 76.3-11.3 189.4 31.6 251.4 21 30.3 46 64.4 78.8 63.2 31.6-1.3 43.6-20.5 81.8-20.5 38.2 0 49 20.5 82.4 19.9 34-.6 55.6-30.9 76.4-61.3 24.1-35.2 34-69.3 34.6-71.1-.8-.3-66.3-25.4-66.9-100.9zM256.6 64.6C274 43.5 285.7 14.2 282.5-15c-25.1 1-55.5 16.7-73.5 37.8-16.1 18.6-30.3 48.4-26.5 76.9 28 2.2 56.6-14.2 74.1-35.1z"
      transform="translate(10 15) scale(0.92)"
    />
  </svg>
);

export const Ubuntu: React.FC<{ size?: number }> = ({ size = 14 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: "block" }}>
    <circle cx="12" cy="12" r="6.4" fill="none" stroke="#E95420" strokeWidth="2.3" />
    <circle cx="4.3" cy="12" r="2.6" fill="#E95420" stroke="#FFF" strokeWidth="1.2" />
    <circle cx="15.9" cy="5.3" r="2.6" fill="#E95420" stroke="#FFF" strokeWidth="1.2" />
    <circle cx="15.9" cy="18.7" r="2.6" fill="#E95420" stroke="#FFF" strokeWidth="1.2" />
  </svg>
);

export const Windows: React.FC<{ size?: number }> = ({ size = 14 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: "block" }}>
    <rect x="2" y="2" width="9.5" height="9.5" fill="#F25022" />
    <rect x="12.5" y="2" width="9.5" height="9.5" fill="#7FBA00" />
    <rect x="2" y="12.5" width="9.5" height="9.5" fill="#00A4EF" />
    <rect x="12.5" y="12.5" width="9.5" height="9.5" fill="#FFB900" />
  </svg>
);

export const DevinMark: React.FC<{ size: number; style?: React.CSSProperties }> = ({ size, style }) => (
  <Img src={staticFile("devin-avatar-black.png")} style={{ width: size, height: size, display: "block", ...style }} />
);
