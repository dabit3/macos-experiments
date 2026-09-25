import { AbsoluteFill, Img, staticFile, useCurrentFrame } from "remotion";
import { cameraPose, flatness, homography, projectScreen } from "./camera";
import { easeInOutQuint, easeOutCubic, mix, ramp } from "./ease";
import { Studio } from "./scene/Studio";
import { T } from "./timeline";
import { Cursor } from "./ui/Cursor";
import { Home } from "./ui/Home";
import { Session } from "./ui/Session";
import { TestRecording } from "./ui/TestRecording";
import { C, inter, UI_H, UI_W, UI_ZOOM } from "./ui/tokens";

const ZOOM = 1.45;
const FOCUS = { x: 943, y: 396 };

const uiZoom = (frame: number) => {
  const t = ramp(frame, T.zoomIn, T.zoomIn + 70, easeInOutQuint) * (1 - ramp(frame, T.zoomOut, T.zoomOut + 60, easeInOutQuint));
  const s = mix(1, ZOOM, t);
  const vw = UI_W / s;
  const vh = UI_H / s;
  const cx = Math.min(Math.max(FOCUS.x, vw / 2), UI_W - vw / 2);
  const cy = Math.min(Math.max(FOCUS.y, vh / 2), UI_H - vh / 2);
  const tx = mix(0, -(cx - vw / 2) * s, t > 0 ? 1 : 0);
  const ty = mix(0, -(cy - vh / 2) * s, t > 0 ? 1 : 0);
  return { s, tx, ty };
};

const Screens: React.FC<{ frame: number }> = ({ frame }) => {
  const { s, tx, ty } = uiZoom(frame);
  return (
    <div style={{ position: "absolute", inset: 0, transformOrigin: "0 0", transform: s === 1 ? undefined : `translate(${tx}px, ${ty}px) scale(${s})` }}>
      {frame < T.session + 12 && <Home frame={frame} />}
      {frame >= T.session && frame < T.recording + 24 && <Session frame={frame} />}
      {frame >= T.recording && <TestRecording frame={frame} />}
      <Cursor frame={frame} />
    </div>
  );
};

const EndCard: React.FC<{ frame: number }> = ({ frame }) => {
  const bg = ramp(frame, T.endCard, T.endCard + 36, easeInOutQuint);
  if (bg <= 0) return null;
  const logo = ramp(frame, T.endCard + 18, T.endCard + 58, easeOutCubic);
  const line = ramp(frame, T.endCard + 32, T.endCard + 72, easeOutCubic);
  return (
    <AbsoluteFill style={{ background: C.page, opacity: bg, alignItems: "center", justifyContent: "center" }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
        <Img
          src={staticFile("brand/devin-lockup-black.png")}
          style={{ width: 430, opacity: logo, transform: `translateY(${(1 - logo) * 10}px)` }}
        />
        <div
          style={{
            fontFamily: inter,
            fontWeight: 500,
            fontSize: 30,
            letterSpacing: "-0.4px",
            color: C.muted,
            marginTop: 6,
            opacity: line,
            transform: `translateY(${(1 - line) * 8}px)`,
          }}
        >
          Now on macOS
        </div>
      </div>
    </AbsoluteFill>
  );
};

export const Video: React.FC = () => {
  const frame = useCurrentFrame();
  const pose = cameraPose(frame);
  const quad = projectScreen(pose);
  const exact = quad.every(([x, y], i) => Math.abs(x - [0, 1920, 1920, 0][i]) < 0.02 && Math.abs(y - [0, 0, 1080, 1080][i]) < 0.02);
  const glare = flatness(pose);
  const intro = 1 - ramp(frame, 0, 30, easeOutCubic);

  return (
    <AbsoluteFill style={{ background: "#f1f0ed" }}>
      <Studio pose={pose} />
      <div
        style={{
          position: "absolute",
          left: 0,
          top: 0,
          width: 1920,
          height: 1080,
          overflow: "hidden",
          transformOrigin: "0 0",
          transform: exact ? undefined : homography(quad, 1920, 1080),
        }}
      >
        <div style={{ width: UI_W, height: UI_H, zoom: UI_ZOOM, position: "relative", overflow: "hidden", background: C.page }}>
          <Screens frame={frame} />
        </div>
        {glare > 0 && (
          <div
            style={{
              position: "absolute",
              inset: 0,
              opacity: glare,
              background: "linear-gradient(115deg, rgba(255,255,255,0) 30%, rgba(255,255,255,0.07) 48%, rgba(255,255,255,0) 66%), rgba(0,0,0,0.035)",
            }}
          />
        )}
      </div>
      <EndCard frame={frame} />
      {intro > 0 && <AbsoluteFill style={{ background: "#f1f0ed", opacity: intro }} />}
    </AbsoluteFill>
  );
};
