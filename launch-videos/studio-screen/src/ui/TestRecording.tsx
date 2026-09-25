import { Pointer } from "./glyphs";
import { OffthreadVideo, Sequence, staticFile } from "remotion";
import { easeInOutQuint, easeOutCubic, ramp } from "../ease";
import { FOOTAGE_START, FPS, T } from "../timeline";
import { Icon } from "./Icon";
import { C, inter, m11, t12, t13, UI_W } from "./tokens";

const PANEL_W = 416;
const VIDEO_W = UI_W - PANEL_W;
const BOUNDS = [0, 2, 6, 13, 19, 25, 31, 48, 72];
const TOTAL = 72;

const TESTS: { title: string; assertion: string }[] = [
  { title: "It should launch to the Otter Flap title screen", assertion: "Title, “Paddle through the driftwood” and Best 0 shown." },
  { title: "It should start a run on the first tap", assertion: "Otter lifts on tap; score reads 0 and logs scroll in." },
  { title: "It should flap on every tap and glide down", assertion: "Each tap raises the otter; releasing lets it fall smoothly." },
  { title: "It should score when clearing a driftwood gap", assertion: "Score counts 1, 2, 3 as the otter clears each gap." },
  { title: "It should end the run on collision", assertion: "Splash! card shows final score 3 and Best 3." },
  { title: "It should restart from the game-over card", assertion: "Tap restarts at 0 with the same log spacing." },
  { title: "It should keep the best score after relaunch", assertion: "Quit and relaunch; title screen shows Best 3." },
];

const fmt = (s: number) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, "0")}`;

export const playbackTime = (frame: number) => 28 + Math.max(0, frame - T.recording) / FPS;

const TimeCell: React.FC<{ t: number }> = ({ t }) => (
  <div style={{ width: 32, textAlign: "right", ...m11, color: C.faint, flexShrink: 0 }}>{fmt(t)}</div>
);

const ControlButton: React.FC<{ children: React.ReactNode; wide?: boolean }> = ({ children, wide }) => (
  <div style={{ height: 28, width: wide ? undefined : 28, padding: wide ? "0 6px" : 0, borderRadius: 6, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
    {children}
  </div>
);

export const TestRecording: React.FC<{ frame: number }> = ({ frame }) => {
  const t = playbackTime(frame);
  const current = Math.max(0, BOUNDS.findIndex((b, i) => t >= b && t < BOUNDS[i + 1]));
  const testIdx = current - 1;
  const enter = ramp(frame, T.recording, T.recording + 22, easeInOutQuint);
  const scrollTarget = (idx: number) => Math.max(0, 4 + 33.9 + idx * 83 - 190);
  const changeAt = T.recording + (31 - 28) * FPS;
  const scroll =
    scrollTarget(4) + (scrollTarget(5) - scrollTarget(4)) * ramp(frame, changeAt, changeAt + 30, easeInOutQuint);
  const playFrom = Math.round((55.2 - FOOTAGE_START) * FPS);
  const segW = (VIDEO_W - 24 - 2 * (BOUNDS.length - 2)) / TOTAL;
  const tapFrames = [0, 27, 49, 80, 104, 131, 160, 186, 214, 240, 262, 292, 318, 347, 371, 398].map((d) => T.recording + 30 + d);

  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        background: "#fcfcfc",
        opacity: enter,
        transform: `scale(${0.985 + 0.015 * enter})`,
        display: "flex",
        flexDirection: "column",
      }}
    >
      <div style={{ height: 40, flexShrink: 0, boxSizing: "border-box", borderBottom: `0.8px solid ${C.hairline}`, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 16px" }}>
        <div style={{ ...t13, fontWeight: 500, color: C.text }}>Otter Flap gameplay</div>
        <div style={{ width: 32, height: 32, marginRight: -8, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Icon name="close" size={18} />
        </div>
      </div>
      <div style={{ flex: 1, display: "flex", minHeight: 0 }}>
        <div style={{ width: VIDEO_W, display: "flex", flexDirection: "column" }}>
          <div style={{ flex: 1, position: "relative", overflow: "hidden", background: "#000" }}>
            <Sequence from={T.recording} layout="none">
              <OffthreadVideo
                src={staticFile("footage/desktop.mp4")}
                startFrom={playFrom}
                muted
                style={{ position: "absolute", left: 0, top: 0, width: VIDEO_W, height: (VIDEO_W * 656) / 876, display: "block" }}
              />
            </Sequence>
            {tapFrames.map((f) => {
              const p = (frame - f) / 22;
              if (p < 0 || p > 1) return null;
              const x = VIDEO_W * 0.517;
              const y = ((VIDEO_W * 656) / 876) * 0.63;
              return (
                <div
                  key={f}
                  style={{
                    position: "absolute",
                    left: x - 14,
                    top: y - 14,
                    width: 28,
                    height: 28,
                    borderRadius: 9999,
                    background: `rgba(96,165,250,${0.35 * (1 - p)})`,
                    transform: `scale(${0.5 + 0.9 * easeOutCubic(p)})`,
                  }}
                />
              );
            })}
            <Pointer style={{ position: "absolute", left: VIDEO_W * 0.517 - 6, top: ((VIDEO_W * 656) / 876) * 0.63 - 3, width: 28, height: 32 }}
            />
          </div>
          <div style={{ background: "#fff", padding: "8px 12px 12px", flexShrink: 0 }}>
            <div style={{ display: "flex", gap: 2, height: 12 }}>
              {BOUNDS.slice(0, -1).map((b, i) => {
                const end = BOUNDS[i + 1];
                const w = (end - b) * segW;
                const fill = Math.max(0, Math.min(1, (t - b) / (end - b)));
                const setup = i === 0;
                const done = fill >= 1;
                return (
                  <div key={b} style={{ width: w, height: 12, borderRadius: 4, overflow: "hidden", position: "relative", background: setup ? "rgba(107,114,128,0.2)" : "rgba(52,211,153,0.2)" }}>
                    <div
                      style={{
                        position: "absolute",
                        left: 0,
                        top: 0,
                        height: 12,
                        width: w * fill,
                        borderRadius: 4,
                        background: setup ? "#6b7280" : C.timeline,
                        opacity: done ? 0.85 : 1,
                      }}
                    />
                  </div>
                );
              })}
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: 4, height: 36, paddingTop: 8, boxSizing: "border-box" }}>
              <ControlButton>
                <Icon name="prev" size={14} />
              </ControlButton>
              <ControlButton>
                <Icon name="pause" size={16} />
              </ControlButton>
              <ControlButton>
                <Icon name="next" size={14} />
              </ControlButton>
              <ControlButton wide>
                <div style={{ ...m11, fontWeight: 500, color: C.muted }}>1x</div>
              </ControlButton>
              <ControlButton>
                <Icon name="loop" size={16} />
              </ControlButton>
              <ControlButton>
                <Icon name="download" size={16} />
              </ControlButton>
              <div style={{ flex: 1, display: "flex", justifyContent: "flex-end", gap: 6, alignItems: "center" }}>
                <div style={{ ...m11, color: C.text, whiteSpace: "nowrap" }}>{testIdx >= 0 ? TESTS[testIdx].title : "Setup"}</div>
                <div style={{ ...m11, color: C.faint }}>|</div>
                <div style={{ ...m11, color: C.muted, whiteSpace: "nowrap" }}>
                  {fmt(t)} / {fmt(TOTAL)}
                </div>
              </div>
            </div>
          </div>
        </div>
        <div style={{ width: PANEL_W, boxSizing: "border-box", borderLeft: `0.8px solid ${C.hairline}`, display: "flex", flexDirection: "column", overflow: "hidden" }}>
          <div style={{ borderBottom: `0.8px solid ${C.hairline}`, padding: "10px 16px", display: "flex", gap: 12 }}>
            <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
              <div style={{ width: 8, height: 8, borderRadius: 9999, background: C.green }} />
              <div style={{ ...t12, color: C.muted }}>7 passed</div>
            </div>
            <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
              <div style={{ width: 8, height: 8, borderRadius: 9999, background: C.red }} />
              <div style={{ ...t12, color: C.muted }}>0 failed</div>
            </div>
          </div>
          <div style={{ borderBottom: `0.8px solid ${C.hairline}`, padding: "12px 16px" }}>
            <div style={{ fontFamily: inter, fontSize: 12, lineHeight: "19.5px", color: C.muted }}>
              Requested gameplay flow passed on iPhone 17: launch, title screen, tap to flap, scoring through driftwood gaps, collision, restart and relaunch with best score kept. Flap response and log spacing stayed consistent through the run.
            </div>
          </div>
          <div style={{ flex: 1, position: "relative", overflow: "hidden" }}>
            <div style={{ position: "absolute", left: 0, right: 0, top: -scroll, padding: "4px 0" }}>
              <div style={{ display: "flex", gap: 8, alignItems: "center", padding: "8px 12px" }}>
                <TimeCell t={0} />
                <div style={{ width: 14, display: "flex", justifyContent: "center" }}>
                  <Icon name="setup" size={14} />
                </div>
                <div style={{ fontFamily: inter, fontSize: 12, lineHeight: "16.5px", color: C.text, flex: 1 }}>
                  iPhone 17, iOS 26.5; Xcode 26.6. Fresh install, first launch of Otter Flap.
                </div>
              </div>
              {TESTS.map((test, i) => {
                const isCurrent = i === testIdx;
                return (
                  <div key={test.title} style={{ height: 83, paddingTop: 4, boxSizing: "border-box" }}>
                    <div style={{ display: "flex", gap: 8, alignItems: "center", padding: "8px 12px", background: isCurrent ? C.blueTint : "transparent" }}>
                      <TimeCell t={BOUNDS[i + 1]} />
                      <div style={{ width: 14, display: "flex", justifyContent: "center" }}>
                        <Icon name="test" size={14} />
                      </div>
                      <div style={{ ...t13, lineHeight: "17.875px", fontWeight: 500, color: C.text, whiteSpace: "nowrap" }}>{test.title}</div>
                    </div>
                    <div style={{ display: "flex", alignItems: "center", padding: "6px 12px 6px 0", position: "relative", opacity: isCurrent ? 0.4 : 1 }}>
                      <div style={{ width: 72, flexShrink: 0 }} />
                      <div style={{ width: 14, display: "flex", justifyContent: "center" }}>
                        <Icon name="check" size={14} />
                      </div>
                      <div style={{ fontFamily: inter, fontSize: 12, lineHeight: "16.5px", color: C.text, paddingLeft: 8, flex: 1 }}>{test.assertion}</div>
                      <div
                        style={{
                          position: "absolute",
                          left: 59,
                          top: 0,
                          width: 8,
                          height: 22.5,
                          boxSizing: "border-box",
                          borderLeft: `0.8px solid ${C.hairline}`,
                          borderBottom: `0.8px solid ${C.hairline}`,
                          borderBottomLeftRadius: 6,
                        }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
