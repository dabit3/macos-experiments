import React from "react";
import { Img, staticFile } from "remotion";
import { C, INTER } from "../theme";
import { Icon, FigmaIcon } from "../icons";

export const Btn: React.FC<{ icon: FigmaIcon; size?: number; box?: number; radius?: number; style?: React.CSSProperties }> = ({ icon, size = 18, box = 28, radius = 9999, style }) => (
  <div style={{ width: box, height: box, borderRadius: radius, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0, ...style }}>
    <Icon name={icon} size={size} />
  </div>
);

export const Text: React.FC<{ size?: number; lh?: number; weight?: number; color?: string; track?: number; style?: React.CSSProperties; children: React.ReactNode }> = ({
  size = 14,
  lh = 20,
  weight = 400,
  color = C.text,
  track,
  style,
  children,
}) => (
  <div
    style={{
      fontFamily: INTER,
      fontSize: size,
      lineHeight: `${lh}px`,
      fontWeight: weight,
      color,
      letterSpacing: track ?? -0.005 * size,
      whiteSpace: "nowrap",
      fontFeatureSettings: "'cv11', 'ss01'",
      ...style,
    }}
  >
    {children}
  </div>
);

export const DevinMark: React.FC<{ size: number; style?: React.CSSProperties }> = ({ size, style }) => (
  <Img src={staticFile("media/mark-black.png")} style={{ width: size, height: size, display: "block", ...style }} />
);

export const Caret: React.FC<{ frame: number; h?: number; color?: string }> = ({ frame, h = 18, color = C.text }) => (
  <span
    style={{
      display: "inline-block",
      width: 1.2,
      height: h,
      background: color,
      verticalAlign: "middle",
      marginLeft: 0.5,
      marginTop: -2,
      opacity: Math.floor(frame / 32) % 2 === 0 ? 1 : 0,
    }}
  />
);

export const Kbd: React.FC<{ icon: FigmaIcon }> = ({ icon }) => (
  <span
    style={{
      display: "inline-flex",
      width: 16,
      height: 16,
      borderRadius: 4,
      background: "rgba(0,0,0,0.06)",
      alignItems: "center",
      justifyContent: "center",
      verticalAlign: "middle",
      margin: "0 2px",
      marginTop: -3,
    }}
  >
    <Icon name={icon} size={12} />
  </span>
);
