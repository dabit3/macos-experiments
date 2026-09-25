import type { ReactNode } from "react";
import { IconClose, IconDownload, IconLoop, IconPassed, IconPause, IconSkipBack, IconSkipFwd, IconTestCase } from "../icons";
import { c, font } from "../theme";

export const PANEL_W = 415.2;
export const VIEWER_HEADER = 44;
export const CONTROLS_H = 68;

type Test = { t: string; name: string; result: string };
export const TESTS: Test[] = [
  { t: "0:02", name: "It should launch to the title screen and start on tap", result: "Title rendered; first tap started a run at score 0." },
  { t: "0:09", name: "It should score when the otter clears a log", result: "Score advanced 0 → 6 across six log gaps." },
  { t: "0:17", name: "It should end the run on a log collision", result: "Game over card showed score 6 and best 6." },
  { t: "0:26", name: "It should restart from the game over card", result: "Restart reset score to 0 and respawned the otter." },
  { t: "0:33", name: "It should resume at the same score after pause", result: "Pressed @i17 Resume; play resumed at score 6." },
];

const hair = "0.8px solid rgba(0,0,0,0.06)";

const Btn = ({ children, w = 28 }: { children: ReactNode; w?: number }) => (
  <div style={{ width: w, height: 28, borderRadius: 6, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>{children}</div>
);

const TestRow = ({ test, state, check }: { test: Test; state: "done" | "current" | "future"; check: number }) => {
  const muted = state === "future";
  const showResult = state !== "current" || check > 0;
  return (
    <div style={{ paddingTop: 4, width: "100%" }}>
      <div style={{ display: "flex", gap: 8, alignItems: "center", padding: "8px 12px", background: state === "current" ? c.blueSoft : "transparent", opacity: muted ? 0.45 : 1 }}>
        <div style={{ width: 32, textAlign: "right", fontFamily: font.mono, fontSize: 11, lineHeight: "14px", letterSpacing: 0.11, color: c.text4 }}>{test.t}</div>
        <div style={{ width: 14, display: "flex", justifyContent: "center" }}><IconTestCase /></div>
        <div style={{ flex: 1, fontFamily: font.sans, fontWeight: 500, fontSize: 13, lineHeight: "17.875px", letterSpacing: -0.065, color: c.ink, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{test.name}</div>
      </div>
      <div style={{ position: "relative", display: "flex", alignItems: "center", padding: "6px 12px 6px 0", minHeight: 28.5, opacity: muted ? 0.45 : 1 }}>
        <div style={{ position: "absolute", left: 59, top: 0, width: 8, height: 22.5, borderLeft: hair, borderBottom: hair, borderBottomLeftRadius: 6 }} />
        <div style={{ width: 72, flexShrink: 0 }} />
        <div style={{ width: 14, display: "flex", justifyContent: "center", transform: `scale(${state === "current" ? check : 1})`, opacity: showResult ? 1 : 0 }}><IconPassed /></div>
        <div style={{ flex: 1, paddingLeft: 8, fontFamily: font.sans, fontSize: 12, lineHeight: "16.5px", color: c.ink, opacity: state === "current" ? Math.min(1, check * 1.2) : 1 }}>{test.result}</div>
      </div>
    </div>
  );
};

export const TestViewer = ({ video, check, time, segFill }: { video: ReactNode; check: number; time: string; segFill: number }) => {
  const passed = check >= 0.5 ? 5 : 4;
  const segs = [0.06, 0.1, 0.11, 0.12, 0.13, 0.48];
  return (
    <div style={{ position: "absolute", inset: 0, background: "#FFFFFF", fontFamily: font.sans, color: c.ink }}>
      <div style={{ position: "absolute", left: 0, top: 0, right: 0, height: VIEWER_HEADER, borderBottom: hair, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 16px" }}>
        <div style={{ fontWeight: 500, fontSize: 13, lineHeight: "18px", letterSpacing: -0.065 }}>Flappy Otter pause and resume</div>
        <div style={{ width: 32, height: 32, display: "flex", alignItems: "center", justifyContent: "center", marginRight: -8 }}><IconClose size={18} color="rgba(25,25,25,0.56)" /></div>
      </div>
      <div style={{ position: "absolute", left: 0, top: VIEWER_HEADER, width: 1280 - PANEL_W, bottom: CONTROLS_H, overflow: "hidden", background: "#FFFFFF" }}>{video}</div>
      <div style={{ position: "absolute", left: 0, width: 1280 - PANEL_W, bottom: 0, height: CONTROLS_H, background: "#FFFFFF", padding: "8px 12px 12px", boxSizing: "border-box" }}>
        <div style={{ display: "flex", gap: 2, height: 12 }}>
          {segs.map((w, i) => {
            const green = i >= 1 && i <= 4;
            const base = green ? c.segGreen : i === 5 ? c.segGreen : c.segGray;
            const fill = i < 5 ? 1 : segFill;
            return (
              <div key={i} style={{ flex: w, height: 12, borderRadius: 4, background: i === 0 ? "rgba(107,114,128,0.2)" : "rgba(52,211,153,0.2)", overflow: "hidden", position: "relative" }}>
                <div style={{ position: "absolute", left: 0, top: 0, height: 12, width: `${fill * 100}%`, borderRadius: 4, background: base, opacity: 0.85 }} />
              </div>
            );
          })}
        </div>
        <div style={{ display: "flex", gap: 4, height: 36, paddingTop: 8, boxSizing: "border-box", alignItems: "center" }}>
          <Btn><IconSkipBack /></Btn>
          <Btn><IconPause /></Btn>
          <Btn><IconSkipFwd /></Btn>
          <Btn w={26}><span style={{ fontFamily: font.mono, fontWeight: 500, fontSize: 11, lineHeight: "14px", letterSpacing: 0.11, color: c.text3 }}>1x</span></Btn>
          <Btn><IconLoop /></Btn>
          <Btn><IconDownload /></Btn>
          <div style={{ flex: 1, textAlign: "right", fontFamily: font.mono, fontSize: 11, lineHeight: "14px", whiteSpace: "nowrap" }}>
            <span style={{ color: c.ink }}>{TESTS[4].name}</span>
            <span style={{ color: c.text4 }}> | </span>
            <span style={{ color: c.text3 }}>{time} / 1:12</span>
          </div>
        </div>
      </div>
      <div style={{ position: "absolute", right: 0, top: VIEWER_HEADER, width: PANEL_W, bottom: 0, borderLeft: hair, background: c.panel, overflow: "hidden" }}>
        <div style={{ display: "flex", gap: 12, alignItems: "center", padding: "10px 16px", borderBottom: hair }}>
          <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
            <div style={{ width: 8, height: 8, borderRadius: 99, background: c.green }} />
            <span style={{ fontSize: 12, lineHeight: "16px", color: c.text3, fontVariantNumeric: "tabular-nums" }}>{passed} passed</span>
          </div>
          <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
            <div style={{ width: 8, height: 8, borderRadius: 99, background: c.red }} />
            <span style={{ fontSize: 12, lineHeight: "16px", color: c.text3 }}>0 failed</span>
          </div>
        </div>
        <div style={{ padding: "12px 16px", borderBottom: hair, fontSize: 12, lineHeight: "19.5px", color: c.text3 }}>
          Built Flappy Otter and played it on the iPhone 17 Simulator: launch, scoring, collision, restart, and pause/resume. Controls were queried and pressed through the accessibility tree; gameplay state was checked with screenshots.
        </div>
        {TESTS.map((t, i) => (
          <TestRow key={i} test={t} state={i < 4 ? "done" : "current"} check={i === 4 ? check : 1} />
        ))}
      </div>
    </div>
  );
};
