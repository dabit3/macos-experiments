import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadRobotoMono } from "@remotion/google-fonts/RobotoMono";

const inter = loadInter("normal", { weights: ["400", "500", "600"], subsets: ["latin"] });
const mono = loadRobotoMono("normal", { weights: ["400", "500"], subsets: ["latin"] });

export const FONT = `${inter.fontFamily}, -apple-system, system-ui, sans-serif`;
export const MONO = `${mono.fontFamily}, ui-monospace, monospace`;

export const FPS = 60;
export const WIDTH = 1920;
export const HEIGHT = 1080;

/** App viewport in CSS px (Figma frames are 1203 wide). */
export const VW = 1203;
export const VH = (VW * 9) / 16;
export const BASE_SCALE = WIDTH / VW;

export const C = {
  bg: "#f9f9f9",
  panel: "#fcfcfc",
  text: "#191919",
  text56: "rgba(25,25,25,0.56)",
  text40: "rgba(25,25,25,0.4)",
  border08: "rgba(0,0,0,0.08)",
  border06: "rgba(0,0,0,0.06)",
  fill04: "rgba(0,0,0,0.04)",
  fill06: "rgba(0,0,0,0.06)",
  dark: "#1f1f1f",
  blue: "#317cff",
  badgeBg: "#e9eefe",
  badgeText: "#2563eb",
  green: "#00a558",
  greenBar: "#34d399",
  red: "#f53b3a",
};

/** Text presets from Figma (size / line-height / tracking). */
export const T = {
  t12: { fontSize: 12, lineHeight: "16px", letterSpacing: 0 },
  t13: { fontSize: 13, lineHeight: "18px", letterSpacing: -0.065 },
  t14: { fontSize: 14, lineHeight: "20px", letterSpacing: -0.07 },
  mono11: { fontFamily: MONO, fontSize: 11, lineHeight: "14px", letterSpacing: 0.11 },
} as const;

/** Rect of the Computer pane's screen area inside the session view (app px). */
export const SCREEN = { x: 638, y: 128, w: 557, h: (557 * 654) / 874 };
/** Footage frame size (px) — crop of the Computer pane screen from the real recording. */
export const FOOTAGE = { w: 874, h: 654 };
export const FK = SCREEN.w / FOOTAGE.w;
