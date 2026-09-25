import React from "react";

export const Arrow: React.FC = () => (
  <svg width={22} height={30} viewBox="0 0 22 30" style={{ display: "block", filter: "drop-shadow(0 1px 1.5px rgba(0,0,0,0.3))" }}>
    <path d="M1.5 1.5v22.2l5.3-5.1 3.4 8.1 3.6-1.5-3.4-8h7.4z" fill="#000" stroke="#fff" strokeWidth="1.5" strokeLinejoin="round" />
  </svg>
);

export const Hand: React.FC = () => (
  <svg width={24} height={28} viewBox="0 0 24 28" style={{ display: "block", filter: "drop-shadow(0 1px 1.5px rgba(0,0,0,0.3))" }}>
    <path
      d="M7.6 2.6c1 0 1.8.8 1.8 1.8v7.1c.3-.9 1.1-1.4 2-1.4 1 0 1.7.6 1.9 1.5.3-.6 1-1 1.8-1 1 0 1.8.7 1.9 1.7.3-.4.9-.7 1.5-.7 1.1 0 1.9.9 1.9 1.9v5.2c0 4.3-3 7.5-7.1 7.5h-1.4c-2.4 0-4.2-1-5.6-3l-4-5.6c-.6-.9-.4-2 .4-2.6.8-.6 1.9-.4 2.5.3l1.2 1.5V4.4c0-1 .8-1.8 1.8-1.8z"
      fill="#fff"
      stroke="#000"
      strokeWidth="1.3"
      strokeLinejoin="round"
    />
    <path d="M11.4 13v5M14.9 13.6v4.4M18.3 14.2v3.8" stroke="#000" strokeWidth="1.1" strokeLinecap="round" />
  </svg>
);

export type CursorKey = { f: number; x: number; y: number };

const ease = (t: number) => (t < 0.5 ? 16 * t ** 5 : 1 - (-2 * t + 2) ** 5 / 2);
const easeInOut = (t: number) => (t < 0.5 ? 4 * t ** 3 : 1 - (-2 * t + 2) ** 3 / 2);

export const cursorAt = (keys: CursorKey[], frame: number) => {
  if (frame <= keys[0].f) return { x: keys[0].x, y: keys[0].y };
  for (let i = 0; i < keys.length - 1; i++) {
    const a = keys[i];
    const b = keys[i + 1];
    if (frame <= b.f) {
      const raw = (frame - a.f) / (b.f - a.f);
      const t = 0.5 * ease(raw) + 0.5 * easeInOut(raw);
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const bend = 0.18;
      const cx = a.x + dx * 0.5 - dy * bend;
      const cy = a.y + dy * 0.5 + dx * bend;
      const x = (1 - t) ** 2 * a.x + 2 * (1 - t) * t * cx + t ** 2 * b.x;
      const y = (1 - t) ** 2 * a.y + 2 * (1 - t) * t * cy + t ** 2 * b.y;
      return { x, y };
    }
  }
  const l = keys[keys.length - 1];
  return { x: l.x, y: l.y };
};
