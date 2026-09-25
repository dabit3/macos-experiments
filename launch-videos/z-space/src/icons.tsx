import React from "react";
import { Img, staticFile } from "remotion";

export type FigmaIcon =
  | "check" | "cmd" | "computer" | "download" | "enter" | "expand" | "flag" | "flask" | "hexagon"
  | "list" | "loop" | "mic" | "more" | "next" | "panel" | "pause" | "plus" | "prev" | "shell"
  | "slash" | "stop" | "voice" | "send" | "chevron-down" | "sidebar" | "sliders" | "arrow-left";

export const Icon: React.FC<{ name: FigmaIcon; size?: number; style?: React.CSSProperties }> = ({ name, size = 18, style }) => (
  <Img src={staticFile(`icons/${name}.svg`)} style={{ width: size, height: size, display: "block", flexShrink: 0, ...style }} />
);

type SvgProps = { size?: number; color?: string; style?: React.CSSProperties };

export const AppleLogo: React.FC<SvgProps> = ({ size = 16, color = "#191919", style }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ display: "block", flexShrink: 0, ...style }}>
    <path
      fill={color}
      d="M11.182.008C11.148-.03 9.923.023 8.857 1.18c-1.066 1.156-.902 2.482-.878 2.516s1.52.087 2.475-1.258.762-2.391.728-2.43m3.314 11.733c-.048-.096-2.325-1.234-2.113-3.422s1.675-2.789 1.698-2.854-.597-.79-1.254-1.157a3.7 3.7 0 0 0-1.563-.434c-.108-.003-.483-.095-1.254.116-.508.139-1.653.589-1.968.607-.316.018-1.256-.522-2.267-.665-.647-.125-1.333.131-1.824.328-.49.196-1.422.754-2.074 2.237-.652 1.482-.311 3.83-.067 4.56s.625 1.924 1.273 2.796c.576.984 1.34 1.667 1.659 1.899s1.219.386 1.843.067c.502-.308 1.408-.485 1.766-.472.357.013 1.061.154 1.782.539.571.197 1.111.115 1.652-.105.541-.221 1.324-1.059 2.238-2.758q.52-1.185.473-1.282"
    />
  </svg>
);

export const UbuntuLogo: React.FC<SvgProps> = ({ size = 16, style }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ display: "block", flexShrink: 0, ...style }}>
    <circle cx="8" cy="8" r="4.6" fill="none" stroke="#E95420" strokeWidth="1.7" />
    <circle cx="2.6" cy="8" r="1.65" fill="#E95420" stroke="#FDFDFD" strokeWidth="0.9" />
    <circle cx="10.7" cy="3.3" r="1.65" fill="#E95420" stroke="#FDFDFD" strokeWidth="0.9" />
    <circle cx="10.7" cy="12.7" r="1.65" fill="#E95420" stroke="#FDFDFD" strokeWidth="0.9" />
  </svg>
);

export const WindowsLogo: React.FC<SvgProps> = ({ size = 16, style }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ display: "block", flexShrink: 0, ...style }}>
    <rect x="1" y="1" width="6.6" height="6.6" fill="#F35325" />
    <rect x="8.4" y="1" width="6.6" height="6.6" fill="#81BC06" />
    <rect x="1" y="8.4" width="6.6" height="6.6" fill="#05A6F0" />
    <rect x="8.4" y="8.4" width="6.6" height="6.6" fill="#FFBA08" />
  </svg>
);

export const Star: React.FC<SvgProps & { filled?: boolean }> = ({ size = 16, color = "rgba(25,25,25,0.6)", filled, style }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ display: "block", flexShrink: 0, ...style }}>
    <path
      d="M8 1.9l1.8 3.8 4.1.5-3 2.8.8 4.1L8 11.1l-3.7 2 .8-4.1-3-2.8 4.1-.5z"
      fill={filled ? color : "none"}
      stroke={color}
      strokeWidth="1.2"
      strokeLinejoin="round"
    />
  </svg>
);

export const Tick: React.FC<SvgProps> = ({ size = 16, color = "rgba(25,25,25,0.7)", style }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ display: "block", flexShrink: 0, ...style }}>
    <path d="M3.5 8.4l3 3 6-6.6" fill="none" stroke={color} strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const Chevron: React.FC<SvgProps & { dir?: "down" | "right" }> = ({ size = 16, color = "rgba(25,25,25,0.56)", dir = "down", style }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ display: "block", flexShrink: 0, transform: dir === "right" ? "rotate(-90deg)" : undefined, ...style }}>
    <path d="M4 6l4 4 4-4" fill="none" stroke={color} strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const Laptop: React.FC<SvgProps> = ({ size = 16, color = "#2F6FEB", style }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ display: "block", flexShrink: 0, ...style }}>
    <rect x="3.2" y="3" width="10" height="7.2" rx="1.2" fill="none" stroke={color} strokeWidth="1.1" />
    <path d="M1.6 12.6h13" stroke={color} strokeWidth="1.1" strokeLinecap="round" />
    <path d="M1.6 12.6l1.6-2.4M14.6 12.6L13.2 10.2" stroke={color} strokeWidth="1.1" strokeLinecap="round" />
  </svg>
);

export const ProgressIcon: React.FC<SvgProps> = ({ size = 18, color = "rgba(25,25,25,0.56)", style }) => (
  <svg width={size} height={size} viewBox="0 0 18 18" style={{ display: "block", flexShrink: 0, ...style }}>
    <path d="M13.5 8V4.2c0-.8-.7-1.5-1.5-1.5H5c-.8 0-1.5.7-1.5 1.5v9.6c0 .8.7 1.5 1.5 1.5h3" fill="none" stroke={color} strokeWidth="1.2" strokeLinecap="round" />
    <path d="M6 6h5M6 8.6h3" stroke={color} strokeWidth="1.2" strokeLinecap="round" />
    <circle cx="11.8" cy="12.2" r="2.3" fill="none" stroke={color} strokeWidth="1.2" />
    <path d="M13.5 13.9l1.6 1.6" stroke={color} strokeWidth="1.2" strokeLinecap="round" />
  </svg>
);

export const GithubMark: React.FC<SvgProps> = ({ size = 16, color = "#191919", style }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ display: "block", flexShrink: 0, ...style }}>
    <path
      fill={color}
      d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27s1.36.09 2 .27c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8"
    />
  </svg>
);

export const MutedSpeaker: React.FC<SvgProps> = ({ size = 18, color = "rgba(25,25,25,0.56)", style }) => (
  <svg width={size} height={size} viewBox="0 0 18 18" style={{ display: "block", flexShrink: 0, ...style }}>
    <path d="M4 7h2.4L10 4v10l-3.6-3H4z" fill="none" stroke={color} strokeWidth="1.2" strokeLinejoin="round" />
    <path d="M3 15L15 3" stroke={color} strokeWidth="1.2" strokeLinecap="round" />
  </svg>
);

export const Popout: React.FC<SvgProps> = ({ size = 18, color = "rgba(25,25,25,0.56)", style }) => (
  <svg width={size} height={size} viewBox="0 0 18 18" style={{ display: "block", flexShrink: 0, ...style }}>
    <rect x="2.5" y="4" width="11" height="10" rx="1.6" fill="none" stroke={color} strokeWidth="1.2" />
    <rect x="8" y="2.5" width="7.5" height="6" rx="1.2" fill="#F9F9F9" stroke={color} strokeWidth="1.2" />
  </svg>
);

export const CloseX: React.FC<SvgProps> = ({ size = 16, color = "rgba(25,25,25,0.8)", style }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ display: "block", flexShrink: 0, ...style }}>
    <path d="M4 4l8 8M12 4l-8 8" stroke={color} strokeWidth="1.3" strokeLinecap="round" />
  </svg>
);
