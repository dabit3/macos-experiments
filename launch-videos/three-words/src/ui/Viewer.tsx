import { C, LH, LW } from "../theme";
import { Box, Icon, mono, text } from "./primitives";

export const RESULTS_W = 415.2;
export const VIDEO_W = LW - RESULTS_W;
export const VIDEO_H = 581.6;
export const VIEWER_TITLE = "Verify Otter Flap gameplay";
export const TITLE_POS = { x: 16, y: 11 };
export const REC_LEN = 72;

export const TESTS = [
  { t: 2, title: "It should launch to the Otter Flap title screen", check: "Title, best score and Tap to flap prompt are visible." },
  { t: 9, title: "It should flap when the screen is tapped", check: "Each tap lifts the otter; gravity pulls it back down." },
  { t: 17, title: "It should score when passing a log gap", check: "Score goes 0 → 1 → 2 as the otter clears each gap." },
  { t: 26, title: "It should end the run on collision", check: "Hitting a log shows Game Over with score, best and Replay." },
  { t: 33, title: "It should pause and resume from the HUD", check: "Pause freezes the logs; Resume continues the same run." },
  { t: 41, title: "It should keep the best score after relaunch", check: "Quit and relaunch; best score 2 is persisted on the title." },
];

const fmt = (s: number) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, "0")}`;

const Summary = () => (
  <div style={{ borderBottom: `0.8px solid ${C.line06}`, padding: "10px 16px", display: "flex", gap: 12, alignItems: "center" }}>
    {[
      [C.green, `${TESTS.length} passed`],
      [C.red, "0 failed"],
    ].map(([c, l]) => (
      <div key={l} style={{ display: "flex", gap: 6, alignItems: "center" }}>
        <div style={{ width: 8, height: 8, borderRadius: 9999, background: c }} />
        <span style={text(12, 16, C.ink56, 400, 0)}>{l}</span>
      </div>
    ))}
  </div>
);

const TestBlock: React.FC<{ i: number; now: number; current: number }> = ({ i, now, current }) => {
  const tc = TESTS[i];
  const played = now >= tc.t;
  const isCur = i === current;
  const pending = isCur && (i + 1 < TESTS.length ? now < tc.t + 4 : true);
  return (
    <div style={{ paddingTop: 4 }}>
      <div
        style={{
          display: "flex",
          gap: 8,
          alignItems: "center",
          padding: "8px 12px",
          background: isCur ? C.blue10 : "transparent",
          opacity: played ? 1 : 0.4,
        }}
      >
        <div style={{ width: 32, textAlign: "right", ...mono(C.ink40) }}>{fmt(tc.t)}</div>
        <Icon name="tap" size={14} />
        <span style={text(13, 17.875, C.ink, 500)}>{tc.title}</span>
      </div>
      <div style={{ position: "relative", display: "flex", alignItems: "center", padding: "6px 12px 6px 0", opacity: played && !pending ? 1 : 0.4 }}>
        <div style={{ width: 72, flexShrink: 0 }} />
        <Icon name="check-circle" size={14} />
        <div style={{ paddingLeft: 8, width: 310, ...text(12, 16.5, C.ink, 400, 0), whiteSpace: "normal" }}>{tc.check}</div>
        <div
          style={{
            position: "absolute",
            left: 59,
            top: 0,
            width: 8,
            height: 22.5,
            borderLeft: `0.8px solid ${C.line06}`,
            borderBottom: `0.8px solid ${C.line06}`,
            borderBottomLeftRadius: 6,
            boxSizing: "border-box",
          }}
        />
      </div>
    </div>
  );
};

export const Viewer: React.FC<{ now: number; video: React.ReactNode; titleOpacity: number }> = ({ now, video, titleOpacity }) => {
  let current = 0;
  TESTS.forEach((tc, i) => {
    if (now >= tc.t) current = i;
  });
  const bounds = [0, ...TESTS.map((t) => t.t), REC_LEN];
  const trackW = VIDEO_W - 24 - 2 * (bounds.length - 2);
  return (
    <div style={{ position: "absolute", inset: 0, background: "#fff" }}>
      <div
        style={{
          position: "absolute",
          left: 0,
          top: 0,
          width: LW,
          height: 40,
          borderBottom: `0.8px solid ${C.line06}`,
          boxSizing: "border-box",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "0 16px",
        }}
      >
        <span style={{ ...text(13, 18, C.ink, 500), opacity: titleOpacity }}>{VIEWER_TITLE}</span>
        <Box size={32} radius={4}>
          <Icon name="close" size={18} />
        </Box>
      </div>
      <div style={{ position: "absolute", left: 0, top: 40, width: VIDEO_W, height: VIDEO_H, overflow: "hidden", background: "#000" }}>{video}</div>
      <div style={{ position: "absolute", left: 0, top: 40 + VIDEO_H, width: VIDEO_W, height: LH - 40 - VIDEO_H, background: "#fff", padding: "8px 12px 12px", boxSizing: "border-box" }}>
        <div style={{ display: "flex", gap: 2, height: 12 }}>
          {bounds.slice(0, -1).map((b, i) => {
            const e = bounds[i + 1];
            const w = ((e - b) / REC_LEN) * trackW;
            const fill = Math.max(0, Math.min(1, (now - b) / (e - b)));
            const setup = i === 0;
            const partial = fill > 0 && fill < 1;
            return (
              <div key={i} style={{ position: "relative", width: w, height: 12, borderRadius: 4, overflow: "hidden", background: setup ? "rgba(107,114,128,0.2)" : "rgba(52,211,153,0.2)" }}>
                <div
                  style={{
                    position: "absolute",
                    left: 0,
                    top: 0,
                    height: 12,
                    width: fill * w,
                    borderRadius: 4,
                    background: setup ? "#6b7280" : "#34d399",
                    opacity: partial ? 1 : 0.85,
                  }}
                />
              </div>
            );
          })}
        </div>
        <div style={{ display: "flex", gap: 4, alignItems: "center", height: 36, paddingTop: 8, boxSizing: "border-box" }}>
          <Box radius={6}>
            <Icon name="prev" size={14} />
          </Box>
          <Box radius={6}>
            <Icon name="pause" size={16} />
          </Box>
          <Box radius={6}>
            <Icon name="next" size={14} />
          </Box>
          <div style={{ height: 28, display: "flex", alignItems: "center", padding: "0 6px" }}>
            <span style={mono(C.ink56, 500)}>1x</span>
          </div>
          <Box radius={6}>
            <Icon name="loop" size={16} />
          </Box>
          <Box radius={6}>
            <Icon name="download" size={16} />
          </Box>
          <div style={{ flex: 1 }} />
          <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
            <span style={mono(C.ink)}>{TESTS[current].title}</span>
            <span style={mono(C.ink40)}>|</span>
            <span style={mono(C.ink56)}>
              {fmt(now)} / {fmt(REC_LEN)}
            </span>
          </div>
        </div>
      </div>
      <div style={{ position: "absolute", left: VIDEO_W, top: 40, width: RESULTS_W, height: LH - 40, borderLeft: `0.8px solid ${C.line06}`, boxSizing: "border-box", background: "#fff", overflow: "hidden" }}>
        <Summary />
        <div style={{ padding: "12px 16px", ...text(12, 19.5, C.ink56, 400, 0), whiteSpace: "normal", width: 384 }}>
          Requested manual flow passed on iPhone 17 (iOS 26.5): title screen, tap-to-flap, scoring through log gaps, collision and Game Over, pause/resume from the HUD, and quit/relaunch with the best score persisted. Hitbox felt fair across 12 runs; no visual issues found.
        </div>
        {TESTS.map((_, i) => (
          <TestBlock key={i} i={i} now={now} current={current} />
        ))}
      </div>
    </div>
  );
};
