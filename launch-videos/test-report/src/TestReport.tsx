import { AbsoluteFill, Sequence, useCurrentFrame } from "remotion";
import { Camera, CamKey, STAGE_H, STAGE_W, camAt } from "./Camera";
import { Cursor, cursorAt, pressScale } from "./Cursor";
import { EndCard } from "./EndCard";
import { HOME_POS, HOME_T, Home } from "./Home";
import { PLAYER_SCREEN, Player } from "./Player";
import { SIM_SCREEN, Session } from "./Session";
import { END, HOME, PLAYER, SESSION } from "./timeline";
import { C, ramp } from "./theme";

const clampCam = (c: { x: number; y: number; s: number }) => {
  const hw = STAGE_W / (2 * c.s);
  const hh = STAGE_H / (2 * c.s);
  return {
    s: c.s,
    x: Math.min(Math.max(c.x, hw), STAGE_W - hw),
    y: Math.min(Math.max(c.y, hh), STAGE_H - hh),
  };
};

const HOME_CAM: CamKey[] = [
  { f: 0, x: 600, y: 372, s: 1.36 },
  { f: 70, x: 570, y: 396, s: 1.32 },
  { f: 140, x: 610, y: 356, s: 1.3 },
  { f: 250, x: 640, y: 350, s: 1.26 },
  { f: 300, x: 614.4, y: 345.6, s: 1.12 },
];

const HOME_CURSOR = [
  { f: 0, x: 760, y: 560 },
  { f: 50, ...HOME_POS.env },
  { f: 70, ...HOME_POS.env },
  { f: 98, ...HOME_POS.macItem },
  { f: 108, ...HOME_POS.macItem },
  { f: 132, ...HOME_POS.text },
  { f: 228, ...HOME_POS.text },
  { f: 256, ...HOME_POS.send },
  { f: 300, x: HOME_POS.send.x + 10, y: HOME_POS.send.y + 30 },
];

const simC = { x: SIM_SCREEN.x + SIM_SCREEN.w / 2, y: SIM_SCREEN.y + SIM_SCREEN.h / 2 };
const plC = { x: PLAYER_SCREEN.x + PLAYER_SCREEN.w / 2, y: PLAYER_SCREEN.y + PLAYER_SCREEN.h / 2 };
const P0 = 1.3;
const Z = (P0 * PLAYER_SCREEN.w) / SIM_SCREEN.w;
const sessionEndX = Math.min(simC.x, STAGE_W - STAGE_W / (2 * Z));
const p0x = plC.x + ((sessionEndX - simC.x) * Z) / P0;

const SESSION_CAM: CamKey[] = [
  { f: 0, x: 614.4, y: 345.6, s: 1.08 },
  { f: 150, x: 614.4, y: 345.6, s: 1.0 },
  { f: 176, x: 620, y: 345.6, s: 1.0 },
  { f: 300, x: simC.x, y: simC.y, s: Z },
  { f: 336, x: simC.x, y: simC.y, s: Z },
];

const PLAYER_CAM: CamKey[] = [
  { f: 0, x: p0x, y: plC.y, s: P0 },
  { f: 16, x: p0x, y: plC.y, s: P0 },
  { f: 100, x: 614.4, y: 345.6, s: 1.0 },
  { f: 230, x: 614.4, y: 345.6, s: 1.02 },
  { f: 310, x: 845, y: 330, s: 1.6 },
  { f: 430, x: 850, y: 380, s: 1.64 },
  { f: 505, x: 433, y: plC.y, s: 1.42 },
  { f: 700, x: 433, y: plC.y + 6, s: 1.46 },
  { f: 775, x: 560, y: 504, s: 1.85 },
  { f: 890, x: 600, y: 507, s: 1.88 },
  { f: 965, x: 845, y: 460, s: 1.6 },
  { f: 1085, x: 851, y: 470, s: 1.63 },
  { f: 1165, x: 614.4, y: 345.6, s: 1.0 },
  { f: 1230, x: 614.4, y: 345.6, s: 1.01 },
];

export const TestReport: React.FC = () => {
  const frame = useCurrentFrame();
  const hf = frame - HOME.from;
  const sf = frame - SESSION.from;
  const pf = frame - PLAYER.from;
  const homeOut = ramp(hf, 270, 300);
  const sessionIn = ramp(sf, 0, 28);
  const playerIn = ramp(pf, 0, 22);
  const cur = cursorAt(hf, HOME_CURSOR);
  const press = pressScale(hf, [HOME_T.envClick, HOME_T.menuItemClick, HOME_T.sendClick]);

  return (
    <AbsoluteFill style={{ background: C.page }}>
      <Sequence from={HOME.from} durationInFrames={HOME.dur}>
        <Camera cam={clampCam(camAt(hf, HOME_CAM))} style={{ opacity: 1 - homeOut }}>
          <Home frame={hf} />
          <Cursor x={cur.x} y={cur.y} scale={press} size={16} opacity={1 - ramp(hf, 262, 292)} />
        </Camera>
      </Sequence>
      <Sequence from={SESSION.from} durationInFrames={SESSION.dur}>
        <Camera cam={clampCam(camAt(sf, SESSION_CAM))} style={{ opacity: sessionIn }}>
          <Session frame={sf} />
        </Camera>
      </Sequence>
      <Sequence from={PLAYER.from} durationInFrames={PLAYER.dur}>
        <Camera cam={camAt(pf, PLAYER_CAM)} style={{ opacity: playerIn }}>
          <Player frame={pf} />
        </Camera>
      </Sequence>
      <Sequence from={END.from} durationInFrames={END.dur}>
        <EndCard frame={frame - END.from} />
      </Sequence>
    </AbsoluteFill>
  );
};
