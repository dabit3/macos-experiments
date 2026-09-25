import { Img, OffthreadVideo, Sequence, staticFile } from "remotion";
import { Apple, Chevron, Expand, Icon, Laptop, Progress, Sidebar } from "./Icon";
import { PROMPT } from "./Home";
import { C, inter, outQuint, ramp, text } from "./theme";

export const LEFT_W = 629;
const DESK = { x: 637, y: 131, w: 565, h: 423.75 };
const SCR_K = DESK.w / 1600;
export const SIM_SCREEN = {
  x: DESK.x + 628 * SCR_K,
  y: DESK.y + 168 * SCR_K,
  w: 402 * SCR_K,
  h: 874 * SCR_K,
};

export const SESSION_T = {
  reply: 22,
  worked: 64,
  rows: [92, 116, 142, 170],
  bootFrom: 36,
  appFrom: 160,
};

const REPLY =
  "On it \u2014 building an otter Flappy Bird iOS game in SwiftUI and SpriteKit, then building and testing it on the iOS Simulator.";

const ROWS: { kind: "cmd" | "thought"; text: string; time?: string }[] = [
  {
    kind: "cmd",
    text: "brew install xcodegen swiftformat 2>&1 | tail -3; xcrun simctl list devices available | rg -i iphone | head",
    time: "9s",
  },
  { kind: "thought", text: "Thought for 6s" },
  {
    kind: "cmd",
    text: "cd ios-otter-flap && xcodegen generate && xcodebuild -scheme OtterFlap -sdk iphonesimulator -derivedDataPath build build",
    time: "21s",
  },
  {
    kind: "cmd",
    text: "xcrun simctl boot \"iPhone 17\"; open -a Simulator; xcrun simctl install booted build/OtterFlap.app",
    time: "4s",
  },
];

const Reveal: React.FC<{ frame: number; at: number; children: React.ReactNode }> = ({
  frame,
  at,
  children,
}) => {
  const t = ramp(frame, at, at + 22, outQuint);
  if (t <= 0) return null;
  return (
    <div style={{ opacity: t, transform: `translateY(${(1 - t) * 6}px)` }}>{children}</div>
  );
};

const Btn: React.FC<{ children: React.ReactNode; active?: boolean; w?: number }> = ({ children, active, w }) => (
  <div
    style={{
      height: 28,
      minWidth: 28,
      width: w,
      borderRadius: 6,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      gap: 2,
      paddingRight: w ? 6 : 0,
      paddingLeft: w ? 3 : 0,
      boxSizing: "border-box",
      background: active ? "rgba(0,0,0,0.06)" : undefined,
    }}
  >
    {children}
  </div>
);

const StreamText: React.FC<{ frame: number; at: number; value: string; perWord?: number }> = ({
  frame,
  at,
  value,
  perWord = 1.6,
}) => {
  const words = value.split(" ");
  return (
    <>
      {words.map((w, i) => {
        const o = ramp(frame, at + i * perWord, at + i * perWord + 10, outQuint);
        return (
          <span key={i} style={{ opacity: o }}>
            {w}
            {i < words.length - 1 ? " " : ""}
          </span>
        );
      })}
    </>
  );
};

export const Session: React.FC<{ frame: number }> = ({ frame }) => {
  const f = frame;
  const workingSecs = Math.min(38, Math.floor(Math.max(0, f - SESSION_T.rows[0]) / 5.2) + 1);
  const bootLogo = ramp(f, SESSION_T.bootFrom + 18, SESSION_T.bootFrom + 40, outQuint);
  const appIn = ramp(f, SESSION_T.appFrom, SESSION_T.appFrom + 18, outQuint);
  const pulse = 0.55 + 0.45 * Math.cos((f / 60) * Math.PI * 2);
  const status = f < SESSION_T.rows[3] ? "Preparing iOS build tools" : "Testing Otter Flap in the iOS Simulator";

  return (
    <div style={{ position: "absolute", inset: 0, background: C.page, fontFamily: inter }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: LEFT_W, height: "100%" }}>
        <div style={{ position: "absolute", left: 10, top: 8, right: 7, height: 28, display: "flex", alignItems: "center" }}>
          <Btn>
            <Sidebar size={18} />
          </Btn>
          <div style={{ marginLeft: 20, ...text(13, 18, 400) }}>Create Otter Flappy Bird iOS App</div>
          <div
            style={{
              marginLeft: 6,
              height: 20,
              padding: "0 6px 0 5px",
              borderRadius: 5,
              background: "rgba(51,125,244,0.1)",
              display: "flex",
              alignItems: "center",
              gap: 4,
              ...text(13, 18, 400, "#1c6ae4"),
            }}
          >
            <Laptop size={14} />
            macOS
          </div>
          <div style={{ flex: 1 }} />
          <Btn>
            <Icon name="session-info" size={18} />
          </Btn>
          <Btn>
            <Icon name="flag" size={18} />
          </Btn>
          <Btn>
            <Icon name="dots" size={16} />
          </Btn>
        </div>

        <div style={{ position: "absolute", left: 24, right: 24, top: 60 }}>
          <div style={{ display: "flex", justifyContent: "flex-end" }}>
            <div
              style={{
                maxWidth: 380,
                background: "rgba(0,0,0,0.04)",
                borderRadius: "16px 4px 16px 16px",
                padding: "8px 14px",
                ...text(14, 20, 400),
              }}
            >
              {PROMPT}
            </div>
          </div>

          <div style={{ marginTop: 22, ...text(14, 20, 400) }}>
            <StreamText frame={f} at={SESSION_T.reply} value={REPLY} />
          </div>

          <Reveal frame={f} at={SESSION_T.worked}>
            <div style={{ marginTop: 18, display: "flex", alignItems: "center", gap: 8 }}>
              <Icon name="chevron-right" size={16} />
              <span style={text(13, 18, 400, C.muted)}>Worked for 38s</span>
            </div>
          </Reveal>

          <Reveal frame={f} at={SESSION_T.rows[0] - 10}>
            <div style={{ marginTop: 20, display: "flex", alignItems: "center", gap: 8 }}>
              <Chevron size={16} color="rgba(25,25,25,0.56)" />
              <span style={text(13, 18, 400, C.muted)}>Working for {workingSecs}s</span>
            </div>
          </Reveal>

          <div style={{ marginLeft: 7, marginTop: 6, borderLeft: `0.8px solid ${C.hairline}`, paddingLeft: 17 }}>
            {ROWS.map((r, i) => (
              <Reveal key={i} frame={f} at={SESSION_T.rows[i]}>
                {r.kind === "cmd" ? (
                  <div style={{ display: "flex", gap: 16, padding: "4px 0" }}>
                    <div style={{ flex: 1, ...text(13, 19, 400, C.muted)}}>{r.text}</div>
                    <div style={{ ...text(13, 19, 400, C.faint) }}>{r.time}</div>
                  </div>
                ) : (
                  <div style={{ display: "flex", alignItems: "center", gap: 4, padding: "4px 0" }}>
                    <span style={text(13, 19, 400, C.muted)}>{r.text}</span>
                    <Icon name="chevron-right" size={14} />
                  </div>
                )}
              </Reveal>
            ))}
          </div>

          <Reveal frame={f} at={SESSION_T.worked + 8}>
            <div style={{ marginTop: 16, display: "flex", alignItems: "center", gap: 8 }}>
              <Img src={staticFile("devin-mark.png")} style={{ width: 15, height: 15, opacity: 0.55 + 0.45 * pulse }} />
              <span style={text(13, 18, 400, C.muted)}>{status}</span>
            </div>
          </Reveal>
        </div>

        <div
          style={{
            position: "absolute",
            left: 14,
            right: 14,
            bottom: 10,
            height: 106,
            borderRadius: 20,
            background: "#fff",
            border: `0.8px solid ${C.border}`,
            boxSizing: "border-box",
          }}
        >
          <div style={{ position: "absolute", left: 16, top: 16, display: "flex", alignItems: "center", ...text(14, 20, 400, C.muted) }}>
            Guide Devin while it works, or press
            <span style={{ display: "inline-flex", gap: 2, margin: "0 4px" }}>
              {(["kbd-cmd", "kbd-enter"] as const).map((k) => (
                <span key={k} style={{ width: 16, height: 16, borderRadius: 2, background: "rgba(0,0,0,0.06)", display: "flex", alignItems: "center", justifyContent: "center" }}>
                  <Icon name={k} size={12} />
                </span>
              ))}
            </span>
            to queue
          </div>
          <div style={{ position: "absolute", left: 12, bottom: 12, display: "flex", alignItems: "center", gap: 1 }}>
            <Btn>
              <Icon name="plus" size={18} />
            </Btn>
            <Btn>
              <Icon name="slash" size={18} />
            </Btn>
            <div style={{ marginLeft: 6, ...text(13, 18, 400, C.muted) }}>Opus 5.5 (Preview)</div>
          </div>
          <div style={{ position: "absolute", right: 12, bottom: 12, display: "flex", alignItems: "center", gap: 4 }}>
            <Btn>
              <Icon name="mic" size={18} />
            </Btn>
            <Btn>
              <Icon name="voice" size={18} />
            </Btn>
            <div style={{ width: 28, height: 28, borderRadius: 9999, background: "#1f1f1f", display: "flex", alignItems: "center", justifyContent: "center" }}>
              <Icon name="stop" size={18} />
            </div>
          </div>
        </div>
      </div>

      <div style={{ position: "absolute", left: LEFT_W, top: 0, width: 0.8, height: "100%", background: C.hairline }} />

      <div style={{ position: "absolute", left: LEFT_W + 1, top: 0, right: 0, height: "100%" }}>
        <div style={{ position: "absolute", left: 8, right: 8, top: 8, height: 28, display: "flex", alignItems: "center", gap: 4 }}>
          <Btn w={90}>
            <span style={{ width: 22, display: "flex", justifyContent: "center" }}>
              <Progress size={16} color="rgba(25,25,25,0.8)" />
            </span>
            <span style={text(13, 18, 400, C.muted)}>Progress</span>
          </Btn>
          <Btn w={96} active>
            <span style={{ width: 22, display: "flex", justifyContent: "center" }}>
              <Icon name="computer" size={16} />
            </span>
            <span style={text(13, 18, 400)}>Computer</span>
          </Btn>
          <Btn>
            <Icon name="plus" size={18} />
          </Btn>
          <div style={{ flex: 1 }} />
          <Btn>
            <Expand size={18} />
          </Btn>
          <Btn>
            <Icon name="panel" size={18} />
          </Btn>
        </div>
      </div>

      <div
        style={{
          position: "absolute",
          left: DESK.x,
          top: DESK.y,
          width: DESK.w,
          height: DESK.h,
          overflow: "hidden",
          background: "#000",
        }}
      >
        <Img src={staticFile("desktop.jpg")} style={{ width: "100%", height: "100%", display: "block" }} />
      </div>

      <div
        style={{
          position: "absolute",
          left: SIM_SCREEN.x,
          top: SIM_SCREEN.y,
          width: SIM_SCREEN.w,
          height: SIM_SCREEN.h,
          borderRadius: 20,
          overflow: "hidden",
          background: "#000",
        }}
      >
        <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", opacity: bootLogo }}>
          <Apple size={30} color="#fff" />
        </div>
        <Sequence from={SESSION_T.appFrom} layout="none">
          <OffthreadVideo
            src={staticFile("otter.mp4")}
            playbackRate={0.3}
            muted
            style={{ position: "absolute", inset: 0, width: "100%", height: "100%", opacity: appIn }}
          />
        </Sequence>
      </div>

      <div style={{ position: "absolute", left: DESK.x, width: DESK.w, top: 628, height: 8, borderRadius: 2, background: "rgba(51,125,244,0.2)" }}>
        <div style={{ position: "absolute", right: 0, top: -3, width: 1.6, height: 14, background: "#1f6bff" }} />
      </div>
      <div style={{ position: "absolute", left: DESK.x - 2, width: DESK.w + 4, top: 650, height: 28, display: "flex", alignItems: "center", gap: 6 }}>
        <Btn>
          <Chevron dir="right" size={16} color="#191919" style={{ transform: "scaleX(-1)" }} />
        </Btn>
        <Btn>
          <Chevron dir="right" size={16} color="#191919" />
        </Btn>
        <div
          style={{
            height: 26,
            padding: "0 10px",
            borderRadius: 9999,
            border: `0.8px solid ${C.border}`,
            display: "flex",
            alignItems: "center",
            gap: 6,
            ...text(13, 18, 400),
          }}
        >
          <span style={{ width: 7, height: 7, borderRadius: 4, background: "#f53b3a" }} />
          Live
        </div>
        <div style={{ flex: 1 }} />
        <span style={text(13, 18, 400)}>Auto (reduced)</span>
        <Chevron size={12} color="#191919" />
      </div>
    </div>
  );
};
