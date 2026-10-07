import { Img, staticFile } from "remotion";
import { inter } from "../fonts";
import { C, T12, T13, T14 } from "../tokens";

export const Icon: React.FC<{ id: string; size?: number; w?: number; h?: number; style?: React.CSSProperties }> = ({
  id,
  size = 18,
  w,
  h,
  style,
}) => <Img src={staticFile(`icons/${id}.svg`)} style={{ width: w ?? size, height: h ?? size, display: "block", ...style }} />;

export const IconButton: React.FC<{ id: string; size?: number; box?: number; round?: boolean }> = ({
  id,
  size = 18,
  box = 28,
  round,
}) => (
  <div
    style={{
      width: box,
      height: box,
      borderRadius: round ? 9999 : 6,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      flexShrink: 0,
    }}
  >
    <Icon id={id} size={size} />
  </div>
);

export const Screen: React.FC<{ children: React.ReactNode; bg?: string; style?: React.CSSProperties }> = ({
  children,
  bg = C.bg,
  style,
}) => (
  <div
    style={{
      position: "absolute",
      inset: 0,
      width: 1280,
      height: 720,
      background: bg,
      fontFamily: inter,
      color: C.text,
      overflow: "hidden",
      WebkitFontSmoothing: "antialiased",
      ...style,
    }}
  >
    {children}
  </div>
);

export const DevinMark: React.FC<{ size?: number; opacity?: number }> = ({ size = 16, opacity = 1 }) => (
  <Icon id="fb89d" w={size * (19.3579 / 21.9987)} h={size} style={{ opacity }} />
);

export const MacBadge: React.FC = () => (
  <div
    style={{
      background: C.blueTint,
      display: "flex",
      gap: 4,
      height: 20,
      alignItems: "center",
      padding: "2px 6px",
      borderRadius: 4,
      flexShrink: 0,
    }}
  >
    <Icon id="6188d" size={14} />
    <span style={{ ...T12, fontWeight: 500, color: C.blue, letterSpacing: -0.065 }}>macOS</span>
  </div>
);

export const SessionHeader: React.FC<{ title: string; width: number; showPanelToggle?: boolean }> = ({
  title,
  width,
  showPanelToggle = true,
}) => (
  <div
    style={{
      position: "absolute",
      left: 0,
      top: 0,
      width,
      height: 44,
      display: "flex",
      alignItems: "center",
      padding: "8px 7px 8px 12px",
      boxSizing: "border-box",
    }}
  >
    <IconButton id="74b9c" />
    <div style={{ display: "flex", alignItems: "center", marginLeft: 12, gap: 2 }}>
      <div style={{ padding: "4px 6px", ...T13, whiteSpace: "nowrap" }}>{title}</div>
      <MacBadge />
    </div>
    <div style={{ flex: 1 }} />
    <div style={{ display: "flex", gap: 1, alignItems: "center" }}>
      <IconButton id="be3ff" />
      <IconButton id="3a1cc" />
      <IconButton id="8e71e" size={16} />
      {showPanelToggle ? (
        <div style={{ marginLeft: 8 }}>
          <IconButton id="c8a98" />
        </div>
      ) : null}
    </div>
  </div>
);

export const Kbd: React.FC<{ id: string }> = ({ id }) => (
  <span
    style={{
      display: "inline-flex",
      width: 16,
      height: 16,
      borderRadius: 2,
      background: "rgba(0,0,0,0.06)",
      alignItems: "center",
      justifyContent: "center",
      verticalAlign: "-3px",
      margin: "0 1px",
    }}
  >
    <Icon id={id} size={12} />
  </span>
);

export const StopButton: React.FC = () => (
  <div
    style={{
      width: 28,
      height: 28,
      borderRadius: 9999,
      background: C.ink,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
    }}
  >
    <Icon id="ad966" size={18} />
  </div>
);

export const SendButton: React.FC<{ active: number; pressed?: number }> = ({ active, pressed = 0 }) => (
  <div
    style={{
      background: C.ink,
      height: 28,
      width: 54,
      borderRadius: 9999,
      display: "flex",
      opacity: 0.5 + active * 0.5,
      overflow: "hidden",
      transform: `scale(${1 - pressed * 0.06})`,
    }}
  >
    <div style={{ width: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
      <Icon id="bc3a8" size={18} />
    </div>
    <div style={{ width: 1, background: "rgba(255,255,255,0.08)" }} />
    <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", paddingRight: 1 }}>
      <Icon id="f856e" size={16} />
    </div>
  </div>
);

export const ChatInput: React.FC<{
  width: number;
  placeholder: React.ReactNode;
  model: string;
  working: boolean;
}> = ({ width, placeholder, model, working }) => (
  <div style={{ width, padding: "0 8px 8px", boxSizing: "border-box" }}>
    <div style={{ padding: "0 6px" }}>
      <div
        style={{
          background: "#fff",
          border: `0.8px solid ${C.border}`,
          borderRadius: 20,
          height: 107.6,
          padding: 12,
          boxSizing: "border-box",
          position: "relative",
        }}
      >
        <div style={{ padding: 4, ...T14, color: C.muted, whiteSpace: "nowrap" }}>{placeholder}</div>
        <div style={{ position: "absolute", left: 8, top: 62, display: "flex", gap: 1, alignItems: "center", padding: 4 }}>
          <IconButton id="2c01e" round />
          <IconButton id="38518" round />
          <div style={{ padding: "0 6px", ...T13, color: C.muted, whiteSpace: "nowrap" }}>{model}</div>
        </div>
        <div style={{ position: "absolute", right: 12, top: 66, display: "flex", gap: 4, alignItems: "center" }}>
          <IconButton id="11456" round />
          <IconButton id="70d60" round />
          {working ? <StopButton /> : <SendButton active={0} />}
        </div>
      </div>
    </div>
  </div>
);

export const Cursor: React.FC<{ x: number; y: number; opacity?: number; press?: number; scale?: number }> = ({
  x,
  y,
  opacity = 1,
  press = 0,
  scale = 1,
}) => (
  <div
    style={{
      position: "absolute",
      left: x - 1 * scale,
      top: y - 1 * scale,
      width: 12 * scale,
      height: 19 * scale,
      opacity,
      transformOrigin: "1px 1px",
      transform: `scale(${1 - press * 0.12})`,
      filter: "drop-shadow(0 1px 1.5px rgba(0,0,0,0.25))",
      pointerEvents: "none",
    }}
  >
    <Icon id="ec11e" w={12 * scale} h={19 * scale} />
  </div>
);

export const ClickRing: React.FC<{ x: number; y: number; t: number; color?: string }> = ({ x, y, t, color = C.blue }) =>
  t <= 0 || t >= 1 ? null : (
    <div
      style={{
        position: "absolute",
        left: x - 16,
        top: y - 16,
        width: 32,
        height: 32,
        borderRadius: 9999,
        border: `1.5px solid ${color}`,
        background: "rgba(51,125,244,0.12)",
        opacity: (1 - t) * 0.9,
        transform: `scale(${0.4 + t * 0.8})`,
      }}
    />
  );
