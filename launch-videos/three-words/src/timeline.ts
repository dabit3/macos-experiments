export const FPS = 60;

export const PROMPT_HEAD = "Build";
export const PROMPT_TAIL = " Flappy Bird with an Otter. Then build and test it on iOS.";

const cadence = (i: number, ch: string, prev: string) => {
  const r = Math.abs(Math.sin((i + 1) * 12.9898) * 43758.5453) % 1;
  let d = 2 + Math.floor(r * 3);
  if (prev === "." || prev === ",") d += 9;
  else if (ch === " " && r > 0.72) d += 3;
  return d;
};

export const TYPE_START = 134;
export const TYPE_TIMES: number[] = (() => {
  const out: number[] = [];
  let t = TYPE_START;
  for (let i = 0; i < PROMPT_TAIL.length; i++) {
    t += cadence(i, PROMPT_TAIL[i], i ? PROMPT_TAIL[i - 1] : "");
    out.push(t);
  }
  return out;
})();
export const TYPE_END = TYPE_TIMES[TYPE_TIMES.length - 1];

export const T = {
  buildIn: 8,
  buildMorph: [84, 134] as const,
  cursorIn: TYPE_END + 6,
  pickerClick: TYPE_END + 50,
  macClick: TYPE_END + 92,
  sendClick: TYPE_END + 146,
  get homeOut() {
    return this.sendClick + 8;
  },
  get session() {
    return this.sendClick + 16;
  },
  runCut: 0,
  runMorph: [0, 0] as [number, number],
  split: 0,
  verifyCut: 0,
  verifyMorph: [0, 0] as [number, number],
  viewer: 0,
  end: 0,
};
T.runCut = T.session + 236;
T.runMorph = [T.runCut + 66, T.runCut + 116];
T.split = T.runMorph[0] + 20;
T.verifyCut = T.split + 372;
T.verifyMorph = [T.verifyCut + 66, T.verifyCut + 116];
T.viewer = T.verifyMorph[0] + 20;
T.end = T.viewer + 400;

export const DURATION = T.end + 170;
