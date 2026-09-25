import { mono } from "../fonts";
import { C, T12, T13 } from "../tokens";
import { Icon, Screen } from "../ui/Primitives";
import { simSrc } from "../ui/Sim";
import { Img } from "remotion";
import { RECORDING_SECONDS } from "../timeline";

export const RECORDING_TITLE = "Flappy Otter gameplay";

export const TESTS = [
  { at: 2, title: "It should show the title screen and start on tap", check: "Flappy Otter title shown; first tap starts a run at score 0." },
  { at: 6, title: "It should hop the otter on every tap", check: "Each tap applies an upward impulse; otter rises, then falls back." },
  { at: 11, title: "It should score when clearing a log gap", check: "Score increments 0 → 3 as the otter clears three gaps." },
  { at: 19, title: "It should end the run on collision", check: "Splash overlay appears on impact; best score saved as 3." },
  { at: 26, title: "It should pause and resume the run", check: "Pause freezes logs mid-flight; resume continues from score 3." },
  { at: 33, title: "It should keep the best score after relaunch", check: "Quit and relaunched from Home; title screen shows Best 3." },
] as const;

const SUMMARY =
  "Played Flappy Otter on iPhone 17 in the iOS Simulator: title screen, tap-to-hop, scoring through log gaps, collision, pause/resume and relaunch persistence all passed. No crashes or layout issues.";

const MEDIA_W = 864;
const MEDIA_H = 612;

export const playerSimFrame = (t: number): number => 236 + (t / RECORDING_SECONDS) * (470 - 236);

const fmt = (t: number): string => {
  const s = Math.max(0, Math.floor(t));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
};

export const PlayerMedia: React.FC<{ t: number; width: number; height: number; blur?: number }> = ({ t, width, height, blur = 0 }) => {
  const s = (1.3 * width) / MEDIA_W;
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width, height, overflow: "hidden", background: "#e9eef3" }}>
      <Img
        src={simSrc(playerSimFrame(t))}
        style={{
          position: "absolute",
          width: 868 * s,
          height: 652 * s,
          left: width / 2 - 451 * s,
          top: height / 2 - 320 * s,
          filter: blur > 0 ? `blur(${blur}px)` : undefined,
        }}
      />
    </div>
  );
};

export const TestPlayer: React.FC<{ t: number; blur?: number }> = ({ t, blur = 0 }) => {
  const segs = [{ from: 0, to: TESTS[0].at, gray: true }, ...TESTS.map((x, i) => ({ from: x.at, to: i < TESTS.length - 1 ? TESTS[i + 1].at : RECORDING_SECONDS, gray: false }))];
  const trackW = MEDIA_W - 24 - 2 * (segs.length - 1);
  const current = TESTS.reduce((acc, x, i) => (t >= x.at ? i : acc), -1);
  const caption = current >= 0 ? TESTS[current].title : "Setup";
  return (
    <Screen bg={C.panel}>
      <div
        style={{
          height: 40,
          borderBottom: `0.8px solid ${C.hair}`,
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "0 12px 0 16px",
          boxSizing: "border-box",
        }}
      >
        <span style={{ ...T13, fontWeight: 500 }}>{RECORDING_TITLE}</span>
        <div style={{ width: 32, height: 32, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Icon id="727c1" size={18} />
        </div>
      </div>
      <div style={{ position: "absolute", left: 0, top: 40, width: MEDIA_W, height: 680 }}>
        <PlayerMedia t={t} width={MEDIA_W} height={MEDIA_H} blur={blur} />
        <div style={{ position: "absolute", left: 0, top: MEDIA_H, width: MEDIA_W, height: 68, background: "#fff", padding: "8px 12px 12px", boxSizing: "border-box" }}>
          <div style={{ display: "flex", gap: 2, height: 12 }}>
            {segs.map((sg) => {
              const w = ((sg.to - sg.from) / RECORDING_SECONDS) * trackW;
              const fill = Math.max(0, Math.min(1, (t - sg.from) / (sg.to - sg.from)));
              const color = sg.gray ? "#6b7280" : C.teal;
              return (
                <div
                  key={sg.from}
                  style={{
                    width: w,
                    height: 12,
                    borderRadius: 4,
                    overflow: "hidden",
                    position: "relative",
                    background: sg.gray ? "rgba(107,114,128,0.2)" : "rgba(52,211,153,0.2)",
                  }}
                >
                  <div style={{ position: "absolute", left: 0, top: 0, height: 12, width: w * fill, background: color, opacity: fill >= 1 ? 0.85 : 1, borderRadius: 4 }} />
                </div>
              );
            })}
          </div>
          <div style={{ display: "flex", gap: 4, height: 36, alignItems: "center", paddingTop: 8, boxSizing: "border-box" }}>
            {[
              ["f0a27", 14],
              ["24bbb", 16],
              ["85a38", 14],
            ].map(([id, s]) => (
              <div key={id} style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
                <Icon id={String(id)} size={Number(s)} />
              </div>
            ))}
            <div style={{ height: 28, padding: "0 6px", display: "flex", alignItems: "center", fontFamily: mono, fontWeight: 500, fontSize: 11, lineHeight: "14px", letterSpacing: 0.11, color: C.muted }}>
              1x
            </div>
            {["8ad55", "b923f"].map((id) => (
              <div key={id} style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
                <Icon id={id} size={16} />
              </div>
            ))}
            <div style={{ flex: 1 }} />
            <div style={{ display: "flex", gap: 6, fontFamily: mono, fontSize: 11, lineHeight: "14px", letterSpacing: 0.11, whiteSpace: "nowrap" }}>
              <span style={{ color: C.text }}>{caption}</span>
              <span style={{ color: C.faint }}>|</span>
              <span style={{ color: C.muted }}>
                {fmt(t)} / {fmt(RECORDING_SECONDS)}
              </span>
            </div>
          </div>
        </div>
      </div>
      <div style={{ position: "absolute", left: MEDIA_W, top: 40, width: 416, height: 680, borderLeft: `0.8px solid ${C.hair}`, boxSizing: "border-box", background: C.panel }}>
        <div style={{ borderBottom: `0.8px solid ${C.hair}`, padding: "10px 16px", display: "flex", gap: 12 }}>
          {[
            [C.green, `${TESTS.length} passed`],
            [C.red, "0 failed"],
          ].map(([c, l]) => (
            <div key={l} style={{ display: "flex", gap: 6, alignItems: "center" }}>
              <div style={{ width: 8, height: 8, borderRadius: 9999, background: c }} />
              <span style={{ ...T12, color: C.muted }}>{l}</span>
            </div>
          ))}
        </div>
        <div style={{ borderBottom: `0.8px solid ${C.hair}`, padding: "12px 16px" }}>
          <p style={{ margin: 0, fontSize: 12, lineHeight: "19.5px", color: C.muted, width: 384 }}>{SUMMARY}</p>
        </div>
        <div style={{ padding: "4px 0" }}>
          <div style={{ display: "flex", gap: 8, alignItems: "center", padding: "8px 12px" }}>
            <span style={{ width: 32, textAlign: "right", fontFamily: mono, fontSize: 11, lineHeight: "14px", letterSpacing: 0.11, color: C.faint }}>0:00</span>
            <Icon id="b83dd" size={14} />
            <span style={{ fontSize: 12, lineHeight: "16.5px" }}>iPhone 17, iOS 26.5; Xcode 26.6. Fresh install, default settings.</span>
          </div>
        </div>
        {TESTS.map((x, i) => {
          const active = i === current;
          const reached = t >= x.at;
          return (
            <div key={x.at} style={{ paddingTop: 4, height: 83, boxSizing: "border-box", opacity: reached ? 1 : 0.45 }}>
              <div style={{ display: "flex", gap: 8, alignItems: "center", padding: "8px 12px", background: active ? C.blueTint : "transparent" }}>
                <span style={{ width: 32, textAlign: "right", fontFamily: mono, fontSize: 11, lineHeight: "14px", letterSpacing: 0.11, color: C.faint }}>
                  {fmt(x.at)}
                </span>
                <Icon id="2a298" size={14} />
                <span style={{ ...T13, lineHeight: "17.875px", fontWeight: 500, whiteSpace: "nowrap" }}>{x.title}</span>
              </div>
              <div style={{ display: "flex", alignItems: "center", padding: "6px 12px 6px 0", position: "relative" }}>
                <div style={{ width: 72 }} />
                <Icon id={reached ? "834f0" : "b83dd"} size={14} />
                <span style={{ paddingLeft: 8, fontSize: 12, lineHeight: "16.5px", width: 310 }}>{x.check}</span>
                <div
                  style={{
                    position: "absolute",
                    left: 59,
                    top: 0,
                    width: 8,
                    height: 22.5,
                    borderLeft: `0.8px solid ${C.hair}`,
                    borderBottom: `0.8px solid ${C.hair}`,
                    borderBottomLeftRadius: 6,
                  }}
                />
              </div>
            </div>
          );
        })}
      </div>
    </Screen>
  );
};
