import React from "react";
import { AbsoluteFill, Img, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { C, HEIGHT, WIDTH, WIN } from "./tokens";
import { sans } from "./fonts";
import { HOME, HomeChrome } from "./Home";
import { PromptBox, HOME_FONT } from "./PromptBox";
import { COL_W, RightPane, SPLIT_LEFT, Session } from "./Session";
import { DESK, Desktop, PHONE, SCREEN, deskToWin } from "./Desktop";
import { TestPlayer, VIDEO } from "./TestPlayer";
import { Pointer, Ripple } from "./Cursor";
import { GAME, PROMPT, T, charTimes, sim, typeEnd } from "./timeline";
import { Rect, clamp01, easeInOut, easeOut, easeQuint, easeSoft, fadeIn, mix, mixRect, prog } from "./anim";
import { measure } from "./measure";

type V3 = { x: number; y: number; s: number };
type Move = { t0: number; dur: number; to: V3 | ((t: number) => V3); ease?: (v: number) => number };

const caretX = (t: number) => {
  let n = 0;
  while (n < charTimes.length && charTimes[n] <= t) n++;
  return HOME.box.x + 16.6 + measure(PROMPT.slice(0, n), `400 ${HOME_FONT}px ${sans}`);
};
const smoothCaret = (t: number) => {
  let acc = 0;
  const N = 16;
  for (let i = 0; i < N; i++) acc += caretX(t - (i / N) * 0.45);
  return acc / N;
};

const leftWidth = (t: number) => mix(WIN.w, SPLIT_LEFT, prog(t, T.split, T.splitDur, easeQuint));

const paneDesk = (leftW: number): Rect => {
  const w = 557;
  const x0 = leftW + 1;
  return { x: x0 + (WIN.w - x0 - w) / 2, y: 131, w, h: (w * DESK.h) / DESK.w };
};
const playerDesk = (): Rect => {
  const w = VIDEO.w;
  const h = (w * DESK.h) / DESK.w;
  return { x: VIDEO.x, y: VIDEO.y + (VIDEO.h - h) / 2, w, h };
};
const playerP = (t: number) => prog(t, T.toPlayer, T.playerDur, easeQuint);
const deskRect = (t: number) => mixRect(paneDesk(leftWidth(t)), playerDesk(), playerP(t));
const deskClip = (t: number) => mixRect(paneDesk(leftWidth(t)), VIDEO, playerP(t));

const phoneCenter = (d: Rect) => deskToWin(d, PHONE.x + PHONE.w / 2, PHONE.y + PHONE.h / 2 - 8);
const PHONE_S = 3.05;

const MOVES: Move[] = [
  {
    t0: 0.7,
    dur: typeEnd - 0.7 + 0.2,
    to: (t) => ({ x: smoothCaret(t) - 40, y: HOME.box.y + 26, s: 4.4 }),
    ease: easeSoft,
  },
  { t0: typeEnd - 0.05, dur: 1.5, to: { x: 602, y: 392, s: 2.3 } },
  { t0: T.sendClick + 0.05, dur: 1.7, to: { x: 602, y: 330, s: 1.62 } },
  { t0: T.reply + 0.1, dur: 2.2, to: { x: 575, y: 300, s: 1.82 }, ease: easeSoft },
  { t0: T.split - 0.05, dur: 1.5, to: { x: 905, y: 350, s: 1.95 } },
  { t0: T.titleScreen - 0.5, dur: 1.9, to: (t) => ({ ...phoneCenter(deskRect(t)), s: PHONE_S }) },
  { t0: T.gameStart + 0.3, dur: 5.2, to: (t) => ({ ...phoneCenter(deskRect(t)), s: PHONE_S * 1.07 }), ease: easeSoft },
  {
    t0: T.toPlayer,
    dur: T.playerDur,
    to: (t) => {
      const d = deskRect(t);
      return { ...phoneCenter(d), s: (PHONE_S * 1.07 * paneDesk(SPLIT_LEFT).w) / d.w };
    },
    ease: easeQuint,
  },
  { t0: T.toPlayer + T.playerDur - 0.1, dur: 1.6, to: { x: 602, y: 345, s: 1.52 } },
  { t0: T.results - 0.1, dur: 1.8, to: { x: 992, y: 330, s: 2.2 } },
  { t0: T.results + 1.7, dur: 3.2, to: { x: 992, y: 420, s: 2.2 }, ease: easeSoft },
  { t0: T.outro, dur: 2.0, to: { x: 602, y: 345, s: 0.9 }, ease: easeInOut },
];

const INIT: V3 = { x: HOME.box.x + 30, y: HOME.box.y + 26, s: 7.2 };

export const cameraAt = (t: number): V3 => {
  let x = INIT.x;
  let y = INIT.y;
  let ls = Math.log(INIT.s);
  for (const m of MOVES) {
    const p = (m.ease ?? easeInOut)(clamp01((t - m.t0) / m.dur));
    if (p <= 0) continue;
    const to = typeof m.to === "function" ? m.to(Math.min(t, m.t0 + m.dur)) : m.to;
    x = mix(x, to.x, p);
    y = mix(y, to.y, p);
    ls = mix(ls, Math.log(to.s), p);
  }
  return { x, y, s: Math.exp(ls) };
};

type Pt = { x: number; y: number };
const USER_PATH: { t: number; p: Pt; leave: number }[] = [
  { t: 3.95, p: { x: 700, y: 560 }, leave: 4.05 },
  { t: 4.75, p: { x: 296, y: 431.5 }, leave: 4.98 },
  { t: 5.46, p: { x: 318, y: 516.5 }, leave: 5.74 },
  { t: 6.38, p: { x: 893, y: 380.5 }, leave: 6.62 },
  { t: 7.2, p: { x: 930, y: 470 }, leave: 99 },
];
const USER_CLICKS = [T.envClick, T.macClick, T.sendClick];

const curve = (a: Pt, b: Pt, p: number, bend = 0.16): Pt => {
  const mx = (a.x + b.x) / 2;
  const my = (a.y + b.y) / 2;
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const cx = mx - dy * bend;
  const cy = my + dx * bend;
  const u = 1 - p;
  return { x: u * u * a.x + 2 * u * p * cx + p * p * b.x, y: u * u * a.y + 2 * u * p * cy + p * p * b.y };
};

const userCursor = (t: number): Pt => {
  const P = USER_PATH;
  if (t <= P[0].leave) return P[0].p;
  for (let i = 0; i < P.length - 1; i++) {
    const a = P[i];
    const b = P[i + 1];
    if (t < b.t) {
      const p = easeInOut(clamp01((t - a.leave) / (b.t - a.leave)));
      return curve(a.p, b.p, p);
    }
    if (t < b.leave) return b.p;
  }
  return P[P.length - 1].p;
};

const pressAt = (t: number, clicks: number[]) => {
  let s = 1;
  for (const c of clicks) {
    const d = t - c + 0.05;
    if (d > 0 && d < 0.2) s = Math.min(s, 1 - 0.14 * Math.sin((d / 0.2) * Math.PI));
  }
  return s;
};

const gameToWin = (d: Rect, gx: number, gy: number) => {
  const k = SCREEN.w / GAME.w;
  return deskToWin(d, SCREEN.x + gx * k, SCREEN.y + (gy - (GAME.h - SCREEN.h / k) / 2) * k);
};

const TAPS = sim.taps.map((g) => g + T.gameStart);

const devinCursorGame = (t: number): Pt => {
  const g = t - T.gameStart;
  const start = { x: 330, y: 790 };
  const rest = { x: 230, y: 610 };
  if (g < 0) {
    const p = easeInOut(clamp01((t - T.cursorIn) / (T.gameStart - 0.08 - T.cursorIn)));
    return curve(start, rest, p, -0.12);
  }
  return { x: rest.x + Math.sin(g * 0.7) * 22, y: rest.y + Math.sin(g * 1.1 + 1) * 16 };
};

const Window: React.FC<{ t: number }> = ({ t }) => {
  const p = prog(t, T.toSession, T.sessionDur, easeQuint);
  const leftW = leftWidth(t);
  const colLeft = (leftW - COL_W) / 2;
  const sessionBox: Rect = { x: colLeft - 6, y: WIN.h - 8 - 107.6, w: COL_W + 12, h: 107.6 };
  const box = mixRect(HOME.box, sessionBox, p);
  const paneOn = t > T.split - 0.02;
  const pp = playerP(t);
  const playerA = prog(t, T.toPlayer + 0.05, T.playerDur * 0.7, easeOut);
  const d = deskRect(t);

  const uc = userCursor(t);
  const userA = fadeIn(t, 3.95, 0.3) * (1 - fadeIn(t, 6.78, 0.3));
  const gc = devinCursorGame(t);
  const dc = gameToWin(d, gc.x, gc.y);
  const devA = fadeIn(t, T.cursorIn, 0.3) * (1 - fadeIn(t, T.results + 0.6, 0.4));
  const k = d.w / DESK.w;
  const lastTap = TAPS.filter((x) => x <= t).pop();

  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        top: 0,
        width: WIN.w,
        height: WIN.h,
        borderRadius: 12,
        overflow: "hidden",
        background: C.page,
        boxShadow: "0 0 0 1px rgba(0,0,0,0.07), 0 24px 70px rgba(0,0,0,0.07), 0 4px 14px rgba(0,0,0,0.035)",
      }}
    >
      {t >= T.toSession ? <Session t={t} p={p} leftW={leftW} /> : null}
      {t < T.toSession + 0.6 ? <HomeChrome t={t} /> : null}
      <PromptBox t={t} rect={box} p={p} />
      {paneOn ? <RightPane t={t} x={leftW} /> : null}
      {pp > 0 ? <TestPlayer t={t} a={playerA} /> : null}
      {paneOn ? <Desktop t={t} rect={d} clip={deskClip(t)} radius={mix(2, 0, pp)} /> : null}
      {lastTap !== undefined && t - lastTap < 0.34 && devA > 0 ? (
        <Ripple x={dc.x} y={dc.y} p={(t - lastTap) / 0.34} r={9 * k * 1.6} />
      ) : null}
      {devA > 0 ? <Pointer x={dc.x} y={dc.y} scale={pressAt(t, TAPS)} opacity={devA} size={15 * Math.max(0.7, k * 1.4)} /> : null}
      {userA > 0 ? <Pointer x={uc.x} y={uc.y} scale={pressAt(t, USER_CLICKS)} opacity={userA} /> : null}
    </div>
  );
};

const EndCard: React.FC<{ t: number }> = ({ t }) => {
  const a = fadeIn(t, T.endCard, 0.9);
  const b = fadeIn(t, T.endCard + 0.45, 0.9);
  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", fontFamily: sans, opacity: a }}>
      <div style={{ transform: `translateY(${(1 - a) * 10 - 30}px) scale(${0.985 + 0.015 * a})`, display: "flex", flexDirection: "column", alignItems: "center" }}>
        <Img src={staticFile("devin-lockup-black.png")} style={{ width: 440, height: (440 * 1024) / 2984 }} />
        <div style={{ marginTop: 34, fontSize: 40, fontWeight: 500, letterSpacing: "-0.037em", color: C.ink, opacity: b, transform: `translateY(${(1 - b) * 8}px)` }}>
          Now on macOS
        </div>
      </div>
      <div style={{ position: "absolute", bottom: 96, fontSize: 22, letterSpacing: "-0.015em", color: "rgba(25,25,25,0.5)", opacity: b }}>devin.ai</div>
    </AbsoluteFill>
  );
};

export const Main: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const cam = cameraAt(t);
  const winA = 1 - fadeIn(t, T.outro + 0.85, 0.75);
  return (
    <AbsoluteFill style={{ background: C.page }}>
      {winA > 0 ? (
        <div
          style={{
            position: "absolute",
            left: 0,
            top: 0,
            width: WIN.w,
            height: WIN.h,
            opacity: winA,
            transformOrigin: "0 0",
            transform: `translate(${WIDTH / 2}px, ${HEIGHT / 2}px) scale(${cam.s}) translate(${-cam.x}px, ${-cam.y}px)`,
          }}
        >
          <Window t={t} />
        </div>
      ) : null}
      {t > T.endCard - 0.1 ? <EndCard t={t} /> : null}
    </AbsoluteFill>
  );
};

export const Compare: React.FC<{ t: number }> = ({ t }) => (
  <AbsoluteFill style={{ background: C.page }}>
    <div style={{ position: "absolute", left: 0, top: 0, width: WIN.w, height: WIN.h, transformOrigin: "0 0", transform: `scale(${1882 / WIN.w})` }}>
      <Window t={t} />
    </div>
  </AbsoluteFill>
);
