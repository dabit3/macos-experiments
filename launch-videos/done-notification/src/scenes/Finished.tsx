import { useCurrentFrame } from "remotion";
import { camStyle, camTrack, cursorAt, easeInOutQuint, pressAt, ramp } from "../anim";
import { F, RECORDING_SECONDS } from "../timeline";
import { C, T13, T14 } from "../tokens";
import { RecordingCard, UserBubble } from "../ui/Chat";
import { ChatInput, Cursor, Screen, SessionHeader } from "../ui/Primitives";
import { PROMPT } from "./Home";
import { PlayerMedia, RECORDING_TITLE, TESTS } from "./Player";
import { SESSION_TITLE } from "./Session";

const COL_X = 280;
const CARD_Y = 186;
export const THUMB = { x: COL_X + 6, y: CARD_Y + 40, w: 348, h: 261.4 };
const THUMB_CAM = { x: THUMB.x + THUMB.w / 2, y: THUMB.y + THUMB.h / 2, z: 1280 / THUMB.w };
const REST = { x: 560, y: 300, z: 1.5 };

export const DONE_MESSAGE = "I'm done building the Flappy Otter game. Check out this recording I made.";

export const FinishedScene: React.FC = () => {
  const f = useCurrentFrame();
  const cam =
    f < F.returnStart
      ? camTrack(
          f,
          [
            [0, { x: 572, y: 306, z: 1.62 }],
            [F.expandStart, REST],
            [F.expandEnd, THUMB_CAM],
          ],
          easeInOutQuint,
        )
      : camTrack(
          f,
          [
            [F.returnStart, THUMB_CAM],
            [F.returnEnd, { ...REST, z: 1.44 }],
            [F.endStart + 40, { ...REST, z: 1.38 }],
          ],
          easeInOutQuint,
        );
  const cur = cursorAt(f, [
    { f: 36, x: 820, y: 560 },
    { f: F.openClick - 8, x: THUMB.x + THUMB.w / 2 + 4, y: THUMB.y + THUMB.h / 2 + 6 },
  ]);
  const hover = f < F.returnStart ? ramp(f, F.openClick - 22, F.openClick - 6) : 0;
  const press = pressAt(f, [F.openClick]);
  const cursorO = f < F.returnStart ? ramp(f, 36, 52) * (1 - ramp(f, F.openClick + 10, F.openClick + 24)) : 0;
  return (
    <Screen>
      <div style={camStyle(cam)}>
        <SessionHeader title={SESSION_TITLE} width={1280} />
        <div style={{ position: "absolute", left: COL_X, top: 64, width: 720 }}>
          <UserBubble text={PROMPT} />
        </div>
        <div style={{ position: "absolute", left: COL_X, top: 120, ...T13, color: C.muted, display: "flex", gap: 4, alignItems: "center" }}>
          Worked for 14m 12s
          <svg width={14} height={14} viewBox="0 0 16 16">
            <path d="M6 4l4 4-4 4" fill="none" stroke={C.muted} strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </div>
        <div style={{ position: "absolute", left: COL_X, top: 152, width: 720, ...T14 }}>{DONE_MESSAGE}</div>
        <div style={{ position: "absolute", left: COL_X, top: CARD_Y }}>
          <RecordingCard
            title={RECORDING_TITLE}
            passed={TESTS.length}
            hover={hover}
            playPress={press}
            playOpacity={f < F.returnStart ? 1 - ramp(f, F.openClick + 4, F.openClick + 30) : ramp(f, F.returnEnd - 30, F.returnEnd)}
            thumb={<PlayerMedia t={RECORDING_SECONDS} width={346.4} height={259.8} />}
          />
        </div>
        <div style={{ position: "absolute", left: COL_X - 14, top: 720 - 8 - 107.6 }}>
          <ChatInput width={748} placeholder="Ask Devin to build features, fix bugs, or work on your code" model="Opus 5.5 (Preview)" working={false} />
        </div>
        <Cursor x={cur.x} y={cur.y} opacity={cursorO} press={press} />
      </div>
    </Screen>
  );
};
