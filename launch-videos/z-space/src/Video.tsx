import React from "react";
import { AbsoluteFill, Img, Sequence, interpolate, staticFile, useCurrentFrame } from "remotion";
import { C, INTER, SCREEN_H, SCREEN_W, fontCss } from "./theme";
import { Layer, Rect, Stage } from "./Layer";
import { Pose, REST, clamp01, mix, outQuint, pose, quint, ramp, settle, typed, typedEnd } from "./motion";
import { Arrow, Hand, cursorAt } from "./Cursor";
import { HOME, HomeBase, HomeCard, HomeControls, HomeLogo, HomeToggle, EnvMenu, EnvPicker } from "./ui/Home";
import { SESSION, SessionHeader, RightTabs, Chat, Composer, Desktop, LiveControls, REPLY, LEFT_W } from "./ui/Session";
import { TP, TPControls, TPHeader, TPResults } from "./ui/TestPlayer";
import { Btn } from "./ui/common";

const PROMPT = "Build Flappy Bird with an Otter. Then build and test it on iOS.";
const SCALE = 1.5;

// ---- timeline ----
const T_CLICK_ENV = 150;
const T_CLICK_MAC = 204;
const T_CLICK_CARD = 250;
const T_TYPE = 262;
const T_TYPED = Math.ceil(typedEnd(PROMPT, T_TYPE));
const T_SEND = T_TYPED + 34;
const A_EXIT = T_SEND + 6;
const SB = A_EXIT + 26;
const V0 = SB - 150;
const SC = SB + 560;
const SD = SC + 430;
export const DURATION = SD + 300;

const CENTER = { x: SCREEN_W / 2, y: SCREEN_H / 2 };

type CamKey = { f: number; d: number; p: Partial<Pose> };

const camKeys: CamKey[] = [
  { f: 0, d: 170, p: { rx: 0, ry: 0, rz: 0, s: 1 } },
  { f: T_CLICK_CARD - 10, d: 120, p: { s: 1.14, y: -40 } },
  { f: A_EXIT - 4, d: 70, p: { s: 0.94, ry: 9, rx: 7, y: 0 } },
  { f: SB + 30, d: 150, p: { s: 1, ry: 0, rx: 0 } },
  { f: SB + 280, d: 120, p: { s: 1.62, x: -(SESSION.desktop.x + SESSION.desktop.w / 2 - CENTER.x) * SCALE * 1.62, y: -(SESSION.desktop.y + SESSION.desktop.h / 2 - CENTER.y) * SCALE * 1.62, ry: -7, rx: 2 } },
  { f: SB + 420, d: 140, p: { ry: 5, rx: -1.5 } },
  { f: SC - 10, d: 90, p: { s: 0.9, x: 0, y: 0, ry: -10, rx: 6 } },
  { f: SC + 70, d: 160, p: { s: 1, ry: 0, rx: 0 } },
  { f: SC + 220, d: 190, p: { s: 1.3, x: -300, y: 60, ry: -5, rx: 2 } },
  { f: SD - 10, d: 110, p: { s: 1, x: 0, y: 0, ry: 0, rx: 0 } },
];

const INTRO: Pose = pose({ rx: 18, ry: -26, rz: -3, s: 0.8, y: 30 });

const cameraAt = (f: number): Pose => {
  let cur: Pose = { ...INTRO };
  let prevTarget: Pose = { ...INTRO };
  for (const k of camKeys) {
    const target: Pose = { ...prevTarget, ...k.p };
    const t = ramp(f, k.f, k.f + k.d, quint);
    cur = {
      x: cur.x + (target.x - prevTarget.x) * t,
      y: cur.y + (target.y - prevTarget.y) * t,
      z: cur.z + (target.z - prevTarget.z) * t,
      rx: cur.rx + (target.rx - prevTarget.rx) * t,
      ry: cur.ry + (target.ry - prevTarget.ry) * t,
      rz: cur.rz + (target.rz - prevTarget.rz) * t,
      s: cur.s + (target.s - prevTarget.s) * t,
      o: 1,
    };
    prevTarget = target;
  }
  const drift = Math.sin(f / 170) * 0.6;
  return { ...cur, ry: cur.ry + drift, rx: cur.rx + Math.cos(f / 210) * 0.35 };
};

// ---- layer helpers ----
const enterPose = (f: number, start: number, from: Partial<Pose>, cfg?: { damping?: number; stiffness?: number }) => {
  const p = settle(f, start, cfg ?? { damping: 19, stiffness: 62 });
  return { pose: mix(pose(from), REST, p), lift: clamp01((1 - p) * 2.4) };
};

const exitPose = (f: number, start: number, to: Partial<Pose>, dur = 56) => {
  const t = ramp(f, start, start + dur, (x) => quint(x));
  return { t, pose: mix(REST, pose(to), t), lift: clamp01(t * 3) };
};

const add = (a: Pose, b: Pose): Pose => ({ x: a.x + b.x, y: a.y + b.y, z: a.z + b.z, rx: a.rx + b.rx, ry: a.ry + b.ry, rz: a.rz + b.rz, s: a.s * b.s, o: a.o * b.o });

const collapse = (f: number, i: number, rect: Rect, order: number) => {
  const t = ramp(f, SD + i * 4, SD + 70 + i * 4, (x) => quint(x));
  const cx = rect.x + rect.w / 2;
  const cy = rect.y + rect.h / 2;
  const p = pose({ x: (CENTER.x - cx) * t, y: (CENTER.y - cy) * t, z: order === 0 ? -150 * t : order * 24 * t, s: 1 - 0.9 * t, rz: (i % 2 ? 6 : -6) * t, o: 1 - ramp(f, SD + 40 + i * 4, SD + 76 + i * 4) });
  return { t, pose: p, lift: clamp01(t * 3) };
};

const Screen: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div style={{ position: "absolute", left: -SCREEN_W / 2, top: -SCREEN_H / 2, width: SCREEN_W, height: SCREEN_H, transformStyle: "preserve-3d" }}>{children}</div>
);

const lerpRect = (a: Rect, b: Rect, t: number): Rect => ({ x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t, w: a.w + (b.w - a.w) * t, h: a.h + (b.h - a.h) * t });

// ---- cursor ----
const CURSOR = [
  { f: 96, x: 700, y: 560 },
  { f: T_CLICK_ENV - 6, x: 300, y: 431 },
  { f: T_CLICK_MAC - 22, x: 300, y: 431 },
  { f: T_CLICK_MAC - 4, x: 322, y: 516 },
  { f: T_CLICK_CARD - 30, x: 322, y: 516 },
  { f: T_CLICK_CARD - 4, x: 610, y: 330 },
  { f: T_TYPED + 4, x: 610, y: 330 },
  { f: T_SEND - 4, x: 897, y: 380 },
];

const pressAt = (f: number, t: number) => {
  const d = f - t;
  if (d < -3 || d > 8) return 0;
  return d < 0 ? (d + 3) / 3 : 1 - d / 8;
};

export const ZSpace: React.FC = () => {
  const f = useCurrentFrame();
  const cam = cameraAt(f);

  // Home state
  const menuOpen = f >= T_CLICK_ENV + 2 && f < T_CLICK_MAC + 22;
  const mac = f >= T_CLICK_MAC + 2;
  const focused = f >= T_CLICK_CARD + 2;
  const text = typed(PROMPT, f, T_TYPE);
  const sendPressed = pressAt(f, T_SEND);

  const homeVisible = f < A_EXIT + 80;
  const sessVisible = f >= SB - 10 && f < SC + 120;
  const tpVisible = f >= SC + 10;

  const homeLayers: { rect: Rect; from: Partial<Pose>; to: Partial<Pose>; node: React.ReactNode; radius?: number; bare?: boolean }[] = [
    { rect: HOME.logo, from: { z: 340, y: -60, x: -40, o: 0, rx: 8 }, to: { z: 620, y: -120, x: -120, o: 0 }, node: <HomeLogo />, radius: 10 },
    { rect: HOME.toggle, from: { z: 420, y: -40, x: 90, o: 0, ry: -10 }, to: { z: 700, x: 180, y: -80, o: 0 }, node: <HomeToggle />, radius: 9999 },
    { rect: HOME.card, from: { z: 220, y: 20, o: 0, rx: -6 }, to: { z: 520, y: 30, o: 0 }, node: <HomeCard text={text} focused={focused} frame={f} />, radius: 20, bare: true },
    { rect: HOME.controls, from: { z: 480, y: 40, o: 0 }, to: { z: 820, y: 90, o: 0 }, node: <HomeControls active={text.length > 0} pressed={sendPressed} />, radius: 10 },
    { rect: HOME.env, from: { z: 380, y: 70, x: -30, o: 0 }, to: { z: 640, y: 150, x: -90, o: 0 }, node: <EnvPicker mac={mac} />, radius: 8 },
  ];

  const menuIn = settle(f, T_CLICK_ENV + 2, { damping: 22, stiffness: 180 });
  const menuOut = ramp(f, T_CLICK_MAC + 8, T_CLICK_MAC + 22, outQuint);
  const menuPose = pose({ z: 60 * (1 - menuIn) + 30 * menuOut, y: -6 * (1 - menuIn) - 4 * menuOut, s: 0.97 + 0.03 * menuIn - 0.02 * menuOut, o: clamp01(menuIn * 1.6) * (1 - menuOut) });
  const hoverMac = ramp(f, T_CLICK_MAC - 10, T_CLICK_MAC - 4, outQuint);

  // Session state
  const replyChars = Math.max(0, Math.floor((f - (SB + 110)) * 2.3));
  const rows = Math.max(0, (f - (SB + 190)) / 20);
  const collapsed = ramp(f, SB + 330, SB + 356);
  const status = f < SB + 110 ? "setup" : f > SB + 350 ? "build" : "none";
  const title = f < SB + 100 ? "New session" : "Create Otter Flappy Bird iOS App";
  const titleFade = interpolate(f, [SB + 94, SB + 100, SB + 106], [1, 0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  const sessLayers: { rect: Rect; from: Partial<Pose>; out: Partial<Pose>; node: React.ReactNode; radius?: number; bare?: boolean }[] = [
    { rect: SESSION.header, from: { z: 380, y: -70, o: 0 }, out: { z: -260, y: -160, x: -200, o: 0 }, node: <div style={{ opacity: titleFade, position: "absolute", inset: 0 }}><SessionHeader title={title} /></div>, radius: 10 },
    { rect: SESSION.tabs, from: { z: 440, y: -60, x: 60, o: 0 }, out: { z: -200, y: -200, x: 120, o: 0 }, node: <RightTabs computer={1} />, radius: 10 },
    { rect: SESSION.chat, from: { z: 260, x: -80, o: 0, ry: 6 }, out: { z: -380, x: -420, o: 0, ry: 10 }, node: <Chat frame={f} replyChars={Math.min(replyChars, REPLY.length)} rows={Math.min(rows, 6)} collapsed={collapsed} status={status} />, radius: 14 },
    { rect: SESSION.composer, from: { z: 320, y: 90, o: 0 }, out: { z: -260, y: 240, x: -140, o: 0 }, node: <Composer running={f > SB + 20} />, radius: 20, bare: true },
    { rect: SESSION.live, from: { z: 360, y: 80, x: 40, o: 0 }, out: { z: -220, y: 220, x: 160, o: 0 }, node: <LiveControls progress={0.996} />, radius: 10 },
  ];

  // Test player
  const tt = 26.4 + Math.max(0, f - (SC + 100)) / 60;
  const scrollT = ramp(f, SC + 100 + (33 - 26.4) * 60 - 20, SC + 100 + (33 - 26.4) * 60 + 25);
  const scroll = 150 + 90 * scrollT;

  const tpLayers: { rect: Rect; from: Partial<Pose>; node: React.ReactNode; radius?: number }[] = [
    { rect: TP.header, from: { z: 360, y: -80, o: 0 }, node: <TPHeader />, radius: 10 },
    { rect: TP.results, from: { z: 300, x: 260, o: 0, ry: -12 }, node: <TPResults time={tt} scroll={scroll} passedAll={1} />, radius: 10 },
    { rect: TP.controls, from: { z: 420, y: 110, o: 0 }, node: <TPControls time={tt} />, radius: 10 },
  ];

  // Base window
  const baseIn = enterPose(f, 0, { z: -260, o: 0 }, { damping: 24, stiffness: 40 });
  const baseCol = collapse(f, 6, { x: 0, y: 0, w: SCREEN_W, h: SCREEN_H }, 0);
  const basePose = f >= SD ? baseCol.pose : baseIn.pose;
  const sidebarIconO = 1 - ramp(f, SC, SC + 40);
  const dividerO = ramp(f, SB - 10, SB + 40) * (1 - ramp(f, SC, SC + 50));

  // Shared desktop layer
  const deskMorph = ramp(f, SC + 6, SC + 96);
  const deskRect = lerpRect(SESSION.desktop, TP.video, deskMorph);
  const deskEnter = enterPose(f, SB + 28, { z: 520, x: 120, o: 0, ry: -8 });
  const deskLiftZ = 60 * ramp(f, SB + 280, SB + 400) * (1 - ramp(f, SC, SC + 80));
  let deskPose = add(deskEnter.pose, pose({ z: deskLiftZ + 90 * Math.sin(Math.PI * deskMorph) }));
  let deskLift = Math.max(deskEnter.lift, ramp(f, SB + 280, SB + 400) * (1 - deskMorph) * 0.9, Math.sin(Math.PI * deskMorph));
  if (f >= SD) {
    const c = collapse(f, 1, deskRect, 2);
    deskPose = c.pose;
    deskLift = c.lift;
  }

  // Taps (computer use) inside the simulator
  const taps = [9.83, 10.5].map((s) => V0 + s * 60);

  // End card
  const markIn = settle(f, SD + 58, { damping: 16, stiffness: 90 });
  const slide = ramp(f, SD + 118, SD + 178);
  const wordReveal = ramp(f, SD + 128, SD + 190);
  const lineIn = ramp(f, SD + 170, SD + 230, outQuint);
  const LH = 150;
  const LW = (LH * 2984) / 1024;
  const lockLeft = 960 - LW / 2;
  const markCenterLeft = 960 - LH / 2;
  const markLeft = markCenterLeft + (lockLeft - markCenterLeft) * slide;

  const cursor = cursorAt(CURSOR, f);
  const cursorO = ramp(f, 96, 120) * (1 - ramp(f, T_CLICK_CARD + 18, T_CLICK_CARD + 26)) + ramp(f, T_TYPED + 2, T_TYPED + 10) * (1 - ramp(f, T_SEND + 4, T_SEND + 18));
  const hand = (f > T_CLICK_ENV - 16 && f < T_CLICK_ENV + 10) || (f > T_CLICK_MAC - 12 && f < T_CLICK_MAC + 10) || f > T_SEND - 12;
  const press = Math.max(pressAt(f, T_CLICK_ENV), pressAt(f, T_CLICK_MAC), pressAt(f, T_CLICK_CARD), pressAt(f, T_SEND));

  return (
    <AbsoluteFill style={{ background: C.stage, fontFamily: INTER }}>
      <style>{fontCss}</style>
      <Stage camera={cam} scale={SCALE}>
        <Screen>
          {/* base window */}
          <Layer rect={{ x: 0, y: 0, w: SCREEN_W, h: SCREEN_H }} pose={basePose} card={false} radius={14} style={{ overflow: "hidden", boxShadow: "0 0 0 0.8px rgba(0,0,0,0.06), 0 30px 80px rgba(0,0,0,0.05), 0 8px 24px rgba(0,0,0,0.03)" }}>
            <HomeBase />
            <div style={{ position: "absolute", left: 11.3, top: 7.5, opacity: sidebarIconO }}>
              <Btn icon="sidebar" radius={6} />
            </div>
            <div style={{ position: "absolute", left: LEFT_W, top: 0, bottom: 0, width: 1, background: "rgba(0,0,0,0.075)", opacity: dividerO }} />
          </Layer>

          {homeVisible
            ? homeLayers.map((l, i) => {
                const e = enterPose(f, 10 + i * 7, l.from);
                const x = exitPose(f, A_EXIT + i * 4, l.to, 58);
                const p = x.t > 0 ? add(REST, x.pose) : e.pose;
                return (
                  <Layer key={i} rect={l.rect} pose={p} lift={l.bare ? 0 : Math.max(e.lift, x.lift)} radius={l.radius} card={!l.bare} style={l.bare ? { boxShadow: `0 ${20 * Math.max(e.lift, x.lift)}px ${60 * Math.max(e.lift, x.lift)}px rgba(0,0,0,${0.08 * Math.max(e.lift, x.lift)})`, borderRadius: l.radius } : undefined}>
                    {l.node}
                  </Layer>
                );
              })
            : null}

          {homeVisible && menuOpen ? (
            <Layer rect={HOME.menu} pose={menuPose} card={false} radius={12}>
              <EnvMenu hoverMac={hoverMac} mac={mac} />
            </Layer>
          ) : null}

          {sessVisible
            ? sessLayers.map((l, i) => {
                const e = enterPose(f, SB + i * 6, l.from);
                const x = exitPose(f, SC + i * 3, l.out, 64);
                const p = x.t > 0 ? x.pose : e.pose;
                const lift = Math.max(e.lift, x.lift);
                return (
                  <Layer key={i} rect={l.rect} pose={p} lift={l.bare ? 0 : lift} radius={l.radius} card={!l.bare} style={l.bare ? { boxShadow: `0 ${20 * lift}px ${60 * lift}px rgba(0,0,0,${0.08 * lift})`, borderRadius: l.radius } : undefined}>
                    {l.node}
                  </Layer>
                );
              })
            : null}

          {f >= SB - 10 ? (
            <Layer rect={deskRect} pose={deskPose} lift={deskLift} radius={2 + 4 * deskLift} card style={{ overflow: "hidden" }}>
              <Sequence from={V0} layout="none">
                <Desktop startFrom={0} />
              </Sequence>
              {taps.map((t, i) => {
                const d = f - t;
                if (d < 0 || d > 30) return null;
                const k = d / 30;
                return (
                  <div
                    key={i}
                    style={{
                      position: "absolute",
                      left: `${(430 / 872) * 100}%`,
                      top: `${(392 / 654) * 100}%`,
                      width: 26,
                      height: 26,
                      marginLeft: -13,
                      marginTop: -13,
                      borderRadius: 9999,
                      border: "1.5px solid rgba(255,255,255,0.9)",
                      background: "rgba(255,255,255,0.18)",
                      transform: `scale(${0.5 + k * 0.9})`,
                      opacity: 1 - k,
                    }}
                  />
                );
              })}
            </Layer>
          ) : null}

          {tpVisible
            ? tpLayers.map((l, i) => {
                const e = enterPose(f, SC + 34 + i * 8, l.from);
                const c = f >= SD ? collapse(f, i + 2, l.rect, 3 + i) : null;
                return (
                  <Layer key={i} rect={l.rect} pose={c ? c.pose : e.pose} lift={c ? c.lift : e.lift} radius={l.radius} style={{ overflow: "hidden" }}>
                    {l.node}
                  </Layer>
                );
              })
            : null}

          {cursorO > 0.001 && f < A_EXIT ? (
            <div style={{ position: "absolute", left: cursor.x, top: cursor.y, transform: `translate3d(0,0,30px) scale(${(1 - 0.1 * press) / 1.4})`, transformOrigin: "0 0", opacity: cursorO }}>
              <div style={{ position: "absolute", left: hand ? -8 : -2, top: hand ? -2 : -2 }}>{hand ? <Hand /> : <Arrow />}</div>
            </div>
          ) : null}
        </Screen>
      </Stage>

      {f >= SD + 40 ? (
        <AbsoluteFill>
          <div style={{ position: "absolute", left: lockLeft, top: 540 - LH / 2 - 30, width: LW, height: LH, clipPath: `inset(0 ${(1 - wordReveal) * 100}% 0 ${((LH * 0.82) / LW) * 100}%)`, opacity: wordReveal, transform: `translateX(${(1 - wordReveal) * -24}px)` }}>
            <Img src={staticFile("media/lockup-black.png")} style={{ width: LW, height: LH, display: "block" }} />
          </div>
          <div style={{ position: "absolute", left: markLeft, top: 540 - LH / 2 - 30, width: LH, height: LH, transform: `scale(${0.4 + 0.6 * markIn})`, opacity: clamp01(markIn * 1.5) }}>
            <Img src={staticFile("media/mark-black.png")} style={{ width: LH, height: LH, display: "block" }} />
          </div>
          <div style={{ position: "absolute", left: 0, right: 0, top: 540 + LH / 2 + 4, textAlign: "center", fontFamily: INTER, fontSize: 30, fontWeight: 500, letterSpacing: -0.4, color: "rgba(25,25,25,0.62)", opacity: lineIn, transform: `translateY(${(1 - lineIn) * 10}px)` }}>
            Devin, now on macOS
          </div>
        </AbsoluteFill>
      ) : null}
    </AbsoluteFill>
  );
};
