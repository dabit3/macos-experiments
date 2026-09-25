export const C = {
  page: "#fafafa",
  surface: "#ffffff",
  text: "#191919",
  muted: "rgba(25,25,25,0.56)",
  faint: "rgba(25,25,25,0.4)",
  border: "rgba(0,0,0,0.08)",
  hairline: "rgba(0,0,0,0.06)",
  hover: "rgba(0,0,0,0.04)",
  active: "rgba(0,0,0,0.06)",
  blue: "#337df4",
  blueTint: "rgba(51,125,244,0.1)",
  green: "#00a558",
  timeline: "#34d399",
  red: "#f53b3a",
  cursorBlue: "#60a5fa",
};

export const inter = "'Inter', system-ui, sans-serif";
export const mono = "'Roboto Mono', ui-monospace, monospace";

export const t13 = { fontFamily: inter, fontSize: 13, lineHeight: "18px", letterSpacing: "-0.065px" } as const;
export const t14 = { fontFamily: inter, fontSize: 14, lineHeight: "20px", letterSpacing: "-0.07px" } as const;
export const t12 = { fontFamily: inter, fontSize: 12, lineHeight: "16px" } as const;
export const m11 = { fontFamily: mono, fontSize: 11, lineHeight: "14px", letterSpacing: "0.11px" } as const;

export const UI_W = 1920 / (1080 / 690);
export const UI_H = 690;
export const UI_ZOOM = 1080 / 690;
