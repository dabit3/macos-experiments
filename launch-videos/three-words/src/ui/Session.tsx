import { Img, staticFile } from "remotion";
import { C, LH, LW } from "../theme";
import { Box, GithubIcon, Icon, MacBadge, Stroke, text } from "./primitives";

export const TITLE = "Create Otter Flappy Bird iOS App";
const CMD = "rgba(25,25,25,0.72)";

export const SessionHeader: React.FC<{ right: number; panelIcon?: boolean }> = ({ right, panelIcon = true }) => (
  <>
    <div style={{ position: "absolute", left: 12, top: 8 }}>
      <Box radius={6}>
        <Icon name="sidebar" size={18} />
      </Box>
    </div>
    <div style={{ position: "absolute", left: 52, top: 9, height: 26, display: "flex", alignItems: "center" }}>
      <div style={{ padding: "4px 6px" }}>
        <span style={text(13, 18)}>{TITLE}</span>
      </div>
      <MacBadge />
    </div>
    <div style={{ position: "absolute", left: right - 7 - (panelIcon ? 116 : 87), top: 8, display: "flex", gap: 1 }}>
      <Box radius={6}>
        <Icon name="hdr-list" size={18} />
      </Box>
      <Box radius={6}>
        <Icon name="hdr-flag" size={18} />
      </Box>
      <Box radius={6}>
        <Icon name="hdr-more" size={16} />
      </Box>
      {panelIcon ? (
        <Box radius={6}>
          <Icon name="hide-panel" size={18} />
        </Box>
      ) : null}
    </div>
  </>
);

export const UserBubble: React.FC<{ msg: string; opacity: number }> = ({ msg, opacity }) => (
  <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 8, paddingBottom: 20, opacity }}>
    <div
      style={{
        background: C.fill04,
        padding: "8px 14px",
        borderRadius: "16px 4px 16px 16px",
        maxWidth: 368,
        ...text(14, 20),
        whiteSpace: "normal",
      }}
    >
      {msg}
    </div>
    <div style={{ display: "flex", alignItems: "center", gap: 10, background: C.fill04, borderRadius: 12, padding: 6, paddingRight: 16, width: 188, boxSizing: "border-box" }}>
      <div style={{ width: 33, height: 33, borderRadius: 8, background: C.fill06, display: "flex", alignItems: "center", justifyContent: "center" }}>
        <GithubIcon size={16} />
      </div>
      <div style={{ display: "flex", flexDirection: "column" }}>
        <span style={text(13, 17, C.ink, 500)}>dabit3/experiments</span>
        <span style={text(12, 16, C.ink56, 400, 0)}>main</span>
      </div>
    </div>
  </div>
);

export const Para: React.FC<{ children: React.ReactNode; opacity?: number }> = ({ children, opacity = 1 }) => (
  <div style={{ ...text(14, 20), whiteSpace: "normal", paddingBottom: 20, opacity }}>{children}</div>
);

export const Streamed: React.FC<{ full: string; words: number }> = ({ full, words }) => {
  const parts = full.split(" ");
  return (
    <>
      {parts.map((w, i) => (
        <span key={i} style={{ opacity: Math.max(0, Math.min(1, words - i)) }}>
          {w}
          {i < parts.length - 1 ? " " : ""}
        </span>
      ))}
    </>
  );
};

export type Row = { kind: "cmd"; text: string; dur: string } | { kind: "thought"; text: string };

export const WorkBlock: React.FC<{ label: string; rows: Row[]; shown: number[]; clip?: boolean }> = ({ label, rows, shown }) => (
  <div style={{ paddingBottom: 12 }}>
    <div style={{ display: "flex", alignItems: "center", gap: 8, height: 18, paddingBottom: 8 }}>
      <Stroke size={16} d="M4.5 6.5 8 10l3.5-3.5" />
      <span style={text(13, 18, CMD)}>{label}</span>
    </div>
    <div style={{ marginLeft: 8, paddingLeft: 15.2, borderLeft: `0.8px solid ${C.line08}`, display: "flex", flexDirection: "column", gap: 8, paddingBottom: 4 }}>
      {rows.map((r, i) => {
        const o = shown[i] ?? 0;
        if (o <= 0) return null;
        return (
          <div key={i} style={{ display: "flex", gap: 12, opacity: o, transform: `translateY(${(1 - o) * 4}px)` }}>
            {r.kind === "cmd" ? (
              <>
                <span style={{ ...text(13, 18, CMD), whiteSpace: "normal", flex: 1 }}>{r.text}</span>
                <span style={text(13, 18, C.ink40)}>{r.dur}</span>
              </>
            ) : (
              <span style={{ display: "flex", alignItems: "center", gap: 6, ...text(13, 18, CMD) }}>
                {r.text}
                <Stroke size={14} d="M6.5 4.5 10 8l-3.5 3.5" />
              </span>
            )}
          </div>
        );
      })}
    </div>
  </div>
);

export const Status: React.FC<{ label: string; labelOpacity?: number }> = ({ label, labelOpacity = 1 }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 7, height: 18 }}>
    <Img src={staticFile("icons/logo-mark.svg")} style={{ width: 16, height: 18, objectFit: "contain" }} />
    <span style={{ ...text(13, 18, CMD), opacity: labelOpacity }}>{label}</span>
  </div>
);

export const STATUS_TEXT_DX = 23;

export const Guide: React.FC<{ x: number; w: number }> = ({ x, w }) => (
  <div
    style={{
      position: "absolute",
      left: x,
      top: LH - 8 - 107.6,
      width: w,
      height: 107.6,
      background: "#fff",
      border: `0.8px solid ${C.line08}`,
      borderRadius: 20,
      boxSizing: "border-box",
    }}
  >
    <div style={{ position: "absolute", left: 16, top: 16.6, display: "flex", alignItems: "center", ...text(14, 20, C.ink56) }}>
      Guide Devin while it works, or press
      <span style={{ display: "inline-flex", gap: 2, margin: "0 4px" }}>
        {["kbd-cmd", "kbd-enter"].map((k) => (
          <span key={k} style={{ width: 16, height: 16, borderRadius: 2, background: C.fill06, display: "inline-flex", alignItems: "center", justifyContent: "center" }}>
            <Icon name={k} size={12} />
          </span>
        ))}
      </span>
      to queue
    </div>
    <div style={{ position: "absolute", left: 8, top: 62, height: 36, display: "flex", alignItems: "center", gap: 1, padding: 4, boxSizing: "border-box" }}>
      <Box>
        <Icon name="plus" size={18} />
      </Box>
      <Box>
        <Icon name="slash" size={18} />
      </Box>
      <div style={{ height: 28, display: "flex", alignItems: "center", padding: "0 6px" }}>
        <span style={text(13, 18, C.ink56)}>Opus 5.5 (Preview)</span>
      </div>
    </div>
    <div style={{ position: "absolute", right: 12, top: 66.8, display: "flex", alignItems: "center", gap: 4 }}>
      <div style={{ width: 24, height: 28, position: "relative" }}>
        <div style={{ position: "absolute", left: 0, top: 0 }}>
          <Box>
            <Icon name="mic" size={18} />
          </Box>
        </div>
      </div>
      <Box>
        <Icon name="voice" size={18} />
      </Box>
      <Box bg={C.send}>
        <Icon name="stop" size={18} />
      </Box>
    </div>
  </div>
);

export const COL_FULL = { x: (LW - 692) / 2, w: 692 };
export const COL_SPLIT = { x: 24.5, w: 578 };
export const PANE = 629;
export const STATUS_Y = 528;

export const ComputerPane: React.FC<{ children: React.ReactNode; progress: number }> = ({ children, progress }) => {
  const x0 = PANE;
  const r = LW;
  return (
    <>
      <div style={{ position: "absolute", left: x0, top: 0, width: 0.8, height: LH, background: C.line08 }} />
      <div style={{ position: "absolute", left: x0 + 11, top: 8, display: "flex", gap: 2, alignItems: "center" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 2, padding: "3px 6px 3px 3px", borderRadius: 6 }}>
          <Box size={22}>
            <Icon name="tab-progress" size={16} />
          </Box>
          <span style={text(13, 18, C.ink56)}>Progress</span>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 2, padding: "3px 6px 3px 3px", borderRadius: 6, background: C.fill06 }}>
          <Box size={22}>
            <Icon name="tab-computer2" size={16} style={{ filter: "brightness(0.35)" }} />
          </Box>
          <span style={text(13, 18)}>Computer</span>
        </div>
        <Box radius={6}>
          <Icon name="tab-add" size={18} />
        </Box>
      </div>
      <div style={{ position: "absolute", left: r - 7 - 57, top: 8, display: "flex", gap: 1 }}>
        <Box radius={6}>
          <Icon name="full-width" size={16} />
        </Box>
        <Box radius={6}>
          <Icon name="hide-panel" size={18} />
        </Box>
      </div>
      <div style={{ position: "absolute", left: VNC.x, top: VNC.y, width: VNC.w, height: VNC.h, overflow: "hidden", background: "#000" }}>{children}</div>
      <div style={{ position: "absolute", left: x0 + 12.5, top: 630.5, width: r - x0 - 25, height: 8, background: "rgba(51,125,244,0.24)" }}>
        <div style={{ position: "absolute", left: `calc(${progress * 100}% - 2px)`, top: -2, width: 2, height: 12, background: C.blue }} />
      </div>
      <div style={{ position: "absolute", left: x0 + 12, top: 650.5, height: 28, display: "flex", alignItems: "center", gap: 4 }}>
        <Box radius={6}>
          <Stroke size={18} d="M13 8H3m4.5-4.5L3 8l4.5 4.5" />
        </Box>
        <Box radius={6}>
          <Stroke size={18} d="M3 8h10M8.5 3.5 13 8l-4.5 4.5" />
        </Box>
        <div style={{ height: 28, display: "flex", alignItems: "center", gap: 6, padding: "0 10px", borderRadius: 9999, border: `0.8px solid ${C.line08}`, marginLeft: 4, background: "#fff" }}>
          <div style={{ width: 8, height: 8, borderRadius: 9999, background: C.red }} />
          <span style={text(13, 18)}>Live</span>
        </div>
      </div>
      <div style={{ position: "absolute", left: r - 12 - 118, top: 650.5, height: 28, display: "flex", alignItems: "center", gap: 4 }}>
        <Box radius={6}>
          <Stroke size={17} d="M6.5 4.3 9.5 2v12L5.2 10.5H2.5v-5h2.7M1.5 1.5l13 13" />
        </Box>
        <div style={{ display: "flex", alignItems: "center", gap: 4, padding: "0 4px" }}>
          <span style={text(13, 18, C.ink56)}>Auto</span>
          <Icon name="chevron-down-14" size={14} />
        </div>
        <Box radius={6}>
          <Stroke size={17} d="M9.5 2.5h4v4M13.5 2.5 8 8M6.5 3.5h-3a1 1 0 0 0-1 1v8a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1v-3" />
        </Box>
      </div>
    </>
  );
};

export const VNC = { x: PANE + 8, y: 124, w: LW - PANE - 16, h: ((LW - PANE - 16) * 656) / 874 };
