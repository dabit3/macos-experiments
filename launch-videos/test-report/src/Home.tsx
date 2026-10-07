import { Img, interpolate, staticFile } from "remotion";
import { Apple, ArrowUp, CheckMark, Chevron, Icon, Sidebar, Sliders, Star, Ubuntu, Windows } from "./Icon";
import { C, inter, outQuint, ramp, text } from "./theme";

export const PROMPT = "Build Flappy Bird with an Otter. Then build and test it on iOS.";

const CARD = { x: 270.4, y: 286, w: 688, h: 120 };
const ENV = { x: CARD.x + 8, y: CARD.y + CARD.h + 14 };
const MENU = { x: ENV.x - 4, y: ENV.y + 30, w: 220 };

export const HOME_T = {
  envClick: 58,
  menuItemClick: 104,
  typeFrom: 136,
  typeTo: 226,
  sendClick: 262,
};

const hash = (i: number) => {
  const x = Math.sin(i * 12.9898) * 43758.5453;
  return x - Math.floor(x);
};

const typeTimes = (() => {
  const times: number[] = [];
  let t = 0;
  for (let i = 0; i < PROMPT.length; i++) {
    const ch = PROMPT[i];
    t += 0.8 + hash(i) * 0.9 + (ch === " " ? 0.35 : 0) + (".,".includes(ch) ? 1.6 : 0);
    times.push(t);
  }
  const scale = (HOME_T.typeTo - HOME_T.typeFrom) / t;
  return times.map((v) => HOME_T.typeFrom + v * scale);
})();

export const typedCount = (frame: number) => typeTimes.filter((t) => t <= frame).length;

export const HOME_POS = {
  env: { x: ENV.x + 44, y: ENV.y + 11 },
  macItem: { x: MENU.x + 70, y: MENU.y + 34 + 30 + 15 },
  text: { x: CARD.x + 340, y: CARD.y + 30 },
  send: { x: CARD.x + CARD.w - 34, y: CARD.y + 93 },
};

const Btn28: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
    {children}
  </div>
);

const MenuItem: React.FC<{
  icon: React.ReactNode;
  label: string;
  hover: number;
  trailing?: React.ReactNode;
  check?: boolean;
}> = ({ icon, label, hover, trailing, check }) => (
  <div
    style={{
      height: 30,
      margin: "0 4px",
      padding: "0 8px",
      borderRadius: 6,
      display: "flex",
      alignItems: "center",
      gap: 8,
      background: `rgba(0,0,0,${0.055 * hover})`,
    }}
  >
    <div style={{ width: 16, display: "flex", justifyContent: "center" }}>{icon}</div>
    <span style={text(14, 20, 400)}>{label}</span>
    {trailing}
    <div style={{ flex: 1 }} />
    {check ? <CheckMark size={14} /> : null}
  </div>
);

export const Home: React.FC<{ frame: number }> = ({ frame }) => {
  const typed = typedCount(frame);
  const value = PROMPT.slice(0, typed);
  const menu = ramp(frame, HOME_T.envClick + 2, HOME_T.envClick + 14, outQuint) *
    (1 - ramp(frame, HOME_T.menuItemClick + 4, HOME_T.menuItemClick + 14, outQuint));
  const hoverMac = ramp(frame, HOME_T.menuItemClick - 20, HOME_T.menuItemClick - 12);
  const isMac = frame >= HOME_T.menuItemClick + 4;
  const typing = typed > 0 && typed < PROMPT.length;
  const caretOn = frame >= HOME_T.typeFrom - 12 && frame < HOME_T.sendClick && (typing || Math.floor(frame / 30) % 2 === 0);
  const sendDark = ramp(frame, HOME_T.typeFrom, HOME_T.typeFrom + 8);
  const sendPress = frame >= HOME_T.sendClick && frame < HOME_T.sendClick + 12;
  const sendBg = `rgb(${Math.round(interpolate(sendDark, [0, 1], [129, 31]))},${Math.round(interpolate(sendDark, [0, 1], [129, 31]))},${Math.round(interpolate(sendDark, [0, 1], [129, 31]))})`;

  return (
    <div style={{ position: "absolute", inset: 0, background: C.page, fontFamily: inter }}>
      <div style={{ position: "absolute", left: 14, top: 12 }}>
        <Btn28>
          <Sidebar size={18} />
        </Btn28>
      </div>

      <div style={{ position: "absolute", left: CARD.x + 8, top: CARD.y - 46, display: "flex", alignItems: "center", gap: 7 }}>
        <Img src={staticFile("devin-mark.png")} style={{ width: 19, height: 19 }} />
        <span style={{ ...text(21, 26, 500), letterSpacing: -0.5 }}>Devin</span>
      </div>

      <div
        style={{
          position: "absolute",
          left: CARD.x + CARD.w - 8 - 112,
          top: CARD.y - 46 + 1,
          width: 112,
          height: 28,
          borderRadius: 9999,
          background: "#efefef",
          display: "flex",
          alignItems: "center",
          padding: 1,
        }}
      >
        <div
          style={{
            height: 26,
            padding: "0 12px",
            borderRadius: 9999,
            background: "#fff",
            border: "0.8px solid rgba(0,0,0,0.08)",
            display: "flex",
            alignItems: "center",
            ...text(13, 18, 400),
          }}
        >
          Agent
        </div>
        <div style={{ padding: "0 12px", ...text(13, 18, 400, C.muted) }}>Ask</div>
      </div>

      <div
        style={{
          position: "absolute",
          left: CARD.x,
          top: CARD.y,
          width: CARD.w,
          height: CARD.h,
          borderRadius: 18,
          background: C.card,
          border: `0.8px solid ${C.border}`,
          boxSizing: "border-box",
        }}
      >
        <div style={{ position: "absolute", left: 14, top: 13, right: 14, ...text(14.5, 22, 400) }}>
          {value.length === 0 ? (
            <span style={{ color: "rgba(25,25,25,0.5)" }}>Ask Devin to build features, fix bugs, or work on your code</span>
          ) : (
            <span>{value}</span>
          )}
          {caretOn ? (
            <span
              style={{
                display: "inline-block",
                width: 1.2,
                height: 17,
                background: C.text,
                verticalAlign: "-3px",
                marginLeft: value.length === 0 ? -1 : 0.5,
                position: value.length === 0 ? "absolute" : "relative",
                left: value.length === 0 ? 0 : undefined,
                top: value.length === 0 ? 2.5 : undefined,
              }}
            />
          ) : null}
        </div>

        <div style={{ position: "absolute", left: 10, bottom: 12, display: "flex", alignItems: "center", gap: 2 }}>
          <Btn28>
            <Icon name="plus" size={18} />
          </Btn28>
          <Btn28>
            <Icon name="slash" size={18} />
          </Btn28>
          <div style={{ position: "relative" }}>
            <Btn28>
              <Sliders size={18} />
            </Btn28>
            <div style={{ position: "absolute", right: 3, top: 3, width: 6, height: 6, borderRadius: 3, background: "#1f6bff" }} />
          </div>
          <div style={{ marginLeft: 6, ...text(14, 20, 400, "rgba(25,25,25,0.7)") }}>Fusion</div>
        </div>

        <div style={{ position: "absolute", right: 10, bottom: 12, display: "flex", alignItems: "center", gap: 2 }}>
          <Btn28>
            <Icon name="mic" size={18} style={{ opacity: 0.8 }} />
          </Btn28>
          <Btn28>
            <Icon name="voice" size={18} style={{ opacity: 0.8 }} />
          </Btn28>
          <div
            style={{
              marginLeft: 4,
              height: 28,
              width: 56,
              borderRadius: 9999,
              background: sendBg,
              display: "flex",
              alignItems: "center",
              overflow: "hidden",
              transform: sendPress ? "scale(0.96)" : undefined,
            }}
          >
            <div style={{ width: 29, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <ArrowUp size={16} />
            </div>
            <div style={{ width: 0.8, height: 28, background: "rgba(255,255,255,0.18)" }} />
            <div style={{ flex: 1, display: "flex", justifyContent: "center" }}>
              <Chevron size={12} color="#fff" />
            </div>
          </div>
        </div>
      </div>

      <div style={{ position: "absolute", left: ENV.x, top: ENV.y, height: 22, display: "flex", alignItems: "center", gap: 6 }}>
        {isMac ? <Apple size={15} color="#4a4a4a" /> : <Ubuntu size={14} />}
        <span style={text(13.5, 18, 400, "rgba(25,25,25,0.75)")}>{isMac ? "macOS" : "Ubuntu"}</span>
        <Chevron size={12} />
      </div>

      {menu > 0.001 ? (
        <div
          style={{
            position: "absolute",
            left: MENU.x,
            top: MENU.y,
            width: MENU.w,
            paddingBottom: 4,
            borderRadius: 10,
            background: "#fff",
            border: "0.8px solid rgba(0,0,0,0.08)",
            boxShadow: "0 4px 16px rgba(0,0,0,0.06), 0 1px 3px rgba(0,0,0,0.04)",
            opacity: menu,
            transform: `translateY(${(1 - menu) * -4}px) scale(${0.98 + 0.02 * menu})`,
            transformOrigin: "20% 0",
          }}
        >
          <div style={{ height: 34, display: "flex", alignItems: "center", padding: "0 12px", ...text(13, 18, 400, C.muted) }}>Hosted</div>
          <MenuItem icon={<Ubuntu size={14} />} label="Ubuntu" hover={0} trailing={<Star filled size={13} color="rgba(25,25,25,0.5)" />} check={!isMac} />
          <MenuItem
            icon={<Apple size={15} color="#555" />}
            label="macOS"
            hover={hoverMac}
            check={isMac}
            trailing={
              <span
                style={{
                  ...text(11, 16, 500, "#1c6ae4"),
                  background: "rgba(51,125,244,0.1)",
                  borderRadius: 4,
                  padding: "0 5px",
                  letterSpacing: 0,
                }}
              >
                New
              </span>
            }
          />
          <MenuItem icon={<Windows size={13} />} label="Windows" hover={0} trailing={<Star size={13} color="rgba(25,25,25,0.5)" />} />
        </div>
      ) : null}
    </div>
  );
};
