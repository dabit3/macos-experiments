import { hash } from "./anim";

export const PROMPT = "Build Flappy Bird with an Otter. Then build and test it on iOS.";

export const T = {
  typeStart: 0.95,
  envClick: 4.85,
  macClick: 5.6,
  dropClose: 5.72,
  sendClick: 6.5,
  toSession: 6.62,
  sessionDur: 1.15,
  repoChip: 7.85,
  reply: 8.05,
  worked: 8.75,
  rows: 8.95,
  status: 9.85,
  split: 10.55,
  splitDur: 1.05,
  boot: 10.75,
  titleScreen: 12.15,
  cursorIn: 12.9,
  gameStart: 13.55,
  toPlayer: 19.15,
  playerDur: 1.25,
  results: 20.55,
  resultStep: 0.72,
  outro: 26.1,
  endCard: 27.15,
};

export const charTimes: number[] = (() => {
  const out: number[] = [];
  let t = T.typeStart;
  for (let i = 0; i < PROMPT.length; i++) {
    out.push(t);
    const ch = PROMPT[i];
    let d = 0.036 + hash(i + 3) * 0.03;
    if (ch === " ") d += hash(i + 91) * 0.035;
    if (ch === "." || ch === ",") d += 0.19;
    if (i > 0 && PROMPT[i - 1] === " " && hash(i * 7) > 0.8) d += 0.05;
    t += d;
  }
  return out;
})();

export const typeEnd = charTimes[charTimes.length - 1];

export const typedCount = (t: number) => {
  let n = 0;
  while (n < charTimes.length && charTimes[n] <= t) n++;
  return n;
};

// Otter Flap simulation, in game units (390 x 844 portrait).
export const GAME = {
  w: 390,
  h: 844,
  ground: 760,
  otterX: 128,
  gravity: 1900,
  flapV: -560,
  speed: 150,
  firstPipe: 1.55,
  pipeEvery: 1.5,
  gap: 205,
  pipeW: 70,
};

const DT = 1 / 240;
const SIM_S = 14;

export const pipes = Array.from({ length: 10 }, (_, k) => ({
  arrive: GAME.firstPipe + k * GAME.pipeEvery,
  gapC: k === 0 ? 430 : 330 + hash(k + 11) * 180,
}));

const targetAt = (t: number) => {
  const next = pipes.find((p) => p.arrive + 0.35 > t) ?? pipes[pipes.length - 1];
  const prev = [...pipes].reverse().find((p) => p.arrive + 0.35 <= t);
  const from = prev ? prev.gapC : 420;
  const lead = Math.min(1, Math.max(0, 1 - (next.arrive - 0.5 - t) / 0.8));
  return from + (next.gapC - from) * lead;
};

type Sim = { y: number[]; v: number[]; taps: number[] };

export const sim: Sim = (() => {
  const y: number[] = [];
  const v: number[] = [];
  const taps: number[] = [0];
  let cy = 420;
  let cv = GAME.flapV;
  let last = 0;
  for (let i = 0; i <= SIM_S / DT; i++) {
    const t = i * DT;
    if (t - last > 0.26 && cv > 0 && cy > targetAt(t) + 28) {
      cv = GAME.flapV;
      last = t;
      taps.push(t);
    }
    cv += GAME.gravity * DT;
    cy += cv * DT;
    y.push(cy);
    v.push(cv);
  }
  return { y, v, taps };
})();

export const otterAt = (g: number) => {
  const i = Math.max(0, Math.min(sim.y.length - 1, Math.round(g / DT)));
  return { y: sim.y[i], v: sim.v[i] };
};

export const scoreAt = (g: number) =>
  pipes.filter((p) => g > p.arrive + GAME.pipeW / 2 / GAME.speed).length;

export const TESTS = [
  {
    time: "0:00",
    title: "iPhone 17, iOS 26.5; Xcode 26.6. Fresh install, sound on.",
    setup: true,
    note: "",
  },
  {
    time: "0:02",
    title: "It should launch to the Otter Flap title screen",
    note: "Title, “Paddle through the driftwood” and Best 3 are readable.",
  },
  {
    time: "0:06",
    title: "It should start the run on the first tap",
    note: "Tap to flap dismissed; otter rises, then gravity takes over.",
  },
  {
    time: "0:13",
    title: "It should score when passing a driftwood gap",
    note: "Score goes 0 → 1 after the first log pair; no clipping.",
  },
  {
    time: "0:19",
    title: "It should end the run on a log collision",
    note: "Game over card shows score 4 and a new Best 4.",
  },
  {
    time: "0:25",
    title: "It should pause and resume the run",
    note: "Resume returns to the same frame; logs keep their spacing.",
  },
  {
    time: "0:31",
    title: "It should keep the best score after relaunch",
    note: "Quit and relaunch; Best 4 persists on the title screen.",
  },
];
