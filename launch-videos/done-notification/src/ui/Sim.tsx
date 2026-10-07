import { Img, staticFile } from "remotion";

export const SIM_W = 868;
export const SIM_H = 652;
export const SIM_FRAMES = 540;

export const simSrc = (i: number): string =>
  staticFile(`generated/sim/${String(Math.max(0, Math.min(SIM_FRAMES - 1, Math.round(i)))).padStart(4, "0")}.jpg`);

export const Sim: React.FC<{ frame: number; width: number; style?: React.CSSProperties }> = ({ frame, width, style }) => (
  <Img
    src={simSrc(frame)}
    style={{ width, height: (width * SIM_H) / SIM_W, display: "block", ...style }}
  />
);
