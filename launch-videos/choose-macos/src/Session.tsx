import React from "react";
import { C, FONT, SCREEN, T, VH, VW } from "./theme";
import { ArrowIcon, ChevronRight, Icon, IconBox, LaptopIcon, ProgressIcon, SidebarIcon } from "./Icon";
import { prog, easeOut } from "./anim";

export const LEFT_W = 629;
const ROW = { fontSize: 14, lineHeight: "18px", letterSpacing: -0.07 };
export const PROMPT_TEXT = "Build Flappy Bird with an Otter. Then build and test it on iOS.";

type Row = { at: number; kind: "cmd" | "thought"; text: string; dur?: string };

export type SessionScript = {
  bubble: number;
  reply: number;
  worked: number;
  rows: Row[];
  status: { at: number; text: string }[];
};

const Appear: React.FC<{ frame: number; at: number; maxH?: number; children: React.ReactNode }> = ({ frame, at, maxH = 90, children }) => {
  const p = prog(frame, at, at + 22, easeOut);
  if (p <= 0) return null;
  return (
    <div style={{ maxHeight: p >= 1 ? undefined : maxH * p, overflow: p >= 1 ? undefined : "hidden" }}>
      <div style={{ opacity: p, transform: `translateY(${(1 - p) * 6}px)` }}>{children}</div>
    </div>
  );
};

const Header: React.FC = () => (
  <div style={{ position: "absolute", left: 0, top: 0, width: LEFT_W, height: 44, display: "flex", alignItems: "center", padding: "0 7px 0 16px", boxSizing: "border-box" }}>
    <SidebarIcon size={18} />
    <div style={{ ...T.t13, color: C.text, marginLeft: 24 }}>Create Otter Flappy Bird iOS App</div>
    <div
      style={{
        marginLeft: 7,
        height: 20,
        padding: "0 6px 0 5px",
        borderRadius: 5,
        background: C.badgeBg,
        display: "flex",
        alignItems: "center",
        gap: 4,
      }}
    >
      <LaptopIcon size={14} color={C.badgeText} />
      <div style={{ ...T.t13, color: C.badgeText }}>macOS</div>
    </div>
    <div style={{ flex: 1 }} />
    <IconBox icon="list" iconSize={18} radius={6} />
    <div style={{ width: 1 }} />
    <IconBox icon="flag" iconSize={18} radius={6} />
    <div style={{ width: 1 }} />
    <IconBox icon="dots" iconSize={18} radius={6} />
  </div>
);

const Tab: React.FC<{ icon: React.ReactNode; label: string; active?: boolean }> = ({ icon, label, active }) => (
  <div
    style={{
      height: 28,
      display: "flex",
      alignItems: "center",
      gap: 2,
      padding: "3px 6px 3px 3px",
      boxSizing: "border-box",
      borderRadius: 6,
      background: active ? C.fill06 : undefined,
    }}
  >
    <div style={{ width: 22, height: 22, display: "flex", alignItems: "center", justifyContent: "center" }}>{icon}</div>
    <div style={{ ...T.t13, color: active ? C.text : C.text56 }}>{label}</div>
  </div>
);

const RightChrome: React.FC = () => (
  <>
    <div style={{ position: "absolute", left: LEFT_W + 0.8, right: 0, top: 0, height: 44, display: "flex", alignItems: "center", padding: "0 8px", gap: 4, boxSizing: "border-box" }}>
      <Tab icon={<ProgressIcon size={16} />} label="Progress" />
      <Tab icon={<Icon name="computer" size={16} />} label="Computer" active />
      <IconBox icon="plus-18" iconSize={18} radius={6} />
      <div style={{ flex: 1 }} />
      <IconBox icon="expand" iconSize={18} radius={6} />
      <IconBox icon="panel" iconSize={18} radius={6} />
    </div>
    <div style={{ position: "absolute", left: SCREEN.x + 3, width: SCREEN.w - 6, top: VH - 60, height: 10, borderRadius: 3, background: "#ccddfb" }}>
      <div style={{ position: "absolute", right: 0, top: -2, width: 3, height: 14, borderRadius: 1, background: C.blue }} />
    </div>
    <div style={{ position: "absolute", left: SCREEN.x + 4, right: 8, top: VH - 40, height: 28, display: "flex", alignItems: "center", gap: 4 }}>
      <div style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
        <ArrowIcon size={18} dir="left" />
      </div>
      <div style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
        <ArrowIcon size={18} dir="right" />
      </div>
      <div
        style={{
          marginLeft: 4,
          height: 28,
          padding: "0 10px",
          borderRadius: 9999,
          border: `0.8px solid ${C.border08}`,
          display: "flex",
          alignItems: "center",
          gap: 6,
          boxSizing: "border-box",
          background: "#fff",
        }}
      >
        <div style={{ width: 8, height: 8, borderRadius: 9999, background: C.red }} />
        <div style={{ ...T.t13, color: C.text }}>Live</div>
      </div>
      <div style={{ flex: 1 }} />
      <div style={{ ...T.t13, color: C.text56 }}>Auto</div>
      <Icon name="chevron-14" size={14} />
      <div style={{ width: 8 }} />
    </div>
  </>
);

const Input: React.FC = () => (
  <div
    style={{
      position: "absolute",
      left: 14,
      width: LEFT_W - 28,
      bottom: 8,
      height: 107.6,
      boxSizing: "border-box",
      background: "#fff",
      border: `0.8px solid ${C.border08}`,
      borderRadius: 20,
      padding: 12,
    }}
  >
    <div style={{ padding: 4, display: "flex", alignItems: "center", ...T.t14, color: C.text56 }}>
      Guide Devin while it works, or press
      <div style={{ display: "flex", gap: 2, margin: "0 4px" }}>
        {["cmd-key", "return-key"].map((k) => (
          <div key={k} style={{ width: 16, height: 16, borderRadius: 2, background: C.fill06, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <Icon name={k} size={12} />
          </div>
        ))}
      </div>
      to queue
    </div>
    <div style={{ position: "absolute", left: 12, right: 12, bottom: 12, height: 28, display: "flex", alignItems: "center" }}>
      <IconBox icon="plus-in" iconSize={18} />
      <div style={{ width: 1 }} />
      <IconBox icon="slash-in" iconSize={18} />
      <div style={{ ...T.t13, color: C.text56, marginLeft: 6.8 }}>Opus 5.5 (Preview)</div>
      <div style={{ flex: 1 }} />
      <IconBox icon="mic-18" iconSize={18} />
      <IconBox icon="voice-18" iconSize={18} />
      <div style={{ width: 4 }} />
      <div style={{ width: 28, height: 28, borderRadius: 9999, background: C.dark, display: "flex", alignItems: "center", justifyContent: "center" }}>
        <Icon name="stop" size={18} />
      </div>
    </div>
  </div>
);

const Chat: React.FC<{ frame: number; script: SessionScript }> = ({ frame, script }) => {
  const status = [...script.status].reverse().find((s) => frame >= s.at);
  return (
    <div style={{ position: "absolute", left: 24, width: LEFT_W - 48, top: 56, display: "flex", flexDirection: "column" }}>
      <Appear frame={frame} at={script.bubble}>
        <div style={{ display: "flex", justifyContent: "flex-end" }}>
          <div style={{ ...T.t14, color: C.text, background: C.fill04, borderRadius: 16, padding: "10px 14px", maxWidth: 420 }}>{PROMPT_TEXT}</div>
        </div>
      </Appear>
      <Appear frame={frame} at={script.reply}>
        <div style={{ ...T.t14, color: C.text, marginTop: 20 }}>
          On it — building an otter Flappy Bird iOS game, then building and testing it on the iOS simulator.
        </div>
      </Appear>
      <Appear frame={frame} at={script.worked}>
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 16, ...ROW, color: C.text56 }}>
          <Icon name="chevron-14" size={14} />
          Worked for 38s
        </div>
      </Appear>
      <div style={{ paddingLeft: 22, marginTop: 4 }}>
        {script.rows.map((r, i) => (
          <Appear key={i} frame={frame} at={r.at}>
            <div style={{ display: "flex", alignItems: "flex-start", gap: 12, padding: "4px 0", ...ROW, color: C.text56 }}>
              {r.kind === "thought" ? (
                <div style={{ display: "flex", alignItems: "center", gap: 4 }}>
                  {r.text}
                  <ChevronRight size={14} />
                </div>
              ) : (
                <>
                  <div style={{ flex: 1 }}>{r.text}</div>
                  {r.dur ? <div style={{ color: C.text40 }}>{r.dur}</div> : null}
                </>
              )}
            </div>
          </Appear>
        ))}
      </div>
      {status ? (
        <Appear frame={frame} at={script.status[0].at}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, marginTop: 14, ...ROW, color: "rgba(25,25,25,0.72)" }}>
            <Icon name="devin-mark" size={0} w={14.1} h={16} />
            <span key={status.text} style={{ opacity: prog(frame, status.at, status.at + 14, easeOut) }}>
              {status.text}
            </span>
          </div>
        </Appear>
      ) : null}
    </div>
  );
};

export const Session: React.FC<{ frame: number; script: SessionScript; chrome: number; screen: React.ReactNode }> = ({ frame, script, chrome, screen }) => (
  <div style={{ position: "absolute", left: 0, top: 0, width: VW, height: VH, fontFamily: FONT, color: C.text }}>
    <div style={{ position: "absolute", inset: 0, opacity: chrome }}>
      <Header />
      <div style={{ position: "absolute", left: LEFT_W, top: 0, width: 0.8, height: VH, background: "rgba(0,0,0,0.07)" }} />
      <RightChrome />
      <Chat frame={frame} script={script} />
      <Input />
    </div>
    <div style={{ position: "absolute", left: SCREEN.x, top: SCREEN.y, width: SCREEN.w, height: SCREEN.h, overflow: "hidden" }}>{screen}</div>
  </div>
);
