import React from "react";
import { Img, staticFile } from "remotion";

export const Icon: React.FC<{ name: string; size: number; w?: number; h?: number; style?: React.CSSProperties }> = ({
  name,
  size,
  w,
  h,
  style,
}) => <Img src={staticFile(`icons/${name}.svg`)} style={{ width: w ?? size, height: h ?? size, display: "block", flexShrink: 0, ...style }} />;

export const IconBox: React.FC<{ size?: number; icon: string; iconSize: number; radius?: number; style?: React.CSSProperties }> = ({
  size = 28,
  icon,
  iconSize,
  radius = 9999,
  style,
}) => (
  <div style={{ width: size, height: size, borderRadius: radius, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0, ...style }}>
    <Icon name={icon} size={iconSize} />
  </div>
);

const G = "rgba(25,25,25,0.56)";

export const UbuntuIcon: React.FC<{ size: number }> = ({ size }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ display: "block", flexShrink: 0 }}>
    <circle cx="8" cy="8" r="4.6" fill="none" stroke="#e95420" strokeWidth="1.7" />
    <g fill="#e95420" stroke="#fff" strokeWidth="1">
      <circle cx="2.6" cy="8" r="1.9" />
      <circle cx="10.7" cy="3.3" r="1.9" />
      <circle cx="10.7" cy="12.7" r="1.9" />
    </g>
  </svg>
);

export const WindowsIcon: React.FC<{ size: number }> = ({ size }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ display: "block", flexShrink: 0 }}>
    <rect x="1" y="1" width="6.7" height="6.7" fill="#f25022" />
    <rect x="8.3" y="1" width="6.7" height="6.7" fill="#7fba00" />
    <rect x="1" y="8.3" width="6.7" height="6.7" fill="#00a4ef" />
    <rect x="8.3" y="8.3" width="6.7" height="6.7" fill="#ffb900" />
  </svg>
);

export const StarIcon: React.FC<{ size: number; filled?: boolean }> = ({ size, filled }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ display: "block", flexShrink: 0 }}>
    <path
      d="M8 1.9l1.8 3.75 4.1.55-3 2.85.75 4.05L8 11.15 4.35 13.1l.75-4.05-3-2.85 4.1-.55L8 1.9z"
      fill={filled ? "#6b6b6b" : "none"}
      stroke={filled ? "#6b6b6b" : "#3a3a3a"}
      strokeWidth="1.1"
      strokeLinejoin="round"
    />
  </svg>
);

export const CheckIcon: React.FC<{ size: number; color?: string }> = ({ size, color = "#3a3a3a" }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ display: "block", flexShrink: 0 }}>
    <path d="M3 8.4l3.2 3.1L13 4.6" fill="none" stroke={color} strokeWidth="1.25" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const LaptopIcon: React.FC<{ size: number; color: string }> = ({ size, color }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ display: "block", flexShrink: 0 }}>
    <rect x="3" y="3.2" width="10" height="7" rx="1" fill="none" stroke={color} strokeWidth="1.2" />
    <path d="M1.6 12.6h12.8" stroke={color} strokeWidth="1.2" strokeLinecap="round" />
    <rect x="8.6" y="6.4" width="4.6" height="6.8" rx="0.9" fill="#e9eefe" stroke={color} strokeWidth="1.2" />
  </svg>
);

export const SidebarIcon: React.FC<{ size: number }> = ({ size }) => (
  <svg width={size} height={size} viewBox="0 0 18 18" style={{ display: "block", flexShrink: 0 }}>
    <rect x="2.4" y="3.4" width="13.2" height="11.2" rx="2" fill="none" stroke={G} strokeWidth="1.2" />
    <path d="M7 3.6v10.8" stroke={G} strokeWidth="1.2" />
  </svg>
);

export const ProgressIcon: React.FC<{ size: number }> = ({ size }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ display: "block", flexShrink: 0 }}>
    <path d="M12.5 7V3.5a1 1 0 00-1-1h-8a1 1 0 00-1 1v9a1 1 0 001 1H7" fill="none" stroke={G} strokeWidth="1.1" />
    <path d="M5 5.5h5M5 8h3" stroke={G} strokeWidth="1.1" strokeLinecap="round" />
    <circle cx="11" cy="11" r="2.2" fill="none" stroke={G} strokeWidth="1.1" />
    <path d="M12.6 12.6l1.6 1.6" stroke={G} strokeWidth="1.1" strokeLinecap="round" />
  </svg>
);

export const ChevronRight: React.FC<{ size: number }> = ({ size }) => (
  <svg width={size} height={size} viewBox="0 0 14 14" style={{ display: "block", flexShrink: 0 }}>
    <path d="M5.3 3.3L9 7l-3.7 3.7" fill="none" stroke={G} strokeWidth="1.1" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const ArrowIcon: React.FC<{ size: number; dir: "left" | "right" }> = ({ size, dir }) => (
  <svg width={size} height={size} viewBox="0 0 18 18" style={{ display: "block", flexShrink: 0, transform: dir === "left" ? "scaleX(-1)" : undefined }}>
    <path d="M3 9h12M10.5 4.5L15 9l-4.5 4.5" fill="none" stroke={G} strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);
