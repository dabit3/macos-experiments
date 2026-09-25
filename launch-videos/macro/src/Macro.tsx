import React, { useEffect, useState } from "react";
import { AbsoluteFill, Img, OffthreadVideo, Sequence, continueRender, delayRender, interpolate, random, staticFile, useCurrentFrame } from "remotion";
import { measureText } from "@remotion/layout-utils";
import { FULL, Camera, Key, bez, cubic, outQuint, pulse, quint, track } from "./camera";
import { C, inter, fontsReady, text } from "./theme";
import { Cursor } from "./ui/Icon";
import { HOME, Home } from "./ui/Home";
import { DESK, SESSION, Session } from "./ui/Session";
import { PLAYER, TestPlayer, VIDEO_H, VIDEO_W } from "./ui/TestPlayer";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const PROMPT = "Build Flappy Bird with an Otter. Then build and test it on iOS.";
const TYPE_START = 64;

const CHAR_AT: number[] = (() => {
  const out: number[] = [];
  let f = TYPE_START;
  for (let i = 0; i < PROMPT.length; i++) {
    out.push(f);
    const ch = PROMPT[i];
    let d = 2.4 + random(`k${i}`) * 2.2;
    if (ch === " ") d += random(`s${i}`) * 1.8;
    if (ch === ".") d += 12;
    if (ch === "," || PROMPT[i + 1] === "O" || PROMPT[i + 1] === "i") d += 2;
    f += d;
  }
  out.push(f);
  return out;
})();
export const TE = Math.round(CHAR_AT[PROMPT.length]);

type Way = { f: number; x: number; y: number; bow?: number };
const cursorAt = (f: number, ws: Way[]) => {
  if (f <= ws[0].f) return ws[0];
  for (let i = 1; i < ws.length; i++) {
    const a = ws[i - 1];
    const b = ws[i];
    if (f <= b.f) {
      const t = quint((f - a.f) / (b.f - a.f));
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const bow = b.bow ?? 0.18;
      const c: [number, number] = [(a.x + b.x) / 2 - dy * bow, (a.y + b.y) / 2 + dx * bow];
      return bez(t, [a.x, a.y], c, [b.x, b.y]);
    }
  }
  return ws[ws.length - 1];
};

const useFonts = () => {
  const [ready, setReady] = useState(false);
  const [handle] = useState(() => delayRender("fonts"));
  useEffect(() => {
    fontsReady().then(() => {
      setReady(true);
      continueRender(handle);
    });
  }, [handle]);
  return ready;
};

const typedWidth = (s: string) => (s.length === 0 ? 0 : measureText({ text: s, fontFamily: inter, fontSize: 14, fontWeight: "400", letterSpacing: "-0.07px" }).width);

export const PROMPT_LEN = TE + 345;

export const ScenePrompt: React.FC = () => {
  const f = useCurrentFrame();
  const ready = useFonts();
  const n = CHAR_AT.filter((t, i) => i < PROMPT.length && f >= t).length;
  const typed = PROMPT.slice(0, n);
  const lastKey = n > 0 ? CHAR_AT[n - 1] : -100;
  const idle = f - lastKey > 12;
  const caret = !idle || Math.floor((f - lastKey) / 32) % 2 === 1 || n === 0 ? (n === 0 ? Math.floor(f / 32) % 2 === 0 : true) : false;

  const caretX = (g: number) => {
    const k = CHAR_AT.filter((t, i) => i < PROMPT.length && g >= t).length;
    return HOME.textX + (ready ? typedWidth(PROMPT.slice(0, k)) : 0);
  };
  const smooth = (g: number) => {
    let s = 0;
    let wsum = 0;
    for (let i = 0; i < 24; i++) {
      const w = 24 - i;
      s += caretX(g - i) * w;
      wsum += w;
    }
    return s / wsum;
  };

  const textY = HOME.textY + 10;
  const envC = { x: HOME.env.x + 34, y: HOME.env.y + 8 };
  const badge = { x: HOME.menu.x + 4 + 10 + 14 + 8 + 41 + 8 + 13, y: HOME.menu.y + 4 + 28 + 30 + 15 };
  const send = HOME.send;

  const typeCam = (g: number) => {
    const p = interpolate(g, [TYPE_START, TE], [0, 1], clamp);
    const z = interpolate(p, [0, 1], [5.2, 3.1], { easing: cubic });
    return { x: smooth(g) + interpolate(p, [0, 1], [18, -40]), y: textY, z };
  };

  const keys: Key[] = [
    { f: 0, x: HOME.textX + 26, y: textY, z: 6.2 },
    { f: TYPE_START, x: HOME.textX + 18, y: textY, z: 5.2, ease: outQuint },
  ];
  const tEnd = typeCam(TE + 14);
  const post: Key[] = [
    { f: TE + 14, ...tEnd },
    { f: TE + 62, x: envC.x + 6, y: envC.y + 6, z: 5.2, ease: quint },
    { f: TE + 106, x: badge.x - 14, y: badge.y - 12, z: 5.8 },
    { f: TE + 136, x: badge.x - 10, y: badge.y - 10, z: 6.0, ease: (t) => t },
    { f: TE + 196, x: send.x - 8, y: send.y, z: 5.4, ease: quint },
    { f: TE + 226, x: send.x - 6, y: send.y, z: 5.6, ease: (t) => t },
    { f: TE + 306, ...FULL, ease: quint },
    { f: TE + 345, x: FULL.x, y: FULL.y, z: 1.015, ease: (t) => t },
  ];
  let cam;
  if (f < TYPE_START) cam = track(f, keys);
  else if (f <= TE + 14) cam = typeCam(f);
  else cam = track(f, post);

  const menu = interpolate(f, [TE + 58, TE + 70], [0, 1], { ...clamp, easing: outQuint }) * interpolate(f, [TE + 138, TE + 146], [1, 0], clamp);
  const env = f >= TE + 138 ? "macos" : "ubuntu";
  const hover = f >= TE + 96 ? "macos" : f >= TE + 70 ? "ubuntu" : null;
  const press = pulse(f, TE + 210, 5, 12);
  const clickEnv = pulse(f, TE + 54, 4, 8);
  const clickMac = pulse(f, TE + 132, 4, 8);

  const cur = cursorAt(f, [
    { f: TE + 10, x: envC.x + 70, y: envC.y + 60 },
    { f: TE + 52, x: envC.x + 4, y: envC.y + 1 },
    { f: TE + 76, x: envC.x + 4, y: envC.y + 1 },
    { f: TE + 104, x: badge.x + 58, y: badge.y + 3, bow: -0.2 },
    { f: TE + 146, x: badge.x + 58, y: badge.y + 3 },
    { f: TE + 200, x: send.x - 2, y: send.y + 2, bow: 0.12 },
  ]);

  return (
    <Camera cam={cam}>
      <Home typed={typed} caret={caret} env={env} menu={menu} hover={hover} press={press} />
      {f >= TE + 10 ? <Cursor x={cur.x} y={cur.y} press={Math.max(clickEnv, clickMac, press)} opacity={interpolate(f, [TE + 10, TE + 22, TE + 250, TE + 290], [0, 1, 1, 0], clamp)} /> : null}
    </Camera>
  );
};

export const BUILD_LEN = 540;

export const SceneBuild: React.FC = () => {
  const f = useCurrentFrame();
  const workSec = Math.min(38, 31 + Math.floor(Math.max(0, f - 12) / 11));
  const done = f >= 100;
  const w = SESSION.worked;
  const s = SESSION.status;
  const cam = track(f, [
    { f: 0, x: w.x + 70, y: w.y + 9, z: 5.6 },
    { f: 104, x: w.x + 84, y: w.y + 9, z: 5.0, ease: (t) => t },
    { f: 176, x: s.x + 80, y: s.y + 9, z: 4.4, ease: quint },
    { f: 196, x: s.x + 86, y: s.y + 9, z: 4.3, ease: (t) => t },
    { f: 286, ...FULL, ease: quint },
    { f: BUILD_LEN, x: FULL.x + 40, y: FULL.y, z: 1.035, ease: (t) => t },
  ]);
  return (
    <Camera cam={cam}>
      <Session
        workSec={workSec}
        done={done}
        phase={f / 9}
        screen={<OffthreadVideo src={staticFile("computer.mp4")} playbackRate={1.25} muted style={{ width: DESK.w, height: DESK.h, objectFit: "cover", display: "block" }} />}
      />
    </Camera>
  );
};

export const TEST_LEN = 540;
const PHONE = { x: 455, y: 330 };
const vScale = Math.max(VIDEO_W / 872, VIDEO_H / 654);
const vOff = { x: (VIDEO_W - 872 * vScale) / 2, y: (VIDEO_H - 654 * vScale) / 2 };
const TAPS = [382, 408, 430, 462, 486, 512];

export const SceneTest: React.FC = () => {
  const f = useCurrentFrame();
  const t = 30.4 + f / 60;
  const seg = PLAYER.segEnd(5);
  const cap = PLAYER.caption;
  const chk = PLAYER.check(5);
  const cam = track(f, [
    { f: 0, x: seg.x - 26, y: seg.y + 4, z: 6.0 },
    { f: 150, x: seg.x - 2, y: seg.y + 6, z: 5.2, ease: (t2) => t2 },
    { f: 212, x: cap.x - 104, y: cap.y - 4, z: 4.2, ease: quint },
    { f: 236, x: cap.x - 100, y: cap.y - 4, z: 4.2, ease: (t2) => t2 },
    { f: 292, x: chk.x + 24, y: chk.y - 8, z: 6.0, ease: quint },
    { f: 322, x: chk.x + 26, y: chk.y - 8, z: 6.0, ease: (t2) => t2 },
    { f: 400, ...FULL, ease: quint },
    { f: TEST_LEN, x: FULL.x, y: FULL.y, z: 1.03, ease: (t2) => t2 },
  ]);
  const checkP = interpolate(f, [284, 318], [0, 1], { ...clamp, easing: cubic });
  const ph = { x: vOff.x + PHONE.x * vScale, y: 40 + vOff.y + PHONE.y * vScale };
  const tapPress = Math.max(...TAPS.map((a) => pulse(f, a, 3, 7)));
  const cx = ph.x + 18 * Math.sin(f / 50) + 8;
  const cy = ph.y + 24 + 10 * Math.cos(f / 37);
  return (
    <Camera cam={cam}>
      <TestPlayer
        t={t}
        checkP={checkP}
        screen={
          <OffthreadVideo
            src={staticFile("computer.mp4")}
            startFrom={Math.round(2.4 * 60)}
            muted
            style={{ position: "absolute", left: vOff.x, top: vOff.y, width: 872 * vScale, height: 654 * vScale, display: "block" }}
          />
        }
      />
      {TAPS.map((a) => {
        const p = interpolate(f, [a, a + 22], [0, 1], clamp);
        if (p <= 0 || p >= 1) return null;
        return (
          <div
            key={a}
            style={{ position: "absolute", left: cx - 9, top: cy - 9, width: 18, height: 18, borderRadius: 9999, border: "1.2px solid rgba(255,255,255,0.9)", boxSizing: "border-box", opacity: (1 - p) * 0.9, transform: `scale(${0.5 + p * 0.9})` }}
          />
        );
      })}
      <Cursor x={cx} y={cy} press={tapPress} opacity={interpolate(f, [330, 360], [0, 1], clamp)} />
    </Camera>
  );
};

export const END_LEN = 240;
export const EndCard: React.FC = () => {
  const f = useCurrentFrame();
  const a = interpolate(f, [8, 50], [0, 1], { ...clamp, easing: outQuint });
  const b = interpolate(f, [34, 76], [0, 1], { ...clamp, easing: outQuint });
  return (
    <AbsoluteFill style={{ background: C.bg, alignItems: "center", justifyContent: "center" }}>
      <Img src={staticFile("lockup-black.png")} style={{ width: 560, opacity: a, transform: `translateY(${(1 - a) * 10}px) scale(${0.985 + 0.015 * a})` }} />
      <div style={{ ...text(34, 44, C.grey, 400, -0.4), marginTop: 22, opacity: b, transform: `translateY(${(1 - b) * 8}px)` }}>Now on macOS</div>
    </AbsoluteFill>
  );
};

const X1 = 24;
const X2 = 24;
const X3 = 30;
export const A_AT = 0;
export const B_AT = PROMPT_LEN - X1;
export const C_AT = B_AT + BUILD_LEN - X2;
export const E_AT = C_AT + TEST_LEN - X3;
export const MACRO_LEN = E_AT + END_LEN;

const Fade: React.FC<{ len: number; children: React.ReactNode }> = ({ len, children }) => {
  const f = useCurrentFrame();
  return <AbsoluteFill style={{ opacity: interpolate(f, [0, len], [0, 1], { ...clamp, easing: cubic }) }}>{children}</AbsoluteFill>;
};

export const Macro: React.FC = () => (
  <AbsoluteFill style={{ background: C.bg }}>
    <Sequence from={A_AT} durationInFrames={PROMPT_LEN}>
      <ScenePrompt />
    </Sequence>
    <Sequence from={B_AT} durationInFrames={BUILD_LEN}>
      <Fade len={X1}>
        <SceneBuild />
      </Fade>
    </Sequence>
    <Sequence from={C_AT} durationInFrames={TEST_LEN}>
      <Fade len={X2}>
        <SceneTest />
      </Fade>
    </Sequence>
    <Sequence from={E_AT} durationInFrames={END_LEN}>
      <Fade len={X3}>
        <EndCard />
      </Fade>
    </Sequence>
  </AbsoluteFill>
);

export const Screens: React.FC<{ which: "home" | "menu" | "session" | "player" }> = ({ which }) => (
  <Camera cam={FULL}>
    {which === "home" ? <Home typed="" caret env="ubuntu" menu={0} hover={null} press={0} /> : null}
    {which === "menu" ? <Home typed={PROMPT} caret env="ubuntu" menu={1} hover="macos" press={0} /> : null}
    {which === "session" ? <Session workSec={38} done phase={0} screen={<OffthreadVideo src={staticFile("computer.mp4")} startFrom={600} muted style={{ width: DESK.w, height: DESK.h, objectFit: "cover" }} />} /> : null}
    {which === "player" ? <TestPlayer t={33.4} checkP={1} screen={<OffthreadVideo src={staticFile("computer.mp4")} startFrom={600} muted style={{ position: "absolute", left: vOff.x, top: vOff.y, width: 872 * vScale, height: 654 * vScale }} />} /> : null}
  </Camera>
);
