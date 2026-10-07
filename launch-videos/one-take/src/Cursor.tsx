import React from "react";

export const Pointer: React.FC<{ x: number; y: number; scale: number; opacity: number; size?: number }> = ({ x, y, scale, opacity, size = 17 }) => (
  <div style={{ position: "absolute", left: x, top: y, width: 0, height: 0, opacity }}>
    <svg
      width={size * 0.7}
      height={size}
      viewBox="0 0 14 20"
      style={{ position: "absolute", left: -1, top: -1, transform: `scale(${scale})`, transformOrigin: "1px 1px", filter: "drop-shadow(0 1px 1.5px rgba(0,0,0,0.3))" }}
    >
      <path d="M1 1v15.2l3.7-3.6 2.4 5.6 2.6-1.1-2.4-5.5h5.2z" fill="#000" stroke="#FFF" strokeWidth="1.2" strokeLinejoin="round" />
    </svg>
  </div>
);

export const Ripple: React.FC<{ x: number; y: number; p: number; r: number }> = ({ x, y, p, r }) => (
  <div
    style={{
      position: "absolute",
      left: x - r,
      top: y - r,
      width: r * 2,
      height: r * 2,
      borderRadius: r,
      background: "rgba(255,255,255,0.35)",
      boxShadow: "0 0 0 1px rgba(0,0,0,0.25)",
      transform: `scale(${0.35 + 0.65 * p})`,
      opacity: (1 - p) * 0.9,
    }}
  />
);
