import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadMono } from "@remotion/google-fonts/RobotoMono";
import { Easing, interpolate } from "remotion";

export const inter = loadInter("normal", {
  weights: ["400", "500", "600"],
  subsets: ["latin"],
}).fontFamily;
export const mono = loadMono("normal", {
  weights: ["400", "500"],
  subsets: ["latin"],
}).fontFamily;

export const C = {
  page: "#f9f9f9",
  panel: "#fcfcfc",
  card: "#fdfdfd",
  text: "#191919",
  muted: "rgba(25,25,25,0.56)",
  faint: "rgba(25,25,25,0.4)",
  border: "rgba(0,0,0,0.08)",
  hairline: "rgba(0,0,0,0.06)",
  hover: "rgba(0,0,0,0.04)",
  green: "#00a558",
  red: "#f53b3a",
  blue: "#337df4",
};

export const text = (
  size: number,
  line: number,
  weight = 400,
  color = C.text,
): React.CSSProperties => ({
  fontFamily: inter,
  fontSize: size,
  lineHeight: `${line}px`,
  fontWeight: weight,
  letterSpacing: size >= 13 ? -size * 0.005 : 0,
  color,
});

export const monoText = (color = C.faint): React.CSSProperties => ({
  fontFamily: mono,
  fontSize: 11,
  lineHeight: "14px",
  letterSpacing: 0.11,
  color,
});

export const quint = Easing.bezier(0.83, 0, 0.17, 1);
export const outQuint = Easing.bezier(0.22, 1, 0.36, 1);
export const outCubic = Easing.bezier(0.33, 1, 0.68, 1);

export const ramp = (
  f: number,
  from: number,
  to: number,
  ease: (t: number) => number = quint,
) =>
  interpolate(f, [from, to], [0, 1], {
    easing: ease,
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

export const mix = (a: number, b: number, t: number) => a + (b - a) * t;
