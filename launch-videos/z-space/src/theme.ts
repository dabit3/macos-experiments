import { staticFile } from "remotion";

export const C = {
  stage: "#FAFAFB",
  page: "#F9F9F9",
  card: "#FDFDFD",
  text: "#191919",
  muted: "rgba(25,25,25,0.56)",
  faint: "rgba(25,25,25,0.4)",
  border: "rgba(0,0,0,0.08)",
  hairline: "rgba(0,0,0,0.06)",
  pass: "#00A558",
  fail: "#F53B3A",
  blue: "#2F6FEB",
  badgeBg: "#E1EBFA",
};

export const INTER = "'Inter Devin', Inter, sans-serif";
export const MONO = "'Roboto Mono Devin', 'Roboto Mono', monospace";

export const SCREEN_W = 1203;
export const SCREEN_H = 690;

export const fontCss = `
@font-face { font-family: 'Inter Devin'; font-weight: 400; src: url(${staticFile("fonts/inter-latin-400-normal.woff2")}) format('woff2'); }
@font-face { font-family: 'Inter Devin'; font-weight: 500; src: url(${staticFile("fonts/inter-latin-500-normal.woff2")}) format('woff2'); }
@font-face { font-family: 'Inter Devin'; font-weight: 600; src: url(${staticFile("fonts/inter-latin-600-normal.woff2")}) format('woff2'); }
@font-face { font-family: 'Roboto Mono Devin'; font-weight: 400; src: url(${staticFile("fonts/roboto-mono-latin-400-normal.woff2")}) format('woff2'); }
@font-face { font-family: 'Roboto Mono Devin'; font-weight: 500; src: url(${staticFile("fonts/roboto-mono-latin-500-normal.woff2")}) format('woff2'); }
* { box-sizing: border-box; }
`;
