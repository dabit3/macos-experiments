import { C, T13, T14 } from "../tokens";
import { DevinMark, Icon, Kbd } from "./Primitives";

export const UserBubble: React.FC<{ text: string; opacity?: number; y?: number }> = ({ text, opacity = 1, y = 0 }) => (
  <div style={{ display: "flex", justifyContent: "flex-end", opacity, transform: `translateY(${y}px)` }}>
    <div
      style={{
        maxWidth: 445,
        background: C.fill,
        borderRadius: "16px 4px 16px 16px",
        padding: "8px 14px",
        ...T14,
      }}
    >
      {text}
    </div>
  </div>
);

const Chevron: React.FC<{ open: number }> = ({ open }) => (
  <svg width={14} height={14} viewBox="0 0 16 16" style={{ transform: `rotate(${open * 90}deg)` }}>
    <path d="M6 4l4 4-4 4" fill="none" stroke={C.muted} strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

export const WorkHeader: React.FC<{ label: string; open: number }> = ({ label, open }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 4, ...T13, color: C.muted, height: 22 }}>
    <Chevron open={open} />
    <span>{label}</span>
  </div>
);

export type WorkRow = { kind: "think" | "cmd" | "file"; text: string; meta?: string };

export const WorkRows: React.FC<{ rows: readonly WorkRow[]; shown: (i: number) => number; height: number }> = ({
  rows,
  shown,
  height,
}) => (
  <div style={{ height, overflow: "hidden" }}>
    <div style={{ paddingLeft: 18, display: "flex", flexDirection: "column", gap: 4, paddingTop: 4 }}>
      {rows.map((r, i) => {
        const o = shown(i);
        return (
          <div
            key={r.text}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 8,
              height: 22,
              ...T13,
              color: C.muted,
              opacity: o,
              transform: `translateY(${(1 - o) * 4}px)`,
            }}
          >
            {r.kind === "cmd" ? (
              <span style={{ fontFamily: "inherit", color: C.text, opacity: 0.72, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                {r.text}
              </span>
            ) : r.kind === "file" ? (
              <span style={{ whiteSpace: "nowrap" }}>
                Edited <span style={{ color: C.text, opacity: 0.72 }}>{r.text}</span>
              </span>
            ) : (
              <span style={{ whiteSpace: "nowrap", display: "flex", alignItems: "center", gap: 4 }}>
                {r.text}
                <Chevron open={0} />
              </span>
            )}
            <div style={{ flex: 1 }} />
            {r.meta ? (
              <span style={{ whiteSpace: "nowrap", color: r.kind === "file" ? C.green : C.faint }}>{r.meta}</span>
            ) : null}
          </div>
        );
      })}
    </div>
  </div>
);

export const Status: React.FC<{ text: string; opacity?: number }> = ({ text, opacity = 1 }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 8, ...T14, opacity, height: 22 }}>
    <DevinMark size={14} />
    <span>{text}</span>
  </div>
);

export const QueuePlaceholder: React.FC = () => (
  <span>
    Guide Devin while it works, or press <Kbd id="0ca65" />
    <Kbd id="5ba73" /> to queue
  </span>
);

export const RecordingCard: React.FC<{ title: string; passed: number; thumb: React.ReactNode; playPress?: number; hover?: number; playOpacity?: number }> = ({
  title,
  passed,
  thumb,
  playPress = 0,
  hover = 0,
  playOpacity = 1,
}) => (
  <div style={{ width: 360, background: C.fill, borderRadius: 14, padding: "0 6px 6px", boxSizing: "border-box" }}>
    <div style={{ height: 40, display: "flex", alignItems: "center", gap: 8, padding: "0 8px" }}>
      <Icon id="0de5b" size={16} />
      <span style={{ ...T13, fontWeight: 500, whiteSpace: "nowrap" }}>{title}</span>
      <span style={{ ...T13, color: C.muted, whiteSpace: "nowrap" }}>{passed} passed</span>
    </div>
    <div
      style={{
        position: "relative",
        width: 348,
        height: 261.4,
        background: "#fff",
        border: `0.8px solid ${C.hair}`,
        borderRadius: 8,
        overflow: "hidden",
        boxSizing: "border-box",
        boxShadow: "0 1px 2px rgba(0,0,0,0.04)",
      }}
    >
      {thumb}
      <div style={{ position: "absolute", inset: 0, background: `rgba(0,0,0,${(0.04 + hover * 0.06) * playOpacity})` }} />
      <div
        style={{
          position: "absolute",
          left: 174 - 24,
          top: 130.7 - 24,
          width: 48,
          height: 48,
          borderRadius: 9999,
          background: "rgba(31,31,31,0.94)",
          border: "0.8px solid rgba(255,255,255,0.04)",
          boxSizing: "border-box",
          boxShadow: "0 1px 3px rgba(0,0,0,0.2)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          transform: `scale(${1 + hover * 0.06 - playPress * 0.1})`,
          opacity: playOpacity,
        }}
      >
        <Icon id="3c88e" size={20} />
      </div>
    </div>
  </div>
);
