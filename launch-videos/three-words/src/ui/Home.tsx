import { C, LW } from "../theme";
import { Box, Caret, CheckIcon, Icon, Logo, StarIcon, UbuntuIcon, WindowsIcon, text } from "./primitives";

export const HX = (LW - 700) / 2;
export const COMPOSER = { x: HX + 6, y: 284, w: 688, h: 121.6 };
export const PROMPT_POS = { x: COMPOSER.x + 0.8 + 12 + 4, y: COMPOSER.y + 0.8 + 12 + 4 };
export const PICKER = { x: HX + 16, y: 405.6 + 12, w: 84.981, h: 16 };
export const MENU = { x: PICKER.x, y: 440, w: 221 };
export const MENU_ROW = (i: number) => ({ x: MENU.x + 4, y: MENU.y + 4 + 26 + i * 30, w: MENU.w - 8, h: 30 });
export const SEND = { x: COMPOSER.x + 0.8 + 12 + 548.4 + 8 + 52 + 4, y: COMPOSER.y + 0.8 + 12 + 68, w: 54, h: 28 };

type Env = "ubuntu" | "macos";

export const Home: React.FC<{
  prompt: string;
  promptOpacity: number;
  placeholder: number;
  caret: boolean;
  env: Env;
  menu: number;
  hover: number;
  sendPress: number;
}> = ({ prompt, promptOpacity, placeholder, caret, env, menu, hover, sendPress }) => {
  const hasText = prompt.length > 0;
  return (
    <>
      <div style={{ position: "absolute", left: 12, top: 8 }}>
        <Box radius={6}>
          <Icon name="sidebar" size={18} />
        </Box>
      </div>
      <div
        style={{
          position: "absolute",
          left: HX,
          top: 240,
          width: 700,
          height: 28,
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "0 12px 0 16px",
          boxSizing: "border-box",
        }}
      >
        <Logo />
        <div style={{ display: "flex", gap: 1, alignItems: "center", background: C.fill04, borderRadius: 20 }}>
          <div
            style={{
              background: "#fff",
              border: `0.8px solid ${C.line06}`,
              borderRadius: 9999,
              padding: "4px 12px",
              boxShadow: "0px 1px 2px 0px rgba(0,0,0,0.04)",
            }}
          >
            <span style={text(13, 18)}>Agent</span>
          </div>
          <div style={{ border: "0.8px solid transparent", borderRadius: 9999, padding: "4px 12px" }}>
            <span style={text(13, 18, C.ink56)}>Ask</span>
          </div>
        </div>
      </div>

      <div
        style={{
          position: "absolute",
          left: COMPOSER.x,
          top: COMPOSER.y,
          width: COMPOSER.w,
          height: COMPOSER.h,
          background: "#fff",
          border: `0.8px solid ${C.line08}`,
          borderRadius: 20,
          boxSizing: "border-box",
        }}
      >
        <div style={{ position: "absolute", left: 16, top: 16, ...text(14, 20, hasText ? C.ink : C.ink56) }}>
          <span style={{ opacity: hasText ? promptOpacity : placeholder }}>{hasText ? prompt : "Ask Devin to build features, fix bugs, or work on your code"}</span>
          {caret ? <Caret on /> : null}
        </div>
        <div style={{ position: "absolute", left: 8, top: 76, height: 36, display: "flex", alignItems: "center", gap: 1, padding: 4, boxSizing: "border-box" }}>
          <Box>
            <Icon name="plus" size={18} />
          </Box>
          <Box>
            <Icon name="slash" size={18} />
          </Box>
          <div style={{ position: "relative" }}>
            <Box>
              <Icon name="config" size={18} />
            </Box>
            <div style={{ position: "absolute", left: 19, top: 3, width: 6, height: 6, borderRadius: 9999, background: "#317cff" }} />
          </div>
          <div style={{ height: 28, display: "flex", alignItems: "center", padding: "0 6px", border: "0.8px solid transparent" }}>
            <span style={text(13, 18, C.ink56)}>Opus 5.5</span>
          </div>
        </div>
        <div style={{ position: "absolute", right: 12, top: 80, display: "flex", alignItems: "center", gap: 4 }}>
          <div style={{ width: 24, height: 28, position: "relative" }}>
            <div style={{ position: "absolute", left: 0, top: 0 }}>
              <Box>
                <Icon name="mic" size={18} />
              </Box>
            </div>
          </div>
          <Box>
            <Icon name="voice" size={18} />
          </Box>
          <div
            style={{
              width: 54,
              height: 28,
              borderRadius: 9999,
              background: C.send,
              opacity: hasText ? 1 : 0.5,
              display: "flex",
              overflow: "hidden",
              transform: `scale(${1 - sendPress * 0.06})`,
            }}
          >
            <div style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <Icon name="send" size={18} />
            </div>
            <div style={{ width: 1, height: 28, background: "rgba(255,255,255,0.08)" }} />
            <div style={{ display: "flex", alignItems: "center", paddingLeft: 4, paddingRight: 5 }}>
              <Icon name="chevron-down-16" size={16} style={{ filter: "invert(1)", opacity: 0.9 }} />
            </div>
          </div>
        </div>
      </div>

      <div style={{ position: "absolute", left: PICKER.x, top: PICKER.y, height: 16, display: "flex", alignItems: "center", gap: 4, paddingRight: 8 }}>
        {env === "macos" ? <Icon name="apple" size={14} /> : <UbuntuIcon size={14} />}
        <span style={text(12, 16, C.ink56, 400, 0)}>{env === "macos" ? "macOS" : "Ubuntu"}</span>
        <Icon name="chevron-down-14" size={14} />
      </div>

      {menu > 0 ? (
        <div
          style={{
            position: "absolute",
            left: MENU.x,
            top: MENU.y,
            width: MENU.w,
            padding: 4,
            boxSizing: "border-box",
            background: "rgba(255,255,255,0.94)",
            border: `0.8px solid ${C.line08}`,
            borderRadius: 10,
            boxShadow: "0px 10px 15px -3px rgba(0,0,0,0.06), 0px 4px 6px -4px rgba(0,0,0,0.04)",
            opacity: menu,
            transformOrigin: "20px 0px",
            transform: `translateY(${(1 - menu) * -4}px) scale(${0.98 + 0.02 * menu})`,
          }}
        >
          <div style={{ height: 26, padding: "5px 8px", boxSizing: "border-box", ...text(12, 16, C.ink56, 500, 0) }}>Hosted</div>
          {(["ubuntu", "macos", "windows"] as const).map((k, i) => (
            <div
              key={k}
              style={{
                height: 30,
                display: "flex",
                alignItems: "center",
                gap: 8,
                padding: "6px 8px",
                boxSizing: "border-box",
                borderRadius: 6,
                background: hover === i ? C.fill06 : "transparent",
              }}
            >
              {k === "ubuntu" ? <UbuntuIcon size={16} /> : k === "macos" ? <Icon name="apple" size={16} /> : <WindowsIcon size={16} />}
              <span style={text(13, 18)}>{k === "ubuntu" ? "Ubuntu" : k === "macos" ? "macOS" : "Windows"}</span>
              {k !== "windows" ? <StarIcon size={14} filled={k === "ubuntu"} /> : null}
              <div style={{ flex: 1 }} />
              {k === env ? <CheckIcon size={16} /> : null}
            </div>
          ))}
        </div>
      ) : null}
    </>
  );
};
