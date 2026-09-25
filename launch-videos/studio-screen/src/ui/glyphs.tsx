import { C } from "./tokens";

type P = { size?: number; color?: string; style?: React.CSSProperties };

export const Sliders: React.FC<P> = ({ size = 18, color = C.muted }) => (
  <svg width={size} height={size} viewBox="0 0 18 18" fill="none">
    <path d="M5.25 2.25v5.4M5.25 12.6v3.15M12.75 2.25v2.4M12.75 9.6v6.15" stroke={color} strokeWidth={1.125} strokeLinecap="round" />
    <circle cx={5.25} cy={10.12} r={2.25} stroke={color} strokeWidth={1.125} />
    <circle cx={12.75} cy={7.12} r={2.25} stroke={color} strokeWidth={1.125} />
  </svg>
);

export const ArrowUp: React.FC<P> = ({ size = 16, color = "#fff" }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
    <path d="M8 13V3M8 3L3.75 7.25M8 3l4.25 4.25" stroke={color} strokeWidth={1.33} strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const ChevronDown: React.FC<P> = ({ size = 16, color = C.muted, style }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={style}>
    <path d="M4.5 6.25L8 9.75l3.5-3.5" stroke={color} strokeWidth={1.33} strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const ChevronRight: React.FC<P> = ({ size = 14, color = C.muted }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
    <path d="M6.25 4.5L9.75 8l-3.5 3.5" stroke={color} strokeWidth={1.33} strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const Check: React.FC<P> = ({ size = 16, color = C.text }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
    <path d="M3.5 8.5l3 3 6-7" stroke={color} strokeWidth={1.33} strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const Ubuntu: React.FC<P> = ({ size = 14 }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
    <circle cx={8} cy={8} r={4.6} stroke="#E95420" strokeWidth={1.7} />
    <circle cx={3.1} cy={8} r={1.75} fill="#E95420" stroke="#fafafa" strokeWidth={0.9} />
    <circle cx={10.45} cy={3.76} r={1.75} fill="#E95420" stroke="#fafafa" strokeWidth={0.9} />
    <circle cx={10.45} cy={12.24} r={1.75} fill="#E95420" stroke="#fafafa" strokeWidth={0.9} />
  </svg>
);

export const Apple: React.FC<P> = ({ size = 14, color = C.text }) => (
  <svg width={size} height={size} viewBox="0 0 16 16">
    <path
      fill={color}
      d="M11.18 8.46c-.02-1.7 1.39-2.52 1.45-2.56-.79-1.16-2.02-1.31-2.46-1.33-1.04-.11-2.04.62-2.57.62-.53 0-1.35-.6-2.22-.59-1.14.02-2.2.67-2.78 1.69-1.19 2.06-.3 5.1.85 6.77.57.82 1.24 1.73 2.12 1.7.85-.03 1.17-.55 2.2-.55 1.02 0 1.31.55 2.21.53.92-.02 1.5-.83 2.05-1.65.65-.95.92-1.87.93-1.92-.02-.01-1.77-.68-1.78-2.71zM9.5 3.46c.47-.57.78-1.35.7-2.14-.67.03-1.49.45-1.97 1.01-.43.5-.81 1.3-.71 2.07.75.06 1.51-.38 1.98-.94z"
    />
  </svg>
);

export const Windows: React.FC<P> = ({ size = 14 }) => (
  <svg width={size} height={size} viewBox="0 0 16 16">
    <path fill="#0078D4" d="M2 3.4l5-.7v4.8H2zM7.6 2.6L14 1.7v5.8H7.6zM2 8.1h5v4.8l-5-.7zM7.6 8.1H14v5.9l-6.4-.9z" />
  </svg>
);

export const Laptop: React.FC<P> = ({ size = 14, color = C.blue }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
    <rect x={3} y={3.25} width={10} height={7} rx={1.2} stroke={color} strokeWidth={1.2} />
    <path d="M1.75 12.75h12.5" stroke={color} strokeWidth={1.2} strokeLinecap="round" />
  </svg>
);

export const ProgressDoc: React.FC<P> = ({ size = 16, color = C.muted }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
    <path d="M12.5 7V3.8c0-.72-.58-1.3-1.3-1.3H4.3C3.58 2.5 3 3.08 3 3.8v8.4c0 .72.58 1.3 1.3 1.3H7" stroke={color} strokeWidth={1.2} strokeLinecap="round" />
    <path d="M5.5 5.5h4.5M5.5 8h2.5" stroke={color} strokeWidth={1.2} strokeLinecap="round" />
    <circle cx={11} cy={11} r={2.1} stroke={color} strokeWidth={1.2} />
    <path d="M12.6 12.6l1.4 1.4" stroke={color} strokeWidth={1.2} strokeLinecap="round" />
  </svg>
);

export const Clock: React.FC<P> = ({ size = 16, color = C.muted }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
    <circle cx={8} cy={8} r={5.9} stroke={color} strokeWidth={1.2} />
    <path d="M8 5v3.2l2 1.3" stroke={color} strokeWidth={1.2} strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const Star: React.FC<P> = ({ size = 14, color = C.faint }) => (
  <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
    <path d="M8 2.2l1.75 3.55 3.92.57-2.84 2.77.67 3.9L8 11.15 4.5 13l.67-3.9L2.33 6.32l3.92-.57z" stroke={color} strokeWidth={1.1} strokeLinejoin="round" />
  </svg>
);

export const DevinGlyph: React.FC<P & { phase?: number }> = ({ size = 16, color = C.text, phase = 0 }) => {
  const s = (o: number) => 1 + 0.12 * Math.sin(phase + o);
  return (
    <svg width={size} height={size} viewBox="0 0 16 16">
      <circle cx={4.2} cy={4.4} r={2.6 * s(0)} fill={color} />
      <circle cx={4.2} cy={11.6} r={2.6 * s(2.1)} fill={color} />
      <circle cx={11} cy={8} r={3.6 * s(4.2)} fill={color} />
    </svg>
  );
};

export const Pointer: React.FC<{ style?: React.CSSProperties }> = ({ style }) => (
  <svg width={28} height={32} viewBox="0 0 28 32" fill="none" style={{ overflow: "visible", filter: "drop-shadow(0 1px 1.5px rgba(0,0,0,0.3))", ...style }}>
    <path d="M6 4V21L10.5 16.5L14.5 24L17.5 22.5L13.5 15L20 14L6 4Z" fill="white" stroke="black" strokeWidth={1.2} strokeLinejoin="round" />
  </svg>
);
