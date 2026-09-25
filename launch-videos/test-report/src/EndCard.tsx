import { Img, staticFile } from "remotion";
import { C, inter, outQuint, ramp } from "./theme";

export const EndCard: React.FC<{ frame: number }> = ({ frame }) => {
  const bg = ramp(frame, 0, 30);
  const logo = ramp(frame, 14, 58, outQuint);
  const line = ramp(frame, 34, 78, outQuint);
  return (
    <div style={{ position: "absolute", inset: 0, background: C.page, opacity: bg }}>
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: 430,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
        }}
      >
        <Img
          src={staticFile("devin-lockup.png")}
          style={{
            height: 136,
            opacity: logo,
            transform: `translateY(${(1 - logo) * 14}px) scale(${0.985 + 0.015 * logo})`,
          }}
        />
        <div
          style={{
            marginTop: 34,
            fontFamily: inter,
            fontSize: 32,
            lineHeight: "44px",
            fontWeight: 400,
            letterSpacing: -0.3,
            color: "rgba(25,25,25,0.56)",
            opacity: line,
            transform: `translateY(${(1 - line) * 10}px)`,
          }}
        >
          Devin, now on macOS
        </div>
      </div>
    </div>
  );
};
