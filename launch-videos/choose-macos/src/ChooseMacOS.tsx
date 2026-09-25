import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { BASE_SCALE, C, FK, HEIGHT, SCREEN, VH, VW, WIDTH } from "./theme";
import { camAt, CamKey, cursorAt, easeInOut, easeInOutSoft, easeOut, lerp, pressAt, prog, typedCount, typingSchedule } from "./anim";
import { CHIP, EnvChip, Home, TARGETS } from "./Home";
import { PROMPT_TEXT, Session, SessionScript } from "./Session";
import { FootageFrame, remap } from "./Footage";
import { TestPlayer } from "./TestPlayer";
import { EndCard } from "./EndCard";
import { Icon } from "./Icon";

export const DURATION = 1800;

const TYPE_START = 16;
const typing = typingSchedule(PROMPT_TEXT, TYPE_START);

const F = {
  chipClick: 244,
  menuOpen: 246,
  macClick: 336,
  menuClose: 350,
  sendClick: 424,
  morph: 432,
  morphEnd: 520,
  playerIn: 1150,
  endIn: 1530,
};

const CX = VW / 2;
const CY = VH / 2;

const CAMERA: CamKey[] = [
  { f: 0, x: CX, y: 330, z: 1.62 },
  { f: 170, x: CX, y: 338, z: 1.55, ease: easeInOutSoft },
  { f: 250, x: 430, y: 440, z: 2.2 },
  { f: 330, x: 405, y: 462, z: 2.45, ease: easeInOutSoft },
  { f: 356, x: 405, y: 462, z: 2.45 },
  { f: 420, x: CX, y: 356, z: 1.55 },
  { f: F.morph, x: CX, y: 356, z: 1.55 },
  { f: F.morphEnd, x: 788, y: 338, z: 1.45 },
  { f: 600, x: 788, y: 338, z: 1.45 },
  { f: 680, x: CX, y: CY, z: 1 },
  { f: 860, x: CX, y: CY, z: 1 },
  { f: 950, x: 905, y: 336, z: 1.8 },
  { f: 1130, x: 905, y: 336, z: 1.8 },
  { f: 1200, x: CX, y: CY, z: 1 },
  { f: 1215, x: CX, y: CY, z: 1 },
  { f: 1290, x: 840, y: 330, z: 1.45 },
  { f: 1400, x: 840, y: 330, z: 1.45 },
  { f: 1470, x: 402, y: 452, z: 1.5 },
];

const CURSOR = [
  { f: 172, x: 790, y: 610 },
  { f: 236, x: TARGETS.chip.x, y: TARGETS.chip.y, bend: 0.22 },
  { f: 262, x: TARGETS.chip.x, y: TARGETS.chip.y },
  { f: 300, x: TARGETS.macRow.x, y: TARGETS.macRow.y, bend: -0.25 },
  { f: 364, x: TARGETS.macRow.x, y: TARGETS.macRow.y },
  { f: 418, x: TARGETS.send.x, y: TARGETS.send.y, bend: 0.12 },
];

const SCRIPT: SessionScript = {
  bubble: 500,
  reply: 545,
  worked: 600,
  rows: [
    { at: 615, kind: "cmd", text: "xcodebuild -version; xcrun simctl list devices available | rg -i iphone", dur: "3s" },
    { at: 645, kind: "thought", text: "Thought for 6s" },
    { at: 668, kind: "cmd", text: "brew install xcodegen 2>&1 | tail -3; mkdir -p ~/repos/experiments/ios-otter-flap", dur: "11s" },
    { at: 700, kind: "thought", text: "Thought for 9s" },
    { at: 722, kind: "cmd", text: "xcodegen generate && xcodebuild -scheme OtterFlap -sdk iphonesimulator build", dur: "38s" },
    { at: 790, kind: "cmd", text: "xcrun simctl install booted OtterFlap.app && xcrun simctl launch booted com.devin.OtterFlap", dur: "2s" },
    { at: 850, kind: "cmd", text: 'query Simulator  →  @i17 button "Tap to start" {press}' },
    { at: 885, kind: "cmd", text: "act press @i17" },
  ],
  status: [
    { at: 560, text: "Preparing iOS build tools" },
    { at: 840, text: "Testing Otter Flap with computer use" },
  ],
};

/** Computer-pane footage timing: boot -> home screen -> launch -> gameplay. */
const SCREEN_FOOTAGE: [number, number][] = [
  [500, 18],
  [740, 170],
  [830, 300],
  [1150, 545],
];

const SCREEN_TAPS = [852, 878, 902, 926, 950, 974, 998, 1022, 1046, 1070, 1094, 1118];
const SCREEN_TAP_POS = { x: 927, y: 392 };

/** Player timeline: frames -> playhead seconds. */
const PLAYER_TIME: [number, number][] = [
  [1160, 0],
  [1185, 2],
  [1230, 6],
  [1275, 13],
  [1320, 21],
  [1365, 27],
  [1410, 33],
  [1530, 36],
];
/** Playhead seconds -> footage frame for the recording shown in the player. */
const PLAYER_FOOTAGE: [number, number][] = [
  [0, 262],
  [2, 290],
  [6, 330],
  [13, 430],
  [21, 515],
  [27, 552],
  [33, 612],
  [36, 660],
];
const PLAYER_TAPS = [1187, 1232, 1252, 1272, 1294, 1314, 1370, 1412];

const lastTap = (frame: number, taps: number[]) => {
  const t = [...taps].reverse().find((x) => frame >= x);
  if (t === undefined || frame - t > 20) return 0;
  return prog(frame, t, t + 20, easeOut);
};

const Cursor: React.FC<{ x: number; y: number; press: number; opacity: number }> = ({ x, y, press, opacity }) => (
  <div style={{ position: "absolute", left: x - 6, top: y - 4, opacity, transform: `scale(${1 - press * 0.12})`, transformOrigin: "6px 4px" }}>
    <Icon name="pointer" size={0} w={28} h={32} />
  </div>
);

const Morph: React.FC<{ frame: number }> = ({ frame }) => {
  const p = prog(frame, F.morph, F.morphEnd, easeInOut);
  const q = prog(frame, F.morph, F.morph + 30, easeInOutSoft);
  const fadeOut = 1 - prog(frame, F.morphEnd, F.morphEnd + 36, easeInOutSoft);
  const r0 = { x: CHIP.x - 5, y: CHIP.y - 4, w: 80, h: 24 };
  const x = lerp(r0.x, SCREEN.x, p);
  const y = lerp(r0.y, SCREEN.y, p);
  const w = lerp(r0.w, SCREEN.w, p);
  const h = lerp(r0.h, SCREEN.h, p);
  // Apple glyph: from the chip icon to the Simulator boot logo in the recording.
  const a0 = { x: CHIP.x + 7, y: CHIP.y + 8, s: 14 };
  const a1 = { x: SCREEN.x + 438 * FK, y: SCREEN.y + 305 * FK, s: 42 };
  const ax = lerp(a0.x, a1.x, p);
  const ay = lerp(a0.y, a1.y, p);
  const as = lerp(a0.s, a1.s, p);
  return (
    <div style={{ position: "absolute", inset: 0, opacity: fadeOut }}>
      <div
        style={{
          position: "absolute",
          left: x,
          top: y,
          width: w,
          height: h,
          borderRadius: lerp(6, 0, p),
          background: `rgba(0,0,0,${lerp(0.06, 1, q)})`,
        }}
      />
      <div style={{ position: "absolute", left: CHIP.x, top: CHIP.y, opacity: 1 - prog(frame, F.morph, F.morph + 16) }}>
        <EnvChip env="macos" />
      </div>
      <Icon
        name="apple"
        size={as}
        style={{ position: "absolute", left: ax - as / 2, top: ay - as / 2 - as * 0.03, filter: "brightness(0) invert(1)", opacity: q }}
      />
    </div>
  );
};

export const ChooseMacOS: React.FC = () => {
  const frame = useCurrentFrame();
  const cam = camAt(frame, CAMERA);
  const camTransform = `translate(${WIDTH / 2}px, ${HEIGHT / 2}px) scale(${BASE_SCALE * cam.z}) translate(${-cam.x}px, ${-cam.y}px)`;

  const typed = typedCount(frame, typing.times);
  const caretOn = frame < TYPE_START || (frame >= TYPE_START && frame <= typing.end + 4) || Math.floor((frame - typing.end) / 30) % 2 === 1;
  const env = frame >= F.macClick + 2 ? "macos" : "ubuntu";
  const menu = prog(frame, F.menuOpen, F.menuOpen + 16, easeOut) * (1 - prog(frame, F.menuClose, F.menuClose + 16, easeInOutSoft));
  const homeOpacity = 1 - prog(frame, F.morph + 8, F.morph + 58, easeInOutSoft);
  const cur = cursorAt(frame, CURSOR);
  const curOpacity = prog(frame, 172, 190) * (1 - prog(frame, F.sendClick + 6, F.sendClick + 22));
  const press = Math.max(pressAt(frame, F.chipClick), pressAt(frame, F.macClick), pressAt(frame, F.sendClick));

  const footageN = remap(frame, SCREEN_FOOTAGE);
  const screenTap = lastTap(frame, SCREEN_TAPS);
  const screenCursorOpacity = prog(frame, 815, 835) * (1 - prog(frame, 1135, 1150));
  const screenCursor = cursorAt(frame, [
    { f: 815, x: 1030, y: 480 },
    { f: 848, x: SCREEN_TAP_POS.x, y: SCREEN_TAP_POS.y, bend: 0.2 },
  ]);

  const playerIn = prog(frame, F.playerIn, F.playerIn + 40, easeOut);
  const pTime = remap(frame, PLAYER_TIME);
  const endIn = prog(frame, F.endIn, F.endIn + 40, easeInOutSoft);

  return (
    <AbsoluteFill style={{ background: C.bg, overflow: "hidden" }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: VW, height: VH, transformOrigin: "0 0", transform: camTransform }}>
        {frame >= 470 && frame < F.playerIn + 60 ? (
          <Session
            frame={frame}
            script={SCRIPT}
            chrome={prog(frame, 480, 540, easeInOutSoft)}
            screen={
              frame >= F.morphEnd - 2 ? (
                <>
                  <FootageFrame n={footageN} scale={FK} />
                  <div
                    style={{
                      position: "absolute",
                      left: SCREEN_TAP_POS.x - SCREEN.x - 14,
                      top: SCREEN_TAP_POS.y - SCREEN.y - 14,
                      width: 28,
                      height: 28,
                      borderRadius: 9999,
                      border: "2px solid rgba(255,255,255,0.9)",
                      background: "rgba(49,124,255,0.35)",
                      opacity: screenTap > 0 ? 1 - screenTap : 0,
                      transform: `scale(${0.5 + screenTap * 0.9})`,
                    }}
                  />
                  <div style={{ position: "absolute", left: -SCREEN.x, top: -SCREEN.y }}>
                    <Cursor x={screenCursor.x} y={screenCursor.y} press={screenTap > 0 && screenTap < 0.4 ? 1 - screenTap * 2.5 : 0} opacity={screenCursorOpacity} />
                  </div>
                </>
              ) : null
            }
          />
        ) : null}
        {frame < F.morph + 60 ? (
          <div style={{ position: "absolute", inset: 0, opacity: homeOpacity }}>
            <Home
              text={PROMPT_TEXT.slice(0, typed)}
              caret={caretOn && frame < F.sendClick}
              sendActive={prog(frame, TYPE_START, TYPE_START + 10)}
              sendPress={pressAt(frame, F.sendClick)}
              menu={menu}
              hoverRow={prog(frame, 292, 302)}
              env={env}
              chipPress={pressAt(frame, F.chipClick)}
              chipOpacity={frame >= F.morph ? 0 : 1}
            />
          </div>
        ) : null}
        {frame >= F.morph && frame < F.morphEnd + 40 ? <Morph frame={frame} /> : null}
        {frame < F.sendClick + 30 ? <Cursor x={cur.x} y={cur.y} press={press} opacity={curOpacity} /> : null}
        {frame >= F.playerIn ? (
          <div style={{ position: "absolute", inset: 0, opacity: playerIn, transform: `scale(${0.985 + 0.015 * playerIn})`, transformOrigin: "50% 50%" }}>
            <TestPlayer
              st={{
                time: pTime,
                footageN: remap(pTime, PLAYER_FOOTAGE),
                tap: lastTap(frame, PLAYER_TAPS),
                tapPos: frame >= 1180 && frame < 1425 ? { x: 0.5, y: 0.62 } : null,
                listIn: prog(frame, F.playerIn + 10, F.playerIn + 80, (t) => t),
              }}
            />
          </div>
        ) : null}
      </div>
      {frame >= F.endIn ? (
        <div style={{ position: "absolute", inset: 0, opacity: endIn }}>
          <EndCard frame={frame} start={F.endIn + 20} />
        </div>
      ) : null}
    </AbsoluteFill>
  );
};
