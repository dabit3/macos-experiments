/** macOS arrow cursor drawn in screen px. */
export const Cursor = ({ x, y, down, o = 1 }: { x: number; y: number; down: number; o?: number }) => (
  <svg width={34} height={34} viewBox="0 0 24 24" style={{ position: "absolute", left: x - 7, top: y - 4, opacity: o, transform: `scale(${1 - 0.1 * down})`, transformOrigin: "7px 4px", filter: "drop-shadow(0 1.5px 2px rgba(0,0,0,0.28))" }}>
    <path d="M5.5 3.2v15.6l3.9-3.7 2.5 5.8 2.7-1.2-2.5-5.7h5.4z" fill="#000" stroke="#FFF" strokeWidth={1.3} strokeLinejoin="round" />
  </svg>
);

/** Simulator touch indicator (screen px). */
export const Touch = ({ x, y, t }: { x: number; y: number; t: number }) => {
  if (t <= 0 || t >= 1) return null;
  const r = 20 + 16 * t;
  const o = t < 0.25 ? t / 0.25 : 1 - (t - 0.25) / 0.75;
  return (
    <div style={{ position: "absolute", left: x - r, top: y - r, width: r * 2, height: r * 2, borderRadius: 999, background: "rgba(255,255,255,0.28)", boxShadow: "0 0 0 1.5px rgba(255,255,255,0.8)", opacity: o }} />
  );
};
