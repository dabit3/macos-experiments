import { Img, staticFile } from "remotion";
import { Icon } from "./Icon";
import { ArrowUp, ChevronDown, Sliders } from "./glyphs";
import { C, t13, t14 } from "./tokens";

const IconButton: React.FC<{ children: React.ReactNode; round?: boolean }> = ({ children, round }) => (
  <div style={{ width: 28, height: 28, borderRadius: round ? 9999 : 6, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
    {children}
  </div>
);

export const ComposerToolbar: React.FC<{ model: string; sendActive?: boolean; running?: boolean; pressSend?: number }> = ({
  model,
  sendActive,
  running,
  pressSend = 0,
}) => (
  <div style={{ display: "flex", alignItems: "center", height: 28 }}>
    <IconButton>
      <Icon name="plus" size={18} />
    </IconButton>
    <div style={{ width: 1 }} />
    <IconButton>
      <Icon name="slash" size={18} />
    </IconButton>
    {!running && (
      <>
        <div style={{ width: 2.5 }} />
        <IconButton>
          <div style={{ position: "relative" }}>
            <Sliders />
            <div style={{ position: "absolute", right: -1.5, top: -1.5, width: 6.5, height: 6.5, borderRadius: 9999, background: C.blue }} />
          </div>
        </IconButton>
      </>
    )}
    <div style={{ ...t13, color: C.muted, padding: "0 6px", marginLeft: running ? 2 : 3, whiteSpace: "nowrap" }}>{model}</div>
    <div style={{ flex: 1 }} />
    <IconButton round>
      <Icon name="mic" size={18} />
    </IconButton>
    <IconButton round>
      <Icon name="voice" size={18} />
    </IconButton>
    <div style={{ width: 6 }} />
    {running ? (
      <div style={{ width: 28, height: 28, borderRadius: 9999, background: C.text, display: "flex", alignItems: "center", justifyContent: "center" }}>
        <Icon name="stop" size={18} />
      </div>
    ) : (
      <div
        style={{
          height: 28,
          borderRadius: 9999,
          background: sendActive ? C.text : "rgba(25,25,25,0.56)",
          display: "flex",
          alignItems: "center",
          transform: `scale(${1 - 0.06 * pressSend})`,
        }}
      >
        <div style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <ArrowUp />
        </div>
        <div style={{ width: 0.8, height: 28, background: "rgba(255,255,255,0.18)" }} />
        <div style={{ width: 25, height: 28, display: "flex", alignItems: "center", justifyContent: "center", paddingRight: 2 }}>
          <ChevronDown size={14} color="#fff" />
        </div>
      </div>
    )}
  </div>
);

export const ComposerBox: React.FC<{
  width: number | string;
  height: number;
  children: React.ReactNode;
  toolbar: React.ReactNode;
}> = ({ width, height, children, toolbar }) => (
  <div
    style={{
      width,
      height,
      boxSizing: "border-box",
      background: C.surface,
      border: `0.8px solid ${C.border}`,
      borderRadius: 20,
      padding: 12,
      display: "flex",
      flexDirection: "column",
      boxShadow: "0 1px 2px rgba(0,0,0,0.03)",
    }}
  >
    <div style={{ flex: 1, padding: 4, ...t14, color: C.text }}>{children}</div>
    {toolbar}
  </div>
);

export const Kbd: React.FC<{ name: "kbd-cmd" | "kbd-enter" }> = ({ name }) => (
  <span
    style={{
      display: "inline-flex",
      width: 18,
      height: 18,
      margin: "0 3px",
      verticalAlign: -3.5,
      borderRadius: 4,
      background: C.hover,
      alignItems: "center",
      justifyContent: "center",
    }}
  >
    <Icon name={name} size={12} />
  </span>
);

export const DevinMark: React.FC<{ height: number; style?: React.CSSProperties }> = ({ height, style }) => (
  <Img src={staticFile("brand/mark.png")} style={{ height, width: (height * 657) / 752, display: "block", ...style }} />
);
