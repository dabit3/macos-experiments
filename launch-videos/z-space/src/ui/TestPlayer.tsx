import React from "react";
import { C, INTER, MONO } from "../theme";
import { Icon, CloseX } from "../icons";
import { Text } from "./common";

export const TP = {
  header: { x: 0, y: 0, w: 1203, h: 40 },
  video: { x: 5.6, y: 40, w: 776, h: 582 },
  controls: { x: 0, y: 622, w: 787.2, h: 68 },
  results: { x: 787.2, y: 40, w: 415.8, h: 650 },
};

export const TOTAL = 72;

type Test = { t: number; title: string; asserts: { t: number; text: string }[] };

export const TESTS: Test[] = [
  { t: 2, title: "It should launch to the Otter Flap title screen", asserts: [{ t: 4, text: "Title, otter and “Tap to flap” prompt visible; score hidden until the run starts." }] },
  { t: 6, title: "It should start a run on the first tap", asserts: [{ t: 8, text: "Otter hops on tap; score shows 0 and driftwood logs begin scrolling." }] },
  { t: 11, title: "It should score when passing a log gap", asserts: [{ t: 15, text: "Score increments 0 → 1 → 2 after each cleared gap." }] },
  { t: 17, title: "It should end the run on collision", asserts: [{ t: 21, text: "Game-over card shows score, best and medal; Replay is focused." }] },
  { t: 25, title: "It should restart from the game-over card", asserts: [{ t: 29, text: "Replay resets score to 0 and respawns the otter mid-screen." }] },
  { t: 33, title: "It should pause when backgrounded and resume", asserts: [{ t: 36, text: "Home swipe pauses the scene; relaunch shows Resume and keeps score." }, { t: 42, text: "Resume continues with physics unchanged." }] },
  { t: 46, title: "It should persist best score across relaunch", asserts: [{ t: 52, text: "Quit and relaunch keeps Best: 7 on the title screen." }] },
];

export const SEGMENTS = [0, 2, 6, 11, 17, 25, 33, 46, TOTAL];

export const fmt = (s: number) => {
  const v = Math.max(0, Math.floor(s));
  return `${Math.floor(v / 60)}:${String(v % 60).padStart(2, "0")}`;
};

export const currentTest = (time: number) => {
  let idx = -1;
  TESTS.forEach((t, i) => {
    if (time >= t.t) idx = i;
  });
  return idx;
};

export const TPHeader: React.FC = () => (
  <div style={{ position: "absolute", inset: 0, background: C.page, borderBottom: `0.8px solid ${C.hairline}`, display: "flex", alignItems: "center", padding: "0 16px" }}>
    <Text size={13} lh={18} weight={500}>Otter Flap gameplay checks</Text>
    <div style={{ flex: 1 }} />
    <CloseX size={16} />
  </div>
);

export const TPControls: React.FC<{ time: number }> = ({ time }) => {
  const idx = currentTest(time);
  const caption = idx >= 0 ? TESTS[idx].title : "Setup";
  const W = 763.2;
  const gaps = (SEGMENTS.length - 2) * 2;
  return (
    <div style={{ position: "absolute", inset: 0, background: "#fff", padding: "8px 12px 12px 12px" }}>
      <div style={{ display: "flex", gap: 2, height: 12 }}>
        {SEGMENTS.slice(0, -1).map((a, i) => {
          const b = SEGMENTS[i + 1];
          const w = ((b - a) / TOTAL) * (W - gaps);
          const fill = Math.max(0, Math.min(1, (time - a) / (b - a)));
          const grey = i === 0;
          return (
            <div key={i} style={{ width: w, height: 12, borderRadius: 4, overflow: "hidden", position: "relative", background: grey ? "rgba(107,114,128,0.2)" : "rgba(52,211,153,0.2)" }}>
              <div style={{ position: "absolute", left: 0, top: 0, height: 12, width: w * fill, background: grey ? "#6b7280" : "#34d399", opacity: fill >= 1 ? 0.85 : 1, borderRadius: fill >= 1 ? 4 : "4px 0 0 4px" }} />
            </div>
          );
        })}
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 4, height: 36, paddingTop: 8 }}>
        {(["prev", "pause", "next"] as const).map((n) => (
          <div key={n} style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <Icon name={n} size={n === "pause" ? 16 : 14} />
          </div>
        ))}
        <div style={{ height: 28, padding: "0 6px", display: "flex", alignItems: "center", fontFamily: MONO, fontWeight: 500, fontSize: 11, lineHeight: "14px", letterSpacing: 0.11, color: C.muted }}>1x</div>
        {(["loop", "download"] as const).map((n) => (
          <div key={n} style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <Icon name={n} size={16} />
          </div>
        ))}
        <div style={{ flex: 1 }} />
        <div style={{ display: "flex", gap: 6, fontFamily: MONO, fontSize: 11, lineHeight: "14px", letterSpacing: 0.11, whiteSpace: "nowrap" }}>
          <span style={{ color: C.text }}>{caption}</span>
          <span style={{ color: C.faint }}>|</span>
          <span style={{ color: C.muted }}>
            {fmt(time)} / {fmt(TOTAL)}
          </span>
        </div>
      </div>
    </div>
  );
};

const Stamp: React.FC<{ t: number; dim: boolean }> = ({ t, dim }) => (
  <div style={{ width: 32, flexShrink: 0, fontFamily: MONO, fontSize: 11, lineHeight: "18px", letterSpacing: 0.11, color: dim ? "rgba(25,25,25,0.25)" : C.faint }}>{fmt(t)}</div>
);

export const TPResults: React.FC<{ time: number; scroll: number; passedAll: number }> = ({ time, scroll, passedAll }) => {
  const idx = currentTest(time);
  const total = TESTS.reduce((n, t) => n + t.asserts.length, 0);
  const passed = Math.round(passedAll * total);
  return (
    <div style={{ position: "absolute", inset: 0, background: "#fcfcfc", borderLeft: `0.8px solid ${C.hairline}`, overflow: "hidden" }}>
      <div style={{ height: 36.8, padding: "10px 16px", display: "flex", alignItems: "center", gap: 12, borderBottom: `0.8px solid ${C.hairline}` }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <div style={{ width: 8, height: 8, borderRadius: 9999, background: C.pass }} />
          <Text size={12} lh={16} color={C.muted}>{passed} passed</Text>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <div style={{ width: 8, height: 8, borderRadius: 9999, background: C.fail }} />
          <Text size={12} lh={16} color={C.muted}>0 failed</Text>
        </div>
      </div>
      <div style={{ padding: "12px 16px", borderBottom: `0.8px solid ${C.hairline}`, fontFamily: INTER, fontSize: 12, lineHeight: "19.5px", color: C.muted }}>
        Built OtterFlap with xcodebuild, installed it on the iPhone 17 simulator and played it end to end with computer use. Tap to flap, scoring, collisions,
        game over, replay, backgrounding and relaunch all behave as expected. Best score persists across launches and HUD stays inside the safe area.
      </div>
      <div style={{ position: "relative", overflow: "hidden", height: 460 }}>
      <div style={{ position: "relative", transform: `translateY(${-scroll}px)` }}>
        <div style={{ display: "flex", gap: 8, padding: "8px 12px" }}>
          <Stamp t={0} dim={false} />
          <div style={{ width: 14, paddingTop: 2 }}>
            <Icon name="hexagon" size={14} />
          </div>
          <div style={{ fontFamily: INTER, fontSize: 13, lineHeight: "17.875px", fontWeight: 500, color: C.text, width: 330 }}>
            a1c9f2e: iPhone 17 simulator, iOS 26.5; GUI inputs only.
          </div>
        </div>
        {TESTS.map((t, i) => {
          const future = time < t.t;
          const current = i === idx;
          return (
            <div key={i} style={{ opacity: future ? 0.45 : 1 }}>
              <div style={{ display: "flex", gap: 8, padding: "8px 12px", background: current && time < t.asserts[0].t ? "rgba(51,125,244,0.1)" : undefined }}>
                <Stamp t={t.t} dim={future} />
                <div style={{ width: 14, paddingTop: 2 }}>
                  <Icon name="flask" size={14} />
                </div>
                <div style={{ fontFamily: INTER, fontSize: 13, lineHeight: "17.875px", fontWeight: 500, color: C.text, width: 330 }}>{t.title}</div>
              </div>
              {t.asserts.map((a, j) => {
                const done = time >= a.t;
                const nextT = t.asserts[j + 1]?.t ?? TESTS[i + 1]?.t ?? TOTAL;
                const hl = current && time >= a.t && time < nextT;
                return (
                  <div key={j} style={{ position: "relative", display: "flex", padding: "8px 12px 8px 72px", background: hl ? "rgba(51,125,244,0.1)" : undefined }}>
                    <div style={{ position: "absolute", left: 59, top: -8, width: 8, height: 26, borderLeft: `0.8px solid rgba(0,0,0,0.12)`, borderBottom: `0.8px solid rgba(0,0,0,0.12)`, borderBottomLeftRadius: 6 }} />
                    <div style={{ width: 14, paddingTop: 1.5, opacity: done ? 1 : 0.5, transform: `scale(${done ? 1 : 0.9})` }}>
                      <Icon name="check" size={14} />
                    </div>
                    <div style={{ paddingLeft: 8, fontFamily: INTER, fontSize: 12, lineHeight: "16.5px", color: done ? C.text : C.muted, width: 330 }}>{a.text}</div>
                  </div>
                );
              })}
            </div>
          );
        })}
      </div>
      </div>
    </div>
  );
};
