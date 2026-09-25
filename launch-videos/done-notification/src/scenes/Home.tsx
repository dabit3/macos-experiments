import { useCurrentFrame } from "remotion";
import { camStyle, camTrack, cursorAt, pressAt, ramp, typedCount, typingEnd } from "../anim";
import { F } from "../timeline";
import { C, T12, T13, T14 } from "../tokens";
import { Cursor, Icon, IconButton, Screen, SendButton } from "../ui/Primitives";

export const PROMPT = "Build Flappy Bird with an Otter. Then build and test it on iOS.";

const TOP = 79.2;
const LEFT = 290;
const BOX_Y = TOP + 220;
const ENV_Y = BOX_Y + 121.6 + 12;

const Ubuntu: React.FC<{ size?: number }> = ({ size = 14 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <circle cx="12" cy="12" r="6.6" fill="none" stroke="#e95420" strokeWidth="2.6" />
    <circle cx="4.6" cy="12" r="2.6" fill="#e95420" stroke="#fff" strokeWidth="1.4" />
    <circle cx="15.7" cy="5.6" r="2.6" fill="#e95420" stroke="#fff" strokeWidth="1.4" />
    <circle cx="15.7" cy="18.4" r="2.6" fill="#e95420" stroke="#fff" strokeWidth="1.4" />
  </svg>
);

const Windows: React.FC = () => (
  <svg width={14} height={14} viewBox="0 0 14 14">
    <rect x="0.5" y="0.5" width="6.2" height="6.2" fill="#f25022" />
    <rect x="7.3" y="0.5" width="6.2" height="6.2" fill="#7fba00" />
    <rect x="0.5" y="7.3" width="6.2" height="6.2" fill="#00a4ef" />
    <rect x="7.3" y="7.3" width="6.2" height="6.2" fill="#ffb900" />
  </svg>
);

const Star: React.FC<{ filled: boolean; color: string }> = ({ filled, color }) => (
  <svg width={13} height={13} viewBox="0 0 24 24">
    <path
      d="M12 2.8l2.8 5.9 6.4.8-4.7 4.4 1.2 6.4L12 17.2l-5.7 3.1 1.2-6.4-4.7-4.4 6.4-.8z"
      fill={filled ? color : "none"}
      stroke={color}
      strokeWidth={filled ? 0 : 1.8}
      strokeLinejoin="round"
    />
  </svg>
);

const Check: React.FC<{ color: string }> = ({ color }) => (
  <svg width={14} height={14} viewBox="0 0 16 16">
    <path d="M3 8.5l3.2 3.2L13 4.8" fill="none" stroke={color} strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

const NewBadge: React.FC = () => (
  <span
    style={{
      ...T12,
      fontSize: 11,
      lineHeight: "14px",
      fontWeight: 500,
      color: C.blue,
      background: C.blueTint,
      borderRadius: 4,
      padding: "1px 5px",
    }}
  >
    New
  </span>
);

const EnvMenu: React.FC<{ open: number; hover: "ubuntu" | "macos" | null; selected: "ubuntu" | "macos" }> = ({
  open,
  hover,
  selected,
}) => {
  const row = (key: "ubuntu" | "macos" | "windows", icon: React.ReactNode, label: string, extra: React.ReactNode) => (
    <div
      style={{
        height: 30,
        display: "flex",
        alignItems: "center",
        gap: 8,
        padding: "0 10px",
        borderRadius: 6,
        background: hover === key ? "rgba(0,0,0,0.06)" : "transparent",
        ...T13,
      }}
    >
      <div style={{ width: 14, display: "flex", justifyContent: "center" }}>{icon}</div>
      <span>{label}</span>
      {extra}
      <div style={{ flex: 1 }} />
      {selected === key ? <Check color={hover === key ? C.text : C.muted} /> : null}
    </div>
  );
  return (
    <div
      style={{
        position: "absolute",
        left: LEFT + 12,
        top: ENV_Y + 22,
        width: 221,
        background: "#fff",
        border: `0.8px solid ${C.border}`,
        borderRadius: 10,
        boxShadow: "0 4px 16px rgba(0,0,0,0.08), 0 1px 3px rgba(0,0,0,0.05)",
        padding: 4,
        boxSizing: "border-box",
        opacity: open,
        transformOrigin: "20px 0",
        transform: `translateY(${(1 - open) * -4}px) scale(${0.98 + open * 0.02})`,
      }}
    >
      <div style={{ ...T12, color: C.muted, padding: "7px 10px 5px" }}>Hosted</div>
      {row("ubuntu", <Ubuntu />, "Ubuntu", <Star filled color={hover === "ubuntu" ? C.text : C.muted} />)}
      {row(
        "macos",
        <Icon id="32f69" size={14} style={{ opacity: hover === "macos" ? 1 : 0.7 }} />,
        "macOS",
        <>
          {hover === "macos" ? <Star filled={false} color={C.text} /> : null}
          <NewBadge />
        </>,
      )}
      {row("windows", <Windows />, "Windows", null)}
    </div>
  );
};

export const HomeScene: React.FC = () => {
  const f = useCurrentFrame();
  const cam = camTrack(f, [
    [F.toHomeStart, { x: 640, y: 352, z: 1.52 }],
    [F.toHomeEnd + 10, { x: 640, y: 352, z: 1.45 }],
    [F.envOpen - 8, { x: 560, y: 390, z: 1.62 }],
    [F.envPick + 10, { x: 560, y: 390, z: 1.62 }],
    [F.typeStart + 20, { x: 640, y: 362, z: 1.58 }],
    [F.send + 20, { x: 700, y: 362, z: 1.6 }],
    [F.toSessionEnd, { x: 690, y: 330, z: 1.4 }],
  ]);

  const macos = f >= F.envPick + 2;
  const menuOpen =
    f < F.envOpen ? 0 : f < F.envPick + 4 ? ramp(f, F.envOpen, F.envOpen + 10) : 1 - ramp(f, F.envPick + 4, F.envPick + 14);
  const hover = f > F.envOpen + 28 ? "macos" : f > F.envOpen ? "ubuntu" : null;

  const n = typedCount(f, F.typeStart, PROMPT);
  const typed = PROMPT.slice(0, n);
  const doneTyping = typingEnd(F.typeStart, PROMPT);
  const caretOn = f < F.typeStart || f < doneTyping ? true : Math.floor((f - doneTyping) / 32) % 2 === 0;

  const envX = LEFT + 16 + 30;
  const envYc = ENV_Y + 8;
  const sendX = LEFT + 6 + 688 - 12 - 40;
  const sendY = BOX_Y + 121.6 - 12 - 14;
  const cur = cursorAt(f, [
    { f: F.toHomeEnd, x: 760, y: 560 },
    { f: F.envOpen - 6, x: envX, y: envYc + 2 },
    { f: F.envOpen + 14, x: envX + 4, y: envYc + 4 },
    { f: F.envPick - 6, x: LEFT + 70, y: ENV_Y + 22 + 4 + 28 + 30 + 14 },
    { f: F.typeStart - 4, x: LEFT + 420, y: BOX_Y + 60 },
    { f: doneTyping + 10, x: LEFT + 460, y: BOX_Y + 66 },
    { f: F.send - 4, x: sendX + 2, y: sendY + 2 },
  ]);
  const press = pressAt(f, [F.envOpen, F.envPick, F.send]);
  const cursorOpacity = f < doneTyping - 60 && f > F.typeStart + 10 ? 1 - ramp(f, F.typeStart + 10, F.typeStart + 24) : 1;

  return (
    <Screen>
      <div style={camStyle(cam)}>
        <div style={{ position: "absolute", left: 12, top: 8 }}>
          <IconButton id="74b9c" />
        </div>
        <div style={{ position: "absolute", left: LEFT, top: TOP + 220 - 16 - 28, width: 700, height: 28 }}>
          <div style={{ position: "absolute", left: 16, top: 3, width: 82.82, height: 22 }}>
            <Icon id="fb89d" w={19.36} h={22} style={{ position: "absolute", left: 0, top: 0 }} />
            <Icon id="1e515" w={55.09} h={16.75} style={{ position: "absolute", left: 27.64, top: 2.73 }} />
          </div>
          <div
            style={{
              position: "absolute",
              right: 12,
              top: 0,
              display: "flex",
              gap: 1,
              background: "rgba(0,0,0,0.04)",
              borderRadius: 20,
              alignItems: "center",
            }}
          >
            <div
              style={{
                background: "#fff",
                border: "0.8px solid rgba(0,0,0,0.06)",
                borderRadius: 9999,
                padding: "4px 12px",
                boxShadow: "0 1px 1px rgba(0,0,0,0.05)",
                ...T13,
              }}
            >
              Agent
            </div>
            <div style={{ border: "0.8px solid transparent", padding: "4px 12px", ...T13, color: C.muted }}>Ask</div>
          </div>
        </div>
        <div style={{ position: "absolute", left: LEFT + 6, top: BOX_Y, width: 688, height: 121.6 }}>
          <div
            style={{
              position: "absolute",
              inset: 0,
              background: "#fff",
              border: `0.8px solid ${C.border}`,
              borderRadius: 20,
              padding: 12,
              boxSizing: "border-box",
            }}
          >
            <div style={{ padding: 4, ...T14, whiteSpace: "nowrap", color: n > 0 ? C.text : C.muted, position: "relative" }}>
              {n > 0 ? typed : "Ask Devin to build features, fix bugs, or work on your code"}
              {f >= F.typeStart - 20 && f < F.send ? (
                <span
                  style={{
                    position: n > 0 ? "relative" : "absolute",
                    left: n > 0 ? 0 : 4,
                    display: "inline-block",
                    width: 1.2,
                    height: 17,
                    marginLeft: 1,
                    background: C.text,
                    verticalAlign: "-3px",
                    opacity: caretOn ? 1 : 0,
                  }}
                />
              ) : null}
            </div>
            <div style={{ position: "absolute", left: 8, top: 76, display: "flex", gap: 1, alignItems: "center", padding: 4 }}>
              <IconButton id="2c01e" round />
              <IconButton id="38518" round />
              <div style={{ position: "relative" }}>
                <IconButton id="cd006" round />
                <div style={{ position: "absolute", left: 19, top: 3, width: 6, height: 6, borderRadius: 9999, background: "#317cff" }} />
              </div>
              <div style={{ padding: "0 10px", ...T13, color: C.muted }}>Fusion</div>
            </div>
            <div style={{ position: "absolute", right: 12, top: 81.6, display: "flex", gap: 4, alignItems: "center" }}>
              <IconButton id="11456" round />
              <IconButton id="70d60" round />
              <SendButton active={n > 0 ? 1 : 0} pressed={pressAt(f, [F.send])} />
            </div>
          </div>
        </div>
        <div style={{ position: "absolute", left: LEFT + 16, top: ENV_Y, height: 16, display: "flex", gap: 4, alignItems: "center" }}>
          {macos ? <Icon id="32f69" size={14} /> : <Ubuntu />}
          <span style={{ ...T12, color: C.muted }}>{macos ? "macOS" : "Ubuntu"}</span>
          <Icon id="fc52a" size={14} />
        </div>
        {menuOpen > 0 ? <EnvMenu open={menuOpen} hover={hover} selected={macos ? "macos" : "ubuntu"} /> : null}
        <Cursor x={cur.x} y={cur.y} press={press} opacity={cursorOpacity} />
      </div>
    </Screen>
  );
};
