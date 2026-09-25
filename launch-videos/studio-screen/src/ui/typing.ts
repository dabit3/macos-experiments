import { T } from "../timeline";

export const PROMPT = "Build Flappy Bird with an Otter. Then build and test it on iOS.";

const rand = (i: number) => {
  const x = Math.sin(i * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
};

const schedule: number[] = (() => {
  const out: number[] = [];
  let f = T.typeStart;
  for (let i = 0; i < PROMPT.length; i++) {
    const ch = PROMPT[i];
    const prev = PROMPT[i - 1];
    let d = 1.6 + rand(i) * 1.6;
    if (prev === " ") d += 0.6 + rand(i + 99) * 0.8;
    if (prev === ".") d += 7;
    if (ch === ch.toUpperCase() && /[A-Z]/.test(ch)) d += 1.2;
    f += d;
    out.push(f);
  }
  return out;
})();

export const TYPE_END = schedule[schedule.length - 1];

export const typedLength = (frame: number) => {
  let n = 0;
  while (n < schedule.length && schedule[n] <= frame) n++;
  return n;
};
