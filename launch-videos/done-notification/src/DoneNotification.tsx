import { AbsoluteFill, useCurrentFrame } from "remotion";
import { camStyle, camTrack, easeInOut, easeInOutQuint, ramp, track } from "./anim";
import "./fonts";
import { EndCard } from "./scenes/EndCard";
import { FinishedScene } from "./scenes/Finished";
import { HomeScene } from "./scenes/Home";
import { TestPlayer } from "./scenes/Player";
import { SessionScene } from "./scenes/Session";
import { F, RECORDING_SECONDS } from "./timeline";
import { C } from "./tokens";

const FULL = { x: 640, y: 360, z: 1 };
const MEDIA_CAM = { x: 432, y: 346, z: 1280 / 864 };

const Layer: React.FC<{ opacity: number; scale?: number; blur?: number; children: React.ReactNode }> = ({
  opacity,
  scale = 1,
  blur = 0,
  children,
}) =>
  opacity <= 0 ? null : (
    <div
      style={{
        position: "absolute",
        inset: 0,
        width: 1280,
        height: 720,
        opacity,
        transform: scale !== 1 ? `scale(${scale})` : undefined,
        transformOrigin: "640px 360px",
        filter: blur > 0.05 ? `blur(${blur}px)` : undefined,
      }}
    >
      {children}
    </div>
  );

export const DoneNotification: React.FC = () => {
  const f = useCurrentFrame();

  const finishedO = f < F.expandEnd + 2 ? 1 : f >= F.returnStart ? 1 - ramp(f, F.endStart, F.endStart + 40, easeInOut) : 0;

  const rewindPhase = f < F.toHomeEnd;
  const playerO = rewindPhase
    ? ramp(f, F.playerInStart, F.expandEnd, easeInOut) * (1 - ramp(f, F.toHomeStart, F.toHomeEnd, easeInOut))
    : ramp(f, F.playerStart, F.playerIn, easeInOut) * (1 - ramp(f, F.returnStart, F.returnStart + 36, easeInOut));
  const playerT = rewindPhase
    ? track(f, [[F.scrubStart, RECORDING_SECONDS], [F.scrubEnd, 0]], easeInOutQuint)
    : track(f, [[F.playerIn, 0], [F.playEnd, RECORDING_SECONDS]], (x) => x);
  const scrubSpeed = rewindPhase ? Math.abs(track(f + 1, [[F.scrubStart, RECORDING_SECONDS], [F.scrubEnd, 0]], easeInOutQuint) - playerT) : 0;
  const playerCam = rewindPhase
    ? f < F.toHomeStart
      ? camTrack(f, [
          [F.expandEnd, MEDIA_CAM],
          [F.expandEnd + 40, FULL],
        ])
      : { ...FULL, z: 1 - ramp(f, F.toHomeStart, F.toHomeEnd, easeInOut) * 0.04 }
    : camTrack(f, [
        [F.playerIn, { x: 640, y: 360, z: 1 }],
        [F.playerIn + 60, { x: 1060, y: 300, z: 1.55 }],
        [F.playEnd - 90, { x: 1060, y: 420, z: 1.55 }],
        [F.playEnd - 30, FULL],
        [F.returnStart + 4, MEDIA_CAM],
      ]);
  const playerScale = rewindPhase ? 1 : 0.985 + ramp(f, F.playerStart, F.playerIn, easeInOut) * 0.015;

  const homeIn = ramp(f, F.toHomeStart, F.toHomeEnd, easeInOut);
  const homeO = f < F.toHomeStart || f > F.toSessionEnd ? 0 : homeIn * (1 - ramp(f, F.toSessionStart, F.toSessionEnd, easeInOut));
  const sessionO = f < F.toSessionStart || f > F.playerIn ? 0 : ramp(f, F.toSessionStart, F.toSessionEnd, easeInOut);

  return (
    <AbsoluteFill style={{ background: C.bg }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: 1280, height: 720, transform: "scale(1.5)", transformOrigin: "0 0", overflow: "hidden" }}>
        {f >= F.endStart ? <EndCard /> : null}
        <Layer opacity={finishedO}>
          <FinishedScene />
        </Layer>
        <Layer opacity={homeO} scale={1.035 - homeIn * 0.035} blur={(1 - homeIn) * 6}>
          <HomeScene />
        </Layer>
        <Layer opacity={sessionO}>
          <SessionScene />
        </Layer>
        <Layer opacity={playerO} blur={rewindPhase ? ramp(f, F.toHomeStart, F.toHomeEnd, easeInOut) * 6 : 0}>
          <div style={camStyle(playerCam)}>
            <TestPlayerWrap t={playerT} blur={Math.min(2.5, scrubSpeed * 2.2)} scale={playerScale} />
          </div>
        </Layer>
      </div>
    </AbsoluteFill>
  );
};

const TestPlayerWrap: React.FC<{ t: number; blur: number; scale: number }> = ({ t, blur, scale }) => (
  <div style={{ position: "absolute", inset: 0, transform: `scale(${scale})`, transformOrigin: "640px 360px" }}>
    <TestPlayer t={t} blur={blur} />
  </div>
);
