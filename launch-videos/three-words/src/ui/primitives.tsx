import { Img, staticFile } from "remotion";
import { INTER, MONO } from "../fonts";
import { C, LH, LW, S } from "../theme";
import type { Pt } from "../anim";

export const Icon: React.FC<{ name: string; size: number; style?: React.CSSProperties }> = ({ name, size, style }) => (
  <Img src={staticFile(`icons/${name}.svg`)} style={{ width: size, height: size, display: "block", flexShrink: 0, ...style }} />
);

export const text = (size: number, lh: number, color: string = C.ink, weight = 400, tracking = -0.005): React.CSSProperties => ({
  fontFamily: INTER,
  fontSize: size,
  lineHeight: `${lh}px`,
  fontWeight: weight,
  color,
  letterSpacing: `${tracking}em`,
  whiteSpace: "nowrap",
});

export const mono = (color: string, weight = 400): React.CSSProperties => ({
  fontFamily: MONO,
  fontSize: 11,
  lineHeight: "14px",
  fontWeight: weight,
  color,
  letterSpacing: "0.11px",
  whiteSpace: "nowrap",
});

export type Cam = { z: number; x: number; y: number };

export const toScreen = (cam: Cam, p: Pt): Pt => ({
  x: (p.x - cam.x) * S * cam.z + 960,
  y: (p.y - cam.y) * S * cam.z + 540,
});

export const Camera: React.FC<{ cam: Cam; children: React.ReactNode; bg?: string }> = ({ cam, children, bg = C.bg }) => (
  <div
    style={{
      position: "absolute",
      left: 0,
      top: 0,
      width: LW,
      height: LH,
      background: bg,
      transformOrigin: "0 0",
      transform: `translate(960px, 540px) scale(${S * cam.z}) translate(${-cam.x}px, ${-cam.y}px)`,
    }}
  >
    {children}
  </div>
);

export const Box: React.FC<{ size?: number; radius?: number; children: React.ReactNode; bg?: string }> = ({
  size = 28,
  radius = 9999,
  children,
  bg,
}) => (
  <div style={{ width: size, height: size, borderRadius: radius, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0, background: bg }}>
    {children}
  </div>
);

export const Cursor: React.FC<{ p: Pt; pressed?: number; opacity?: number }> = ({ p, pressed = 0, opacity = 1 }) => (
  <svg
    width={24}
    height={24}
    viewBox="0 0 24 24"
    style={{
      position: "absolute",
      left: p.x - 5.5,
      top: p.y - 3.5,
      opacity,
      transformOrigin: "5.5px 3.5px",
      transform: `scale(${1 - 0.12 * pressed})`,
      filter: "drop-shadow(0px 1px 1.5px rgba(0,0,0,0.3))",
      zIndex: 50,
    }}
  >
    <path d="M5.5 3.5 L5.5 19.2 L9.4 15.6 L11.9 21.2 L14.5 20.1 L12 14.6 L17.3 14.6 Z" fill="#000" stroke="#fff" strokeWidth={1.3} strokeLinejoin="round" />
  </svg>
);

export const Caret: React.FC<{ on: boolean }> = ({ on }) => (
  <span style={{ display: "inline-block", width: 1.2, height: 17, marginLeft: 0.5, background: C.ink, verticalAlign: "-3px", opacity: on ? 1 : 0 }} />
);

export const UbuntuIcon: React.FC<{ size: number }> = ({ size }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ flexShrink: 0 }}>
    <circle cx="8" cy="8" r="4.6" fill="none" stroke="#E95420" strokeWidth="1.7" />
    <circle cx="2.4" cy="8" r="1.7" fill="#E95420" stroke="#fcfcfc" strokeWidth="0.9" />
    <circle cx="10.8" cy="3.15" r="1.7" fill="#E95420" stroke="#fcfcfc" strokeWidth="0.9" />
    <circle cx="10.8" cy="12.85" r="1.7" fill="#E95420" stroke="#fcfcfc" strokeWidth="0.9" />
  </svg>
);

export const WindowsIcon: React.FC<{ size: number }> = ({ size }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ flexShrink: 0 }}>
    <rect x="1" y="1" width="6.6" height="6.6" fill="#F25022" />
    <rect x="8.4" y="1" width="6.6" height="6.6" fill="#7FBA00" />
    <rect x="1" y="8.4" width="6.6" height="6.6" fill="#00A4EF" />
    <rect x="8.4" y="8.4" width="6.6" height="6.6" fill="#FFB900" />
  </svg>
);

export const StarIcon: React.FC<{ size: number; filled: boolean }> = ({ size, filled }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ flexShrink: 0 }}>
    <path
      d="M8 1.9l1.8 3.75 4.1.55-3 2.85.75 4.05L8 11.15 4.35 13.1l.75-4.05-3-2.85 4.1-.55z"
      fill={filled ? "rgba(25,25,25,0.56)" : "none"}
      stroke="rgba(25,25,25,0.56)"
      strokeWidth="1.2"
      strokeLinejoin="round"
    />
  </svg>
);

export const CheckIcon: React.FC<{ size: number }> = ({ size }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ flexShrink: 0 }}>
    <path d="M3.2 8.4l3.1 3.1 6.5-7" fill="none" stroke="rgba(25,25,25,0.56)" strokeWidth="1.25" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const GithubIcon: React.FC<{ size: number }> = ({ size }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ flexShrink: 0 }}>
    <path
      fill="#191919"
      d="M8 0c4.42 0 8 3.58 8 8a8.013 8.013 0 0 1-5.45 7.59c-.4.08-.55-.17-.55-.38 0-.27.01-1.13.01-2.2 0-.75-.25-1.23-.54-1.48 1.78-.2 3.65-.88 3.65-3.95 0-.88-.31-1.59-.82-2.15.08-.2.36-1.02-.08-2.12 0 0-.67-.22-2.2.82-.64-.18-1.32-.27-2-.27-.68 0-1.36.09-2 .27-1.53-1.03-2.2-.82-2.2-.82-.44 1.1-.16 1.92-.08 2.12-.51.56-.82 1.28-.82 2.15 0 3.06 1.86 3.75 3.64 3.95-.23.2-.44.55-.51 1.07-.46.21-1.61.55-2.33-.66-.15-.24-.6-.83-1.23-.82-.67.01-.27.38.01.53.34.19.73.9.82 1.13.16.45.68 1.31 2.69.94 0 .67.01 1.3.01 1.49 0 .21-.15.45-.55.38A7.995 7.995 0 0 1 0 8c0-4.42 3.58-8 8-8Z"
    />
  </svg>
);

export const Stroke: React.FC<{ size: number; d: string; w?: number }> = ({ size, d, w = 1.25 }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ flexShrink: 0 }}>
    <path d={d} fill="none" stroke="rgba(25,25,25,0.56)" strokeWidth={w} strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const Logo: React.FC<{ height?: number }> = ({ height = 22 }) => {
  const w = 82.819 * (height / 22);
  return (
    <div style={{ position: "relative", width: w, height, flexShrink: 0 }}>
      <Img src={staticFile("icons/logo-mark.svg")} style={{ position: "absolute", left: 0, top: 0, width: w * 0.2337, height }} />
      <Img
        src={staticFile("icons/logo-word.svg")}
        style={{ position: "absolute", left: w * 0.3337, top: height * 0.1241, width: w * (1 - 0.3337 - 0.0011), height: height * (1 - 0.1241 - 0.1144) }}
      />
    </div>
  );
};

export const MacBadge: React.FC = () => (
  <div style={{ display: "flex", alignItems: "center", gap: 4, height: 20, padding: "2px 6px", borderRadius: 4, background: C.blue10, flexShrink: 0 }}>
    <Icon name="macos-badge" size={14} />
    <span style={text(12, 16, C.blue, 500, -0.0054)}>macOS</span>
  </div>
);
