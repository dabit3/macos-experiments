import { useCurrentFrame } from "remotion";
import { camStyle, camTrack, cursorAt, easeInOut, pressAt, ramp, track } from "../anim";
import { F } from "../timeline";
import { C, T12, T13, T14 } from "../tokens";
import { QueuePlaceholder, Status, UserBubble, WorkHeader, WorkRow, WorkRows } from "../ui/Chat";
import { ChatInput, ClickRing, Cursor, Icon, IconButton, Screen, SessionHeader } from "../ui/Primitives";
import { Sim, SIM_H, SIM_W } from "../ui/Sim";
import { PROMPT } from "./Home";

export const SESSION_TITLE = "Create Otter Flappy Bird iOS App";

const REPLY =
  "On it — building an otter Flappy Bird iOS game in SpriteKit, then I'll run it in the iOS Simulator and test it myself.";
const AFTER = "Build succeeded. Launching Flappy Otter on the iPhone 17 Simulator to play-test it with computer use.";

const ROWS: readonly WorkRow[] = [
  { kind: "think", text: "Thought for 4s" },
  { kind: "cmd", text: "xcrun simctl list devices available", meta: "2s" },
  { kind: "file", text: "FlappyOtter/project.yml", meta: "+38" },
  { kind: "file", text: "Sources/GameScene.swift", meta: "+214" },
  { kind: "file", text: "Sources/Otter.swift", meta: "+71" },
  { kind: "cmd", text: "xcodebuild -scheme FlappyOtter -sdk iphonesimulator build", meta: "21s" },
];

const PANE_W = 656;
const TAPS = [1119, 1150, 1178, 1206, 1236, 1264] as const;

const linear = (t: number) => t;

export const simFrameAt = (f: number): number =>
  track(
    f,
    [
      [F.paneOpen, 96],
      [F.computerStart, 200],
      [F.playerStart + 30, 440],
    ],
    linear,
  );

const words = (text: string, f: number, start: number, perWord = 2.4): string => {
  const all = text.split(" ");
  const n = Math.max(0, Math.min(all.length, Math.floor((f - start) / perWord)));
  return all.slice(0, n).join(" ");
};

const ProgressIcon: React.FC = () => (
  <svg width={16} height={16} viewBox="0 0 16 16">
    <path d="M3 4.5h10M3 8h10M3 11.5h6" stroke={C.muted} strokeWidth="1.3" strokeLinecap="round" fill="none" />
  </svg>
);

const ComputerPane: React.FC<{ x: number; f: number }> = ({ x, f }) => {
  const simW = PANE_W - 16;
  const simH = (simW * SIM_H) / SIM_W;
  const canvasH = 720 - 52 - 8 - 54;
  const live = ramp(f, F.paneOpen, F.computerStart + 200, linear);
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: 0,
        width: PANE_W,
        height: 720,
        background: C.bg,
        borderLeft: `0.8px solid ${C.hair}`,
      }}
    >
      <div style={{ height: 44, display: "flex", alignItems: "center", padding: "8px 7px 8px 8px", boxSizing: "border-box", gap: 4 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6, height: 28, padding: "0 8px", borderRadius: 6, ...T13, color: C.muted }}>
          <ProgressIcon />
          Progress
        </div>
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 6,
            height: 28,
            padding: "0 9px 0 8px",
            borderRadius: 6,
            background: "rgba(0,0,0,0.06)",
            ...T13,
          }}
        >
          <Icon id="e686f" size={16} />
          Computer
        </div>
        <IconButton id="2c01e" />
        <div style={{ flex: 1 }} />
        <IconButton id="88457" />
        <IconButton id="c8a98" />
      </div>
      <div style={{ position: "absolute", left: 8, top: 52, width: simW, height: canvasH, display: "flex", alignItems: "center" }}>
        <Sim frame={simFrameAt(f)} width={simW} style={{ borderRadius: 2 }} />
      </div>
      <div style={{ position: "absolute", left: 12, top: 52 + canvasH, width: simW - 8, height: 54 }}>
        <div style={{ position: "relative", height: 18, display: "flex", alignItems: "center" }}>
          <div style={{ position: "absolute", left: 0, right: 0, top: 2, height: 10, borderRadius: 4, background: "#c6d8fe" }} />
          <div style={{ position: "absolute", left: 0, width: `${(0.6 + live * 0.4) * 100}%`, top: 2, height: 10, borderRadius: 2, background: C.live }} />
          <div style={{ position: "absolute", left: `calc(${(0.6 + live * 0.4) * 100}% - 3px)`, top: -1, width: 3, height: 16, background: C.live }} />
        </div>
        <div style={{ height: 36, display: "flex", alignItems: "center", gap: 8 }}>
          <IconButton id="f2c32" round />
          <IconButton id="a75fe" round />
          <div
            style={{
              height: 28,
              border: `0.8px solid ${C.hair}`,
              borderRadius: 9999,
              display: "flex",
              alignItems: "center",
              gap: 6,
              padding: "0 10px",
              boxSizing: "border-box",
            }}
          >
            <div style={{ width: 8, height: 8, borderRadius: 9999, background: C.red }} />
            <span style={{ ...T13, fontWeight: 500, color: C.muted }}>Live</span>
          </div>
          <div style={{ flex: 1 }} />
          <IconButton id="70d39" round />
          <div style={{ display: "flex", alignItems: "center", gap: 3, height: 24, padding: "0 8px" }}>
            <span style={{ ...T12, fontWeight: 500, color: C.muted }}>Auto</span>
            <Icon id="fc52a" size={14} />
          </div>
          <IconButton id="9e415" round />
        </div>
      </div>
      <div style={{ position: "absolute", left: 8, top: 52 + (canvasH - simH) / 2, width: simW, height: simH }} />
    </div>
  );
};

export const PHONE = (paneX: number) => {
  const s = (PANE_W - 16) / SIM_W;
  const canvasH = 720 - 52 - 8 - 54;
  const top = 52 + (canvasH - (SIM_H * s)) / 2;
  return { x: paneX + 8 + 451 * s, y: top + 320 * s, s, top, left: paneX + 8 };
};

export const SessionScene: React.FC = () => {
  const f = useCurrentFrame();
  const p = ramp(f, F.paneOpen, F.paneOpenEnd, easeInOut);
  const colW = 720 + (576 - 720) * p;
  const colX = 280 + (24 - 280) * p;
  const leftW = 1280 + (624 - 1280) * p;
  const paneX = 1280 - PANE_W * p;
  const phone = PHONE(624);

  const cam = camTrack(f, [
    [F.toSessionStart, { x: 680, y: 300, z: 1.42 }],
    [F.rows + 20, { x: 650, y: 300, z: 1.36 }],
    [F.paneOpen - 10, { x: 640, y: 300, z: 1.3 }],
    [F.paneOpenEnd + 10, { x: 640, y: 360, z: 1 }],
    [F.computerStart, { x: 660, y: 360, z: 1.04 }],
    [F.computerStart + 60, { x: phone.x - 20, y: phone.y + 10, z: 1.72 }],
    [F.playerStart - 10, { x: phone.x - 10, y: phone.y + 6, z: 1.82 }],
  ]);

  const bubbleO = ramp(f, F.bubble, F.bubble + 16);
  const reply = words(REPLY, f, F.reply);
  const rowShown = (i: number) => ramp(f, F.rows + i * 16, F.rows + i * 16 + 12);
  const collapse = ramp(f, F.paneOpen - 22, F.paneOpen + 6, easeInOut);
  const rowsH = (ROWS.reduce((a, _, i) => a + ramp(f, F.rows + i * 16 - 4, F.rows + i * 16 + 8, easeInOut) * 26, 0) + 4) * (1 - collapse);
  const secs = Math.min(38, Math.max(0, Math.floor((f - F.rows + 20) / 3.3)));
  const header = collapse > 0.5 ? "Worked for 38s" : `Working for ${secs}s`;
  const after = words(AFTER, f, F.paneOpen + 16);
  const status =
    f < F.paneOpen ? "Preparing iOS build tools" : f < F.computerStart ? "Booting iPhone 17 Simulator" : "Testing Flappy Otter with computer use";

  const waypoints = [
      { f: F.computerStart + 20, x: phone.x + 150, y: phone.y + 230 },
      { f: TAPS[0] - 4, x: phone.x + 6, y: phone.y + 70 },
      { f: TAPS[1] - 4, x: phone.x - 16, y: phone.y + 40 },
      { f: TAPS[2] - 4, x: phone.x + 10, y: phone.y + 56 },
      { f: TAPS[3] - 4, x: phone.x - 4, y: phone.y + 30 },
      { f: TAPS[4] - 4, x: phone.x + 14, y: phone.y + 48 },
      { f: TAPS[5] - 4, x: phone.x, y: phone.y + 36 },
  ];
  const cur = cursorAt(f, waypoints, 0.12);
  const cursorO = ramp(f, F.computerStart + 10, F.computerStart + 30);
  const tapNear = TAPS.map((t) => ({ t, k: (f - t) / 22, at: cursorAt(t - 4, waypoints, 0.12) }));

  return (
    <Screen>
      <div style={camStyle(cam)}>
        <SessionHeader title={SESSION_TITLE} width={leftW} showPanelToggle={p < 0.5} />
        <div style={{ position: "absolute", left: colX, top: 60, width: colW, display: "flex", flexDirection: "column", gap: 14 }}>
          <UserBubble text={PROMPT} opacity={bubbleO} y={(1 - bubbleO) * 8} />
          {f >= F.reply ? <div style={{ ...T14 }}>{reply}</div> : null}
          {f >= F.rows - 4 ? (
            <div>
              <WorkHeader label={header} open={1 - collapse} />
              <WorkRows rows={ROWS} shown={rowShown} height={rowsH} />
            </div>
          ) : null}
          {f >= F.paneOpen + 16 ? <div style={{ ...T14 }}>{after}</div> : null}
          {f >= F.rows + 40 ? <Status text={status} opacity={ramp(f, F.rows + 40, F.rows + 56)} /> : null}
        </div>
        <div style={{ position: "absolute", left: (leftW - (colW + 28)) / 2 + 0, top: 720 - 8 - 107.6 }}>
          <ChatInput width={colW + 28} placeholder={<QueuePlaceholder />} model="Opus 5.5 (Preview)" working />
        </div>
        <ComputerPane x={paneX} f={f} />
        {f > F.computerStart ? (
          <>
            {tapNear.map(({ t, k, at }) => (
              <ClickRing key={t} x={at.x} y={at.y} t={k} />
            ))}
            <Cursor x={cur.x} y={cur.y} opacity={cursorO} press={pressAt(f, TAPS)} scale={0.9} />
          </>
        ) : null}
      </div>
    </Screen>
  );
};
