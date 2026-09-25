import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadMono } from "@remotion/google-fonts/RobotoMono";

const interFont = loadInter("normal", { weights: ["400", "500", "600"], subsets: ["latin"] });
const monoFont = loadMono("normal", { weights: ["400", "500"], subsets: ["latin"] });
export const inter = interFont.fontFamily;
export const mono = monoFont.fontFamily;
export const fontsReady = () => Promise.all([interFont.waitUntilDone(), monoFont.waitUntilDone()]);

export const W = 1200;
export const H = 675;
export const BASE = 1920 / W;

export const C = {
  bg: "#F9F9F9",
  ink: "#191919",
  grey: "rgba(25,25,25,0.56)",
  faint: "rgba(25,25,25,0.4)",
  line: "rgba(0,0,0,0.06)",
  border: "rgba(0,0,0,0.08)",
  blue: "#337df4",
  blueBg: "rgba(51,125,244,0.1)",
  green: "#00a558",
  red: "#f53b3a",
};

export const text = (size: number, lh: number, color: string = C.ink, weight = 400, tracking = size === 14 ? -0.07 : size === 13 ? -0.065 : 0) => ({
  fontFamily: inter,
  fontSize: size,
  lineHeight: `${lh}px`,
  color,
  fontWeight: weight,
  letterSpacing: tracking,
  whiteSpace: "nowrap" as const,
});
