import { Pointer } from "./glyphs";
import { OffthreadVideo, Sequence, staticFile } from "remotion";
import { easeInOutQuint, easeOutCubic, mix, ramp } from "../ease";
import { FOOTAGE_START, FPS, T } from "../timeline";
import { ComposerBox, ComposerToolbar, DevinMark, Kbd } from "./Composer";
import { Icon } from "./Icon";
import { ChevronDown, ChevronRight, Clock, Laptop, ProgressDoc } from "./glyphs";
import { C, t13, t14, UI_H, UI_W } from "./tokens";
import { PROMPT } from "./typing";

const PANE_LEFT_W = UI_W * 0.5225;
const ROW = 26.8;

type Item = { at: number; kind: "row" | "cmd" | "thought" | "wait" | "status"; text: string; meta?: string; until?: number };

const ITEMS: Item[] = [
  { at: T.rows, kind: "row", text: "Worked for 38s" },
  { at: T.rows + 14, kind: "thought", text: "Thought for 6s" },
  { at: T.rows + 26, kind: "cmd", text: "uname -a; ls ~ ~/repos 2>/dev/null; which xcodebuild xcrun xcodegen; xcodebuild -version", meta: "11s" },
  { at: T.rows + 38, kind: "cmd", text: "cd ~/repos/experiments && git status -sb && git log --oneline -5 && ls", meta: "6s" },
  { at: T.rows + 50, kind: "thought", text: "Thought for 4s" },
  { at: T.rows + 62, kind: "cmd", text: "brew install xcodegen && xcodegen generate --spec ios-otter-flap/project.yml" },
  { at: T.status - 6, kind: "wait", text: "Waiting for iOS simulator runtime download (120s)" },
  { at: T.pushIn - 40, kind: "cmd", text: "xcodebuild -project OtterFlap.xcodeproj -scheme OtterFlap -sdk iphonesimulator build", meta: "48s" },
  { at: T.pushIn - 24, kind: "cmd", text: "xcrun simctl boot 'iPhone 17' && xcrun simctl install booted build/OtterFlap.app" },
];

const STATUS: { at: number; text: string }[] = [
  { at: T.status, text: "Preparing iOS build tools" },
  { at: T.pushIn - 10, text: "Testing Otter Flap in the iOS Simulator" },
];

const HeaderButton: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div style={{ width: 28, height: 28, borderRadius: 6, display: "flex", alignItems: "center", justifyContent: "center" }}>{children}</div>
);

const Tab: React.FC<{ icon: React.ReactNode; label: string; active?: boolean }> = ({ icon, label, active }) => (
  <div
    style={{
      height: 28,
      borderRadius: 6,
      padding: "3px 6px 3px 3px",
      boxSizing: "border-box",
      display: "flex",
      alignItems: "center",
      gap: 2,
      background: active ? C.active : "transparent",
    }}
  >
    <div style={{ width: 22, height: 22, display: "flex", alignItems: "center", justifyContent: "center" }}>{icon}</div>
    <div style={{ ...t13, color: active ? C.text : C.muted }}>{label}</div>
  </div>
);

const Reveal: React.FC<{ frame: number; at: number; height: number; children: React.ReactNode }> = ({ frame, at, height, children }) => {
  const t = ramp(frame, at, at + 16, easeInOutQuint);
  if (t <= 0) return null;
  return (
    <div style={{ height: height * t, overflow: "visible" }}>
      <div style={{ opacity: ramp(frame, at + 3, at + 18, easeOutCubic), transform: `translateY(${(1 - ramp(frame, at, at + 20, easeOutCubic)) * 5}px)` }}>{children}</div>
    </div>
  );
};

const oneLine: React.CSSProperties = { whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", minWidth: 0 };

const ItemRow: React.FC<{ item: Item }> = ({ item }) => {
  if (item.kind === "row") {
    return (
      <div style={{ height: ROW, display: "flex", alignItems: "center", gap: 8 }}>
        <ChevronRight size={16} />
        <div style={{ ...t13, fontSize: 14, color: C.muted }}>{item.text}</div>
      </div>
    );
  }
  if (item.kind === "wait") {
    return (
      <div style={{ height: ROW, display: "flex", alignItems: "center", gap: 8 }}>
        <Clock size={16} />
        <div style={{ ...t14, color: C.muted, ...oneLine }}>{item.text}</div>
      </div>
    );
  }
  return (
    <div style={{ height: ROW, display: "flex", alignItems: "center", marginLeft: 7.6, borderLeft: `0.8px solid ${C.border}`, paddingLeft: 15.6 }}>
      <div style={{ ...t14, color: item.kind === "cmd" ? "rgba(25,25,25,0.72)" : C.muted, ...oneLine }}>{item.text}</div>
      {item.kind === "thought" && <span style={{ marginLeft: 6, display: "flex" }}><ChevronRight size={14} /></span>}
      {item.meta && <div style={{ ...t14, color: C.muted, marginLeft: 8, flexShrink: 0 }}>{item.meta}</div>}
    </div>
  );
};

export const Taps: { f: number }[] = [1196, 1226, 1249, 1281, 1302, 1333, 1360, 1384, 1411, 1430].map((f) => ({ f }));
const TAP_X = 0.517;
const TAP_Y = 0.63;

const TapOverlay: React.FC<{ frame: number; w: number; h: number }> = ({ frame, w, h }) => {
  const shown = ramp(frame, 1180, 1196, easeOutCubic) * (1 - ramp(frame, T.zoomOut + 20, T.zoomOut + 36, easeOutCubic));
  if (shown <= 0) return null;
  const x = TAP_X * w;
  const y = TAP_Y * h;
  return (
    <div style={{ position: "absolute", inset: 0, opacity: shown }}>
      {Taps.map(({ f }) => {
        const p = (frame - f) / 22;
        if (p < 0 || p > 1) return null;
        const e = easeOutCubic(p);
        return (
          <div
            key={f}
            style={{
              position: "absolute",
              left: x - 11,
              top: y - 11,
              width: 22,
              height: 22,
              borderRadius: 9999,
              background: `rgba(96,165,250,${0.35 * (1 - p)})`,
              border: `1.2px solid rgba(96,165,250,${0.9 * (1 - p)})`,
              transform: `scale(${0.5 + 0.9 * e})`,
            }}
          />
        );
      })}
      <Pointer style={{ position: "absolute", left: x - 3, top: y - 2, width: 14, height: 16 }} />
    </div>
  );
};

export const ComputerPane: React.FC<{ frame: number; width: number }> = ({ frame, width }) => {
  const fw = width - 17.6;
  const fh = (fw * 656) / 876;
  const top = 340.3 - fh / 2;
  const bootFrom = Math.round((44.8 - FOOTAGE_START) * FPS);
  const playFrom = Math.round((51.8 - FOOTAGE_START) * FPS);
  return (
    <div style={{ position: "absolute", inset: 0 }}>
      <div style={{ position: "absolute", left: 8.8, top, width: fw, height: fh, overflow: "hidden", background: "#000" }}>
        <Sequence from={T.paneOpen} durationInFrames={T.pushIn - T.paneOpen} layout="none">
          <OffthreadVideo src={staticFile("footage/desktop.mp4")} startFrom={bootFrom} muted style={{ width: fw, height: fh, display: "block" }} />
        </Sequence>
        <Sequence from={T.pushIn} layout="none">
          <OffthreadVideo src={staticFile("footage/desktop.mp4")} startFrom={playFrom} muted style={{ width: fw, height: fh, display: "block" }} />
        </Sequence>
        <TapOverlay frame={frame} w={fw} h={fh} />
      </div>
      <div style={{ position: "absolute", left: 12.9, right: 11.5, top: 630.6, height: 9.2, borderRadius: 2, background: "rgba(51,125,244,0.22)" }}>
        <div style={{ position: "absolute", right: 0, top: -1.5, width: 2, height: 12.2, borderRadius: 1, background: C.blue }} />
      </div>
      <div style={{ position: "absolute", left: 12.9, right: 11.5, top: 650.5, height: 27.6, display: "flex", alignItems: "center" }}>
        <HeaderButton>
          <svg width={18} height={18} viewBox="0 0 18 18" fill="none">
            <path d="M14.25 9H3.75M3.75 9l4.5-4.5M3.75 9l4.5 4.5" stroke={C.muted} strokeWidth={1.125} strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </HeaderButton>
        <div style={{ width: 4 }} />
        <HeaderButton>
          <svg width={18} height={18} viewBox="0 0 18 18" fill="none">
            <path d="M3.75 9h10.5M14.25 9l-4.5-4.5M14.25 9l-4.5 4.5" stroke={C.muted} strokeWidth={1.125} strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </HeaderButton>
        <div style={{ width: 8 }} />
        <div style={{ height: 27.6, boxSizing: "border-box", borderRadius: 9999, border: `0.8px solid ${C.border}`, background: C.surface, padding: "0 10px 0 9px", display: "flex", alignItems: "center", gap: 6 }}>
          <div style={{ width: 7, height: 7, borderRadius: 9999, background: C.red }} />
          <div style={{ ...t13, fontSize: 14, color: C.muted }}>Live</div>
        </div>
        <div style={{ flex: 1 }} />
        <HeaderButton>
          <svg width={18} height={18} viewBox="0 0 18 18" fill="none">
            <path d="M5.5 6.4l6.4-3v11.2l-6.4-3H3.6V6.4zM2.5 2.5l13 13" stroke={C.muted} strokeWidth={1.125} strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </HeaderButton>
        <div style={{ ...t13, fontSize: 14, color: C.muted, display: "flex", alignItems: "center", gap: 4, padding: "0 6px" }}>
          Auto <ChevronDown size={14} />
        </div>
        <HeaderButton>
          <Icon name="expand" size={18} />
        </HeaderButton>
      </div>
    </div>
  );
};

export const Session: React.FC<{ frame: number }> = ({ frame }) => {
  const open = ramp(frame, T.paneOpen, T.paneOpen + 40, easeInOutQuint);
  const leftW = mix(UI_W, PANE_LEFT_W, open);
  const X = Math.max(24.5, (leftW - 692) / 2);
  const contentW = Math.min(692, leftW - 49);
  const enter = ramp(frame, T.session, T.session + 10, easeOutCubic);
  const statusIdx = STATUS.filter((s) => frame >= s.at).length - 1;
  const status = statusIdx >= 0 ? STATUS[statusIdx] : null;

  return (
    <div style={{ position: "absolute", inset: 0, background: C.page, opacity: enter }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: leftW, height: UI_H, overflow: "hidden" }}>
        <div style={{ position: "absolute", left: 12, top: 8 }}>
          <HeaderButton>
            <Icon name="sidebar" size={18} />
          </HeaderButton>
        </div>
        <div style={{ position: "absolute", left: 58, top: 8, height: 28, display: "flex", alignItems: "center", gap: 8 }}>
          <div style={{ ...t13, color: C.text, whiteSpace: "nowrap" }}>Create Otter Flappy Bird iOS App</div>
          <div style={{ height: 20, borderRadius: 4, background: C.blueTint, display: "flex", alignItems: "center", gap: 4, padding: "0 5px" }}>
            <Laptop size={14} />
            <div style={{ ...t13, color: C.blue }}>macOS</div>
          </div>
        </div>
        <div style={{ position: "absolute", right: 7, top: 8, display: "flex", gap: 1 }}>
          <HeaderButton>
            <Icon name="session-info" size={18} />
          </HeaderButton>
          <HeaderButton>
            <Icon name="flag" size={18} />
          </HeaderButton>
          <HeaderButton>
            <Icon name="dots" size={18} />
          </HeaderButton>
        </div>

        <div style={{ position: "absolute", left: X, top: 60, width: contentW }}>
          <div style={{ display: "flex", justifyContent: "flex-end", paddingBottom: 20 }}>
            <div
              style={{
                maxWidth: Math.min(560, contentW * 0.8),
                boxSizing: "border-box",
                background: "rgba(0,0,0,0.04)",
                borderRadius: "16px 4px 16px 16px",
                padding: "8px 14px",
                ...t14,
                color: C.text,
              }}
            >
              {PROMPT}
            </div>
          </div>
          <Reveal frame={frame} at={T.reply} height={58}>
            <div style={{ ...t14, color: C.text }}>
              On it — building an otter Flappy Bird iOS game (likely in dabit3/experiments), then building and testing it on the iOS simulator.
            </div>
          </Reveal>
          {ITEMS.map((item) => (
            <Reveal key={item.at} frame={frame} at={item.at} height={ROW + (item.kind === "row" ? 0 : 0)}>
              <ItemRow item={item} />
            </Reveal>
          ))}
          {status && (
            <div style={{ height: ROW + 8, display: "flex", alignItems: "flex-end", opacity: ramp(frame, T.status, T.status + 14, easeOutCubic) }}>
              <div style={{ height: ROW, display: "flex", alignItems: "center", gap: 8 }}>
                <DevinMark height={15} style={{ margin: "0 1px" }} />
                <div
                  key={status.text}
                  style={{ ...t14, color: C.text, opacity: ramp(frame, status.at, status.at + 12, easeOutCubic) }}
                >
                  {status.text}
                </div>
              </div>
            </div>
          )}
        </div>

        <div style={{ position: "absolute", left: X - 10.5, bottom: 8, width: contentW + 21 }}>
          <ComposerBox width="100%" height={107.6} toolbar={<ComposerToolbar model="Opus 5.5" running />}>
            <span style={{ color: C.muted }}>
              Guide Devin while it works, or press
              <Kbd name="kbd-cmd" />
              <Kbd name="kbd-enter" />
              to queue
            </span>
          </ComposerBox>
        </div>
      </div>

      {open > 0 && (
        <div style={{ position: "absolute", left: leftW, top: 0, width: UI_W - PANE_LEFT_W, height: UI_H, borderLeft: `0.8px solid ${C.hairline}`, background: C.page }}>
          <div style={{ opacity: ramp(frame, T.paneOpen + 10, T.paneOpen + 36, easeOutCubic), position: "absolute", inset: 0 }}>
            <div style={{ position: "absolute", left: 8, top: 8, display: "flex", gap: 4, alignItems: "center" }}>
              <Tab icon={<ProgressDoc />} label="Progress" />
              <Tab icon={<Icon name="computer" size={16} />} label="Computer" active />
              <HeaderButton>
                <Icon name="plus" size={18} />
              </HeaderButton>
            </div>
            <div style={{ position: "absolute", right: 7, top: 8, display: "flex", gap: 4 }}>
              <HeaderButton>
                <Icon name="expand" size={18} />
              </HeaderButton>
              <HeaderButton>
                <Icon name="panel" size={18} />
              </HeaderButton>
            </div>
            <ComputerPane frame={frame} width={UI_W - PANE_LEFT_W} />
          </div>
        </div>
      )}
    </div>
  );
};
