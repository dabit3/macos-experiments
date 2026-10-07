/** Deterministic Flappy Otter simulation in iPhone points (393 x 852). */
export const W = 393;
export const H = 852;
export const GROUND = 745;
export const OTTER_X = 112;
export const SPEED = 150;
export const SPACING = 230;
export const GAP = 190;
export const LOG_W = 58;
const FIRST = 430;

export const gapCenter = (i: number) => 330 + Math.sin(i * 1.7 + 0.4) * 95 + Math.sin(i * 0.63) * 40;
export const pipeX = (i: number, t: number) => FIRST + i * SPACING - SPEED * t;

const DT = 1 / 120;
const STEPS = 120 * 70;
const ys = new Float32Array(STEPS);
const vs = new Float32Array(STEPS);
(() => {
  let y = 380;
  let v = 0;
  for (let s = 0; s < STEPS; s++) {
    const t = s * DT;
    let i = 0;
    while (pipeX(i, t) + LOG_W / 2 < OTTER_X - 18) i++;
    const target = gapCenter(i) + 28;
    if (y > target && v > -40) v = -460;
    v = Math.min(700, v + 1500 * DT);
    y += v * DT;
    ys[s] = y;
    vs[s] = v;
  }
})();

export const otterAt = (t: number) => {
  const s = Math.max(0, Math.min(STEPS - 2, t / DT));
  const i = Math.floor(s);
  const k = s - i;
  return { y: ys[i] * (1 - k) + ys[i + 1] * k, v: vs[i] * (1 - k) + vs[i + 1] * k };
};

export const scoreAt = (t: number) => {
  let n = 0;
  while (pipeX(n, t) + LOG_W / 2 < OTTER_X - 18) n++;
  return n;
};

/** Accessibility frames exposed by the game (iPhone points). */
export const AX = {
  pause: { x: 20, y: 88, w: 36, h: 36 },
  sound: { x: 337, y: 88, w: 36, h: 36 },
  score: { x: 166, y: 160, w: 62, h: 52 },
  heading: { x: 106, y: 322, w: 181, h: 44 },
  resume: { x: 106, y: 396, w: 181, h: 52 },
  restart: { x: 106, y: 460, w: 181, h: 52 },
};
