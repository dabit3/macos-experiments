import React from "react";
import { C, H, W, mono, text } from "../theme";
import { Btn, DrawCheck, Icon } from "./Icon";

export const VIDEO_W = 784;
export const VIDEO_H = H - 40 - 68;
export const TOTAL = 72;
const SETUP = { t: 0, text: "iPhone 17, iOS 26.5; Xcode 26.6. Fresh install, default settings." };
export const TESTS = [
  { t: 2, title: "It should show the title screen and start on tap", a: "Otter, score 0 and Tap to flap render; first tap starts the run." },
  { t: 7, title: "It should flap on every tap", a: "Each tap lifts the otter; gravity pulls it back between taps." },
  { t: 13, title: "It should score when clearing a pipe gap", a: "Score increments 0 → 1 → 2 as pipe pairs are cleared." },
  { t: 19, title: "It should end the run on collision", a: "Hitting a pipe shows Game Over with score 3 and best 3." },
  { t: 25, title: "It should restart from game over", a: "Restart resets the score to 0 and respawns the otter mid-screen." },
  { t: 33, title: "It should pause, quit and relaunch", a: "Pause freezes the pipes; relaunch restores best score 3." },
  { t: 48, title: "It should resume after backgrounding", a: "Home and return resumes paused with no state lost." },
];
const SEGS = [{ s: 0, e: 2, grey: true }, ...TESTS.map((x, i) => ({ s: x.t, e: i + 1 < TESTS.length ? TESTS[i + 1].t : TOTAL, grey: false }))];

const PX = (VIDEO_W - 24 - (SEGS.length - 1) * 2) / TOTAL;
const LIST_TOP = 40 + 36.8 + 102.8;
const SCROLL = -200;
const segX = (i: number) => 12 + SEGS[i].s * PX + i * 2;

export const PLAYER = {
  segEnd: (i: number) => ({ x: segX(i) + (SEGS[i].e - SEGS[i].s) * PX, y: 621 }),
  caption: { x: VIDEO_W - 12, y: 649 },
  check: (k: number) => ({ x: VIDEO_W + 0.8 + 72 + 7, y: LIST_TOP + SCROLL + 4 + 49 + k * 83 + 4 + 34 + 22.5 }),
  rowTitle: (k: number) => ({ x: VIDEO_W + 0.8 + 12, y: LIST_TOP + SCROLL + 4 + 49 + k * 83 + 4 + 17 }),
};

const fmt = (s: number) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, "0")}`;
const monoT = (color: string, weight = 400) => ({ fontFamily: mono, fontSize: 11, lineHeight: "14px", letterSpacing: 0.11, color, fontWeight: weight, whiteSpace: "nowrap" as const });

export type PlayerProps = { t: number; checkP: number; screen: React.ReactNode };

export const TestPlayer: React.FC<PlayerProps> = ({ t, checkP, screen }) => {
  let cur = 0;
  TESTS.forEach((x, i) => {
    if (t >= x.t) cur = i;
  });
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: W, height: H, background: "#fff", overflow: "hidden" }}>
      <div style={{ height: 40, borderBottom: `0.8px solid ${C.line}`, boxSizing: "border-box", padding: "0 16px", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <span style={text(13, 18, C.ink, 500)}>Otter Flap manual gameplay</span>
        <div style={{ width: 24, height: 32, position: "relative" }}>
          <Btn size={32} radius={4} style={{ position: "absolute", left: 0, top: 0 }}>
            <Icon n="close_727c1" s={18} />
          </Btn>
        </div>
      </div>
      <div style={{ position: "absolute", left: 0, top: 40, width: VIDEO_W, height: VIDEO_H, overflow: "hidden", background: "#000" }}>{screen}</div>
      <div style={{ position: "absolute", left: 0, top: 40 + VIDEO_H, width: VIDEO_W, height: 68, background: "#fff", padding: "8px 12px 12px", boxSizing: "border-box" }}>
        <div style={{ display: "flex", gap: 2, height: 12 }}>
          {SEGS.map((sg, i) => {
            const w = (sg.e - sg.s) * PX;
            const f = Math.max(0, Math.min(1, (t - sg.s) / (sg.e - sg.s)));
            const col = sg.grey ? "#6b7280" : "#34d399";
            return (
              <div key={i} style={{ width: w, height: 12, borderRadius: 4, overflow: "hidden", position: "relative", flexShrink: 0, background: sg.grey ? "rgba(107,114,128,0.2)" : "rgba(52,211,153,0.2)" }}>
                <div style={{ position: "absolute", left: 0, top: 0, height: 12, width: w * f, background: col, opacity: f >= 1 ? 0.85 : 1, borderRadius: f >= 1 ? 4 : "4px 0 0 4px" }} />
              </div>
            );
          })}
        </div>
        <div style={{ display: "flex", gap: 4, height: 36, paddingTop: 8, boxSizing: "border-box", alignItems: "center" }}>
          <Btn radius={6}>
            <Icon n="ctl_f0a27" s={14} />
          </Btn>
          <Btn radius={6}>
            <Icon n="ctl_24bbb" s={16} />
          </Btn>
          <Btn radius={6}>
            <Icon n="ctl_85a38" s={14} />
          </Btn>
          <div style={{ height: 28, padding: "0 6px", display: "flex", alignItems: "center" }}>
            <span style={monoT(C.grey, 500)}>1x</span>
          </div>
          <Btn radius={6}>
            <Icon n="ctl_8ad55" s={16} />
          </Btn>
          <Btn radius={6}>
            <Icon n="ctl_b923f" s={16} />
          </Btn>
          <div style={{ flex: 1, display: "flex", justifyContent: "flex-end", gap: 6 }}>
            <span style={monoT(C.ink)}>{TESTS[cur].title}</span>
            <span style={monoT(C.faint)}>|</span>
            <span style={monoT(C.grey)}>
              {fmt(t)} / {fmt(TOTAL)}
            </span>
          </div>
        </div>
      </div>

      <div style={{ position: "absolute", left: VIDEO_W, top: 40, width: W - VIDEO_W, height: H - 40, background: "#fcfcfc", borderLeft: `0.8px solid ${C.line}`, boxSizing: "border-box", overflow: "hidden" }}>
        <div style={{ borderBottom: `0.8px solid ${C.line}`, padding: "10px 16px", display: "flex", gap: 12 }}>
          {[
            [C.green, `${TESTS.length} passed`],
            [C.red, "0 failed"],
          ].map(([c, l]) => (
            <div key={l} style={{ display: "flex", gap: 6, alignItems: "center" }}>
              <div style={{ width: 8, height: 8, borderRadius: 9999, background: c }} />
              <span style={text(12, 16, C.grey, 400, 0)}>{l}</span>
            </div>
          ))}
        </div>
        <div style={{ borderBottom: `0.8px solid ${C.line}`, padding: "12px 16px", height: 102, boxSizing: "border-box" }}>
          <div style={{ ...text(12, 19.5, C.grey, 400, 0), whiteSpace: "normal", width: 384 }}>
            Requested manual flow passed: title screen, tap to flap, pipe scoring, collision and game over, restart, pause, quit and relaunch. Taps register immediately and the best score persists across launches. Minor visual concern: the score label sits close to the Dynamic Island.
          </div>
        </div>
        <div style={{ position: "absolute", left: 0, top: LIST_TOP - 40, width: 415.2, bottom: 0, overflow: "hidden" }}>
        <div style={{ position: "absolute", left: 0, top: SCROLL, width: 415.2, paddingTop: 4 }}>
          <div style={{ height: 49, display: "flex", gap: 8, alignItems: "center", padding: "8px 12px", boxSizing: "border-box" }}>
            <div style={{ width: 32, textAlign: "right", ...monoT(C.faint) }}>{fmt(SETUP.t)}</div>
            <Icon n="panel_b83dd" s={14} />
            <div style={{ ...text(12, 16.5, C.ink, 400, 0), whiteSpace: "normal", width: 330 }}>{SETUP.text}</div>
          </div>
          {TESTS.map((x, i) => {
            const sel = i === cur;
            const bg = sel ? "rgba(51,125,244,0.1)" : "transparent";
            return (
              <div key={x.t} style={{ height: 83, paddingTop: 4, boxSizing: "border-box" }}>
                <div style={{ height: 33.875, display: "flex", gap: 8, alignItems: "center", padding: "8px 12px", boxSizing: "border-box", background: bg }}>
                  <div style={{ width: 32, textAlign: "right", ...monoT(C.faint) }}>{fmt(x.t)}</div>
                  <Icon n="panel_2a298" s={14} />
                  <span style={text(13, 17.875, C.ink, 500)}>{x.title}</span>
                </div>
                <div style={{ display: "flex", alignItems: "center", padding: "6px 12px 6px 0", position: "relative" }}>
                  <div style={{ width: 72 }} />
                  {sel ? <DrawCheck p={checkP} bg="#fcfcfc" /> : <Icon n="panel_834f0" s={14} />}
                  <div style={{ ...text(12, 16.5, C.ink, 400, 0), whiteSpace: "normal", width: 310, paddingLeft: 8 }}>{x.a}</div>
                  <div style={{ position: "absolute", left: 59, top: 0, width: 8, height: 22.5, borderLeft: `0.8px solid ${C.line}`, borderBottom: `0.8px solid ${C.line}`, borderBottomLeftRadius: 6 }} />
                </div>
              </div>
            );
          })}
        </div>
        </div>
      </div>
    </div>
  );
};
