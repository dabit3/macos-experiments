export const FPS = 60;
export const S = (s: number) => Math.round(s * FPS);

export const HOME = { from: 0, dur: S(5) };
export const SESSION = { from: S(4.6), dur: S(5.6) };
export const PLAYER = { from: S(9.8), dur: S(20.2) };
export const END = { from: S(29.6), dur: S(3.4) };
export const TOTAL = END.from + END.dur;

export const TEST_START = S(1.1);
