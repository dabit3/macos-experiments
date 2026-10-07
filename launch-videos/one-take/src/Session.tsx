import React from "react";
import { C, WIN } from "./tokens";
import { sans } from "./fonts";
import { ArrowLeft, ArrowRight, Branch, Chevron, DevinMark, FIcon, Flag, Laptop, ListIcon, More, Popout, ProgressIcon, SidebarLeft, Unhand } from "./icons";
import { PROMPT, T } from "./timeline";
import { HOME } from "./Home";
import { HOME_FONT } from "./PromptBox";
import { easeOut, fadeIn, mix, prog } from "./anim";
import { measure } from "./measure";

export const COL_W = 590;
export const SPLIT_LEFT = 629;
export const RIGHT_W = WIN.w - SPLIT_LEFT - 1;
export const CHAT_TOP = 64;

const ROWS: { text: string; dur?: string; thought?: boolean }[] = [
  { text: "uname -a; xcodebuild -version; xcrun simctl list devices available | head", dur: "11s" },
  { text: "Thought for 5s", thought: true },
  { text: "cd ~/repos/experiments && mkdir ios-otter-flap && cd ios-otter-flap && xcodegen generate", dur: "6s" },
  { text: "Thought for 4s", thought: true },
  {
    text: "xcodebuild -project OtterFlap.xcodeproj -scheme OtterFlap -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build",
    dur: "24s",
  },
];

const statusText = (t: number) => {
  if (t < T.boot + 0.4) return "Preparing iOS build tools";
  if (t < T.gameStart) return "Booting iPhone 17 Simulator";
  if (t < T.toPlayer) return "Testing Otter Flap in the Simulator";
  return "Reviewing the test recording";
};

const reveal = (t: number, start: number, dy = 6): React.CSSProperties => {
  const v = fadeIn(t, start, 0.45);
  return { opacity: v, transform: `translateY(${(1 - v) * dy}px)` };
};

export const bubbleWidth = () => measure(PROMPT, `400 14px ${sans}`) + 28;

export const Session: React.FC<{ t: number; p: number; leftW: number }> = ({ t, p, leftW }) => {
  const colLeft = (leftW - COL_W) / 2;
  const headerIn = prog(t, T.toSession + T.sessionDur * 0.35, 0.5);
  const bw = bubbleWidth();
  const bx = colLeft + COL_W - bw;
  const startX = HOME.box.x + 16.6 - 14;
  const startY = HOME.box.y + 15.2 - 8 + 1;
  const bp = easeOut(Math.min(1, Math.max(0, (t - T.toSession) / T.sessionDur)));
  const bubbleX = mix(startX, bx, bp);
  const bubbleY = mix(startY, CHAT_TOP, bp);
  const bubbleBg = prog(t, T.toSession + 0.1, 0.5);
  const status = statusText(t);
  const pulse = 0.55 + 0.45 * Math.cos(t * 4.2);

  return (
    <div style={{ position: "absolute", inset: 0, fontFamily: sans, color: C.ink }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: leftW, height: 44, opacity: headerIn }}>
        <div style={{ position: "absolute", left: 16, top: 13 }}>
          <SidebarLeft size={18} />
        </div>
        <div style={{ position: "absolute", left: 58, top: 12, display: "flex", alignItems: "center", gap: 8 }}>
          <span style={{ fontSize: 14, lineHeight: "20px", letterSpacing: "-0.07px" }}>Create Otter Flappy Bird iOS App</span>
          <span
            style={{
              display: "flex",
              alignItems: "center",
              gap: 4,
              height: 20,
              padding: "0 6px 0 5px",
              borderRadius: 4,
              background: C.badgeBg,
              color: C.badgeInk,
              fontSize: 13,
              letterSpacing: "-0.065px",
            }}
          >
            <Laptop size={14} color={C.badgeInk} stroke={1.3} />
            macOS
          </span>
        </div>
        <div style={{ position: "absolute", right: leftW > 900 ? 16 : 10, top: 8, display: "flex", gap: 1 }}>
          {[<ListIcon key="l" />, <Flag key="f" />, <More key="m" />].map((el, i) => (
            <div key={i} style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
              {el}
            </div>
          ))}
          <div style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center", opacity: leftW > 900 ? 1 : 0, marginLeft: 4 }}>
            <FIcon name="tabs_c8a98" size={18} />
          </div>
        </div>
      </div>

      <div
        style={{
          position: "absolute",
          left: bubbleX,
          top: bubbleY,
          width: bw,
          boxSizing: "border-box",
          padding: "8px 14px",
          borderRadius: "16px 4px 16px 16px",
          background: `rgba(0,0,0,${0.04 * bubbleBg})`,
          fontSize: mix(HOME_FONT, 14, bp),
          lineHeight: "20px",
          letterSpacing: "-0.07px",
          whiteSpace: "nowrap",
          opacity: t < T.toSession ? 0 : 1,
        }}
      >
        {PROMPT}
      </div>
      <div
        style={{
          position: "absolute",
          top: CHAT_TOP + 44,
          left: colLeft + COL_W - 150,
          width: 150,
          display: "flex",
          justifyContent: "flex-end",
          ...reveal(t, T.repoChip, 4),
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 5, height: 24, padding: "0 9px 0 7px", borderRadius: 999, background: C.fill, fontSize: 12, color: C.muted }}>
          <Branch size={13} />
          dabit3/experiments
        </div>
      </div>

      <div style={{ position: "absolute", left: colLeft, top: CHAT_TOP + 92, width: COL_W, display: "flex", flexDirection: "column" }}>
        <div style={{ fontSize: 14, lineHeight: "20px", letterSpacing: "-0.07px", ...reveal(t, T.reply) }}>
          On it — building an otter Flappy Bird iOS game in dabit3/experiments, then building and testing it on the iOS simulator.
        </div>
        <div style={{ height: 18 }} />
        <div style={{ display: "flex", alignItems: "center", gap: 8, height: 18, fontSize: 13, color: C.muted, letterSpacing: "-0.065px", ...reveal(t, T.worked) }}>
          <Chevron size={15} />
          Worked for 38s
        </div>
        <div style={{ height: 10 }} />
        <div style={{ position: "relative", paddingLeft: 22, display: "flex", flexDirection: "column", gap: 12 }}>
          <div
            style={{
              position: "absolute",
              left: 7,
              top: 0,
              width: 0.8,
              background: C.hairline,
              height: `${fadeIn(t, T.rows, 1.1) * 100}%`,
            }}
          />
          {ROWS.map((r, i) => (
            <div key={i} style={{ display: "flex", gap: 14, fontSize: 13, lineHeight: "18px", letterSpacing: "-0.065px", color: C.muted, ...reveal(t, T.rows + i * 0.17, 4) }}>
              <div style={{ flex: r.thought ? undefined : 1, display: "flex", alignItems: "center", gap: 4 }}>
                {r.text}
                {r.thought ? <Chevron dir="right" size={14} /> : null}
              </div>
              {r.dur ? <div style={{ color: C.faint, whiteSpace: "nowrap" }}>{r.dur}</div> : null}
            </div>
          ))}
        </div>
        <div style={{ height: 22 }} />
        <div style={{ display: "flex", alignItems: "center", gap: 8, height: 20, fontSize: 14, color: C.muted, letterSpacing: "-0.07px", ...reveal(t, T.status) }}>
          <DevinMark size={16} style={{ opacity: pulse }} />
          {status}
        </div>
      </div>
      <div style={{ position: "absolute", left: 0, top: 0, width: 0, height: 0, opacity: p }} />
    </div>
  );
};

export const RightPane: React.FC<{ t: number; x: number }> = ({ t, x }) => {
  const live = 0.7 + 0.3 * Math.cos(t * 3);
  return (
    <div style={{ position: "absolute", left: x, top: 0, width: RIGHT_W + 1, height: WIN.h, fontFamily: sans, background: C.page }}>
      <div style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: 1, background: "#F0F0F0" }} />
      <div style={{ position: "absolute", left: 9, top: 8, height: 28, display: "flex", alignItems: "center", gap: 4 }}>
        {[
          { label: "Progress", icon: <ProgressIcon size={16} />, sel: false },
          { label: "Computer", icon: <FIcon name="tabs_4dc82" size={16} />, sel: true },
        ].map((tab) => (
          <div
            key={tab.label}
            style={{
              height: 28,
              display: "flex",
              alignItems: "center",
              gap: 2,
              padding: "3px 6px 3px 3px",
              boxSizing: "border-box",
              borderRadius: 6,
              background: tab.sel ? C.fillStrong : "transparent",
              fontSize: 13,
              letterSpacing: "-0.065px",
              color: tab.sel ? C.ink : C.muted,
            }}
          >
            <div style={{ width: 22, height: 22, display: "flex", alignItems: "center", justifyContent: "center" }}>{tab.icon}</div>
            {tab.label}
          </div>
        ))}
        <div style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <FIcon name="tabs_2c01e" size={18} />
        </div>
      </div>
      <div style={{ position: "absolute", right: 8, top: 8, display: "flex", gap: 4 }}>
        {["tabs_88457", "tabs_c8a98"].map((k) => (
          <div key={k} style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <FIcon name={k} size={18} />
          </div>
        ))}
      </div>
      <div style={{ position: "absolute", left: 13, right: 9, top: 628, height: 9, borderRadius: 2, background: C.track }}>
        <div style={{ position: "absolute", right: -1, top: -2, bottom: -2, width: 2, background: C.blue, borderRadius: 1 }} />
      </div>
      <div style={{ position: "absolute", left: 13, right: 13, top: 648, height: 32, display: "flex", alignItems: "center", gap: 6, fontSize: 14, color: C.ink }}>
        <div style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <ArrowLeft size={18} />
        </div>
        <div style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <ArrowRight size={18} />
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 6, height: 30, padding: "0 11px 0 10px", borderRadius: 999, boxShadow: "0 0 0 0.8px rgba(0,0,0,0.08)", background: C.white, marginLeft: 2 }}>
          <div style={{ width: 8, height: 8, borderRadius: 4, background: C.red, opacity: live }} />
          Live
        </div>
        <div style={{ flex: 1 }} />
        <Unhand size={18} />
        <div style={{ display: "flex", alignItems: "center", gap: 3, color: C.muted, fontSize: 14, margin: "0 12px 0 14px" }}>
          Auto
          <Chevron size={14} />
        </div>
        <Popout size={18} />
      </div>
    </div>
  );
};
