import { AbsoluteFill, Img, staticFile, useCurrentFrame } from "remotion";
import "./theme";
import { GameScene } from "./game/Game";
import { AX, H, W } from "./game/sim";
import { clamp01, cursorAt, ease, fade, keys, prog, typedChars, type Pt } from "./motion";
import { AppleBoot, DESK, Desktop, SCREEN } from "./Simulator";
import { T } from "./timeline";
import { Cursor, Touch } from "./ui/Cursor";
import { ENV, MENU, PROMPT_TEXT, PromptScreen, SEND } from "./ui/Prompt";
import { DESK_IN_PANE, REPLY, RIGHT, Session } from "./ui/Session";
import { PANEL_W, TestViewer } from "./ui/TestViewer";
import { ToolCard, XRayOverlay } from "./ui/XRay";
import { c, font } from "./theme";

const BASE = 1.5;
const DESK_SCALE = DESK_IN_PANE.w / DESK.w;
const GK = Math.max(SCREEN.w / W, SCREEN.h / H);
const G_OFF_Y = (SCREEN.h - H * GK) / 2;
const G_OFF_X = (SCREEN.w - W * GK) / 2;

const gameToCss = (gx: number, gy: number): Pt => ({
  x: RIGHT.x + DESK_IN_PANE.x + (SCREEN.x + G_OFF_X + gx * GK) * DESK_SCALE,
  y: DESK_IN_PANE.y + (SCREEN.y + G_OFF_Y + gy * GK) * DESK_SCALE,
});

const PAUSE_AT = T.pauseTap + 4;
const RESUME_AT = T.press + 8;
const gameTime = (f: number) => {
  const run = Math.min(f, PAUSE_AT) - T.gameStart + Math.max(0, f - RESUME_AT);
  return 8 + Math.max(0, run) / 60;
};

const CAM = [
  { f: 0, x: 640, y: 372, s: 1.16 },
  { f: 140, x: 640, y: 368, s: 1.22 },
  { f: 300, x: 640, y: 362, s: 1.18 },
  { f: 380, x: 640, y: 350, s: 1.04 },
  { f: 470, x: 640, y: 356, s: 1.0 },
  { f: 560, x: 905, y: 356, s: 1.12 },
  { f: 650, x: 950, y: 348, s: 1.34 },
  { f: 770, x: 835, y: 348, s: 1.82 },
  { f: 1170, x: 832, y: 348, s: 1.88 },
  { f: 1290, x: 640, y: 360, s: 1.0 },
  { f: 1340, x: 640, y: 360, s: 1.0 },
  { f: 1440, x: 1000, y: 440, s: 1.5 },
  { f: 1640, x: 1010, y: 448, s: 1.56 },
];

export const Video = () => {
  const f = useCurrentFrame();
  const cam = { x: keys(f, CAM, "x"), y: keys(f, CAM, "y"), s: keys(f, CAM, "s") };
  const k = BASE * cam.s;
  const toScreen = (p: Pt): Pt => ({ x: 960 + (p.x - cam.x) * k, y: 540 + (p.y - cam.y) * k });

  // Prompt beats
  const envPt = { x: ENV.x + 38, y: ENV.y + 11 };
  const macRow = { x: MENU.x + 168, y: MENU.y + 6 + 26 + 31 + 15.5 };
  const sendPt = { x: SEND.x + 15, y: SEND.y + 14 };
  const menuOpen = f < T.envPick ? prog(f, T.envOpen, 12, ease.outCubic) : 1 - prog(f, T.envPick + 2, 10);
  const env = f >= T.envPick ? "macos" : "ubuntu";
  const n = typedChars(PROMPT_TEXT, f, T.typeStart);
  const typing = f >= T.typeStart && n < PROMPT_TEXT.length;
  const caret = f >= T.envPick + 12 && f < T.send + 4 && (typing || Math.floor(f / 32) % 2 === 0);
  const click = (at: number) => Math.sin(Math.PI * clamp01((f - at + 3) / 9));

  // Cursor path (CSS coordinates)
  const resumeCss = gameToCss(AX.resume.x + AX.resume.w / 2 + 14, AX.resume.y + AX.resume.h / 2 + 4);
  const pauseCss = gameToCss(AX.pause.x + 18, AX.pause.y + 18);
  const cursorCss = f < T.session
    ? cursorAt(f, { x: 760, y: 560 }, [
        { f: 18, d: 40, to: envPt },
        { f: 78, d: 30, to: macRow, bend: -0.12 },
        { f: 150, d: 50, to: { x: 820, y: 480 } },
        { f: 280, d: 34, to: sendPt, bend: 0.2 },
      ])
    : cursorAt(f, { x: 1130, y: 470 }, [
        { f: 704, d: 58, to: pauseCss, bend: 0.2 },
        { f: 1000, d: 70, to: resumeCss, bend: -0.22 },
        { f: 1140, d: 60, to: gameToCss(300, 640) },
      ]);
  const cursorO = f < T.session ? fade(f, 10, 20, T.send + 8, 14) : fade(f, 694, 16, 1240, 20);
  const down = Math.max(click(60), click(T.envPick), click(T.send), click(T.pauseTap), click(T.press));
  const cursor = toScreen(cursorCss);

  // Session beats
  const replyChars = Math.floor(clamp01((f - T.reply) / 58) * REPLY.length);
  const rows = Math.max(0, Math.min(6, (f - T.rows) / 13));
  const split = prog(f, T.split, 44, ease.inOutQuint);
  const scroll = keys(f, [{ f: 480, v: 0 }, { f: 530, v: 250 }], "v", ease.inOutCubic);

  const gt = gameTime(f);
  const paused = f < RESUME_AT ? prog(f, PAUSE_AT, 14, ease.outCubic) : 1 - prog(f, RESUME_AT, 12, ease.inOutCubic);
  const menu = f < RESUME_AT ? prog(f, PAUSE_AT, 18, ease.outBack) : 1;
  const bootLogo = fade(f, T.simBoot + 6, 20, T.gameStart - 34, 16);
  const gameO = prog(f, T.gameStart - 20, 20);
  const screen = (withXray: boolean) => (
    <>
      <AppleBoot o={bootLogo} />
      <div style={{ position: "absolute", inset: 0, opacity: gameO }}>
        <GameScene t={gt} paused={paused} menu={menu} />
      </div>
      {withXray && f >= T.xrayIn ? <XRayOverlay f={f} start={T.xrayIn} select={T.result} press={T.press} out={T.xrayOut} /> : null}
    </>
  );
  const pane = (
    <div style={{ position: "absolute", left: DESK_IN_PANE.x, top: DESK_IN_PANE.y, width: DESK.w, height: DESK.h, transform: `scale(${DESK_SCALE})`, transformOrigin: "0 0" }}>
      <Desktop sim={1} screen={f >= T.simBoot ? screen(true) : <div style={{ position: "absolute", inset: 0, background: "#000" }} />} />
    </div>
  );

  // Viewer
  const viewerO = prog(f, T.viewer - 34, 30, ease.inOutCubic);
  const check = clamp01(ease.outBack(clamp01((f - T.check) / 22)));
  const vScale = (608) / DESK.h;
  const video = (
    <div style={{ position: "absolute", left: (1280 - PANEL_W - DESK.w * vScale) / 2, top: 0, width: DESK.w, height: DESK.h, transform: `scale(${vScale})`, transformOrigin: "0 0" }}>
      <Desktop sim={1} screen={screen(false)} />
    </div>
  );
  const secs = 33 + Math.floor(Math.max(0, f - T.viewer) / 60);

  const touchPause = toScreen(pauseCss);
  const touchResume = toScreen(resumeCss);
  const cardO = fade(f, T.query - 14, 20, T.xrayOut + 20, 24);
  const endO = prog(f, T.endCard, 36, ease.inOutCubic);

  return (
    <AbsoluteFill style={{ background: c.page, overflow: "hidden" }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: 1280, height: 720, transformOrigin: "0 0", transform: `translate(${960 - cam.x * k}px, ${540 - cam.y * k}px) scale(${k})` }}>
        {f < T.session + 16 ? (
          <div style={{ position: "absolute", inset: 0, opacity: 1 - prog(f, T.session, 14) }}>
            <PromptScreen typed={PROMPT_TEXT.slice(0, n)} caret={caret} env={env} menuOpen={menuOpen} hover={f > 96 && f < T.envPick + 4 ? 1 : -1} sendDown={click(T.send)} />
          </div>
        ) : null}
        {f >= T.session && viewerO < 1 ? (
          <div style={{ position: "absolute", inset: 0, opacity: prog(f, T.session, 14) }}>
            <Session f={f} split={split} replyChars={replyChars} rows={rows} preparing={prog(f, 470, 14)} scroll={scroll} pane={split > 0 ? pane : undefined} />
          </div>
        ) : null}
        {viewerO > 0 ? (
          <div style={{ position: "absolute", inset: 0, opacity: viewerO, transform: `scale(${0.985 + 0.015 * viewerO})`, transformOrigin: "640px 360px" }}>
            <TestViewer video={<div style={{ position: "absolute", inset: 0 }}>{video}</div>} check={check} time={`0:${secs}`} segFill={clamp01((f - T.viewer) / 340)} />
          </div>
        ) : null}
      </div>
      <Touch x={touchPause.x} y={touchPause.y} t={(f - T.pauseTap) / 34} />
      <Touch x={touchResume.x} y={touchResume.y} t={(f - T.press) / 34} />
      {cardO > 0 ? (
        <div style={{ position: "absolute", left: 252, top: 540, transform: `translateY(-50%) scale(1.5) translateX(${(1 - cardO) * -8}px)`, transformOrigin: "0 50%", opacity: cardO }}>
          <ToolCard f={f} query={T.query} result={T.result} act={T.act} done={T.resumed + 4} />
        </div>
      ) : null}
      {cursorO > 0 ? <Cursor x={cursor.x} y={cursor.y} down={down} o={cursorO} /> : null}
      {endO > 0 ? (
        <AbsoluteFill style={{ background: c.page, opacity: endO, alignItems: "center", justifyContent: "center" }}>
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 34, transform: `translateY(${(1 - prog(f, T.endCard + 10, 50, ease.outQuint)) * 14}px)` }}>
            <Img src={staticFile("devin-lockup-black.png")} style={{ height: 92, opacity: prog(f, T.endCard + 12, 30) }} />
            <div style={{ fontFamily: font.sans, fontSize: 34, letterSpacing: -0.4, color: "#474747", opacity: prog(f, T.endCard + 36, 30) }}>Devin, now on macOS</div>
          </div>
        </AbsoluteFill>
      ) : null}
    </AbsoluteFill>
  );
};

