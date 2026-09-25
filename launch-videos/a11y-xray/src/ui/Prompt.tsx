import { Img, staticFile } from "remotion";
import { IconApple, IconArrowUp, IconCheck, IconChevronDown, IconMic, IconPlus, IconSidebar, IconSlash, IconSliders, IconUbuntu, IconWave, IconWindows } from "../icons";
import { c, font } from "../theme";

export const PROMPT_TEXT = "Build Flappy Bird with an Otter. Then build and test it on iOS.";
export const BOX = { x: 282, y: 298, w: 716, h: 125 };
export const ENV = { x: BOX.x + 10, y: 437, w: 110, h: 22 };
export const MENU = { x: BOX.x + 9, y: 459, w: 231 };
export const SEND = { x: BOX.x + BOX.w - 13 - 56, y: BOX.y + 83, w: 56, h: 29 };

const Toggle = () => (
  <div style={{ position: "absolute", left: BOX.x + BOX.w - 124, top: 251, height: 29, width: 116, borderRadius: 999, background: c.fill, fontFamily: font.sans, fontSize: 15 }}>
    <div style={{ position: "absolute", left: 2, top: 2, height: 25, width: 62, borderRadius: 999, background: c.surface, boxShadow: "0 0 0 0.7px #DADADA", display: "flex", alignItems: "center", justifyContent: "center", color: c.text }}>Agent</div>
    <div style={{ position: "absolute", left: 72, top: 0, height: 29, display: "flex", alignItems: "center", color: "#666" }}>Ask</div>
  </div>
);

export const PromptScreen = ({ typed, caret, env, menuOpen, hover, sendDown }: { typed: string; caret: boolean; env: "ubuntu" | "macos"; menuOpen: number; hover: number; sendDown: number }) => {
  const hasText = typed.length > 0;
  return (
    <div style={{ position: "absolute", inset: 0, background: c.page, fontFamily: font.sans, color: c.text }}>
      <div style={{ position: "absolute", left: 17, top: 14 }}><IconSidebar size={18} color="#505050" /></div>
      <Img src={staticFile("devin-lockup-black.png")} style={{ position: "absolute", left: BOX.x + 9, top: 254, height: 23.2 }} />
      <Toggle />
      <div style={{ position: "absolute", left: BOX.x, top: BOX.y, width: BOX.w, height: BOX.h, borderRadius: 18, background: c.surface, boxShadow: `0 0 0 0.7px ${c.border}, 0 1px 2px rgba(0,0,0,0.02)` }}>
        <div style={{ position: "absolute", left: 17, top: 15, fontSize: 16, lineHeight: "24px", letterSpacing: "-0.1px", color: hasText ? c.text : "#6A6A6A", whiteSpace: "pre" }}>
          {hasText ? typed : "Ask Devin to build features, fix bugs, or work on your code"}
          {caret ? <span style={{ display: "inline-block", width: 1.2, height: 19, background: c.text, verticalAlign: "-3.5px", marginLeft: hasText ? 0.5 : 0 }} /> : null}
        </div>
        <div style={{ position: "absolute", left: 17, top: 88, display: "flex", alignItems: "center", gap: 12 }}>
          <IconPlus size={19} color="#444" />
          <IconSlash size={18} color="#444" />
          <IconSliders size={18} color="#444" />
          <div style={{ marginLeft: 6, fontSize: 15, color: "#454545" }}>Opus 5.5</div>
        </div>
        <div style={{ position: "absolute", right: 110, top: 88 }}><IconMic size={18} color="#444" /></div>
        <div style={{ position: "absolute", right: 81, top: 88 }}><IconWave size={18} color="#444" /></div>
        <div style={{ position: "absolute", left: SEND.x - BOX.x, top: SEND.y - BOX.y, width: SEND.w, height: SEND.h, borderRadius: 999, background: hasText ? "#1A1A1A" : "#8A8A8A", transform: `scale(${1 - 0.06 * sendDown})`, display: "flex" }}>
          <div style={{ width: 29, display: "flex", alignItems: "center", justifyContent: "center" }}><IconArrowUp size={17} color="#FFF" sw={1.7} /></div>
          <div style={{ width: 0.7, background: "rgba(255,255,255,0.22)", margin: "5px 0" }} />
          <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center" }}><IconChevronDown size={15} color="#FFF" sw={1.7} /></div>
        </div>
      </div>
      <div style={{ position: "absolute", left: ENV.x, top: ENV.y, height: ENV.h, display: "flex", alignItems: "center", gap: 6, fontSize: 15, color: "#454545" }}>
        {env === "ubuntu" ? <IconUbuntu size={14} /> : <IconApple size={14} color="#454545" />}
        <span>{env === "ubuntu" ? "Ubuntu" : "macOS"}</span>
        <IconChevronDown size={14} color="#555" />
      </div>
      {menuOpen > 0 ? (
        <div style={{ position: "absolute", left: MENU.x, top: MENU.y, width: MENU.w, opacity: menuOpen, transform: `translateY(${(1 - menuOpen) * -4}px) scale(${0.98 + 0.02 * menuOpen})`, transformOrigin: "20px 0", borderRadius: 11, background: c.surface, boxShadow: "0 0 0 0.7px #E0E0E0, 0 6px 20px rgba(0,0,0,0.07), 0 1px 3px rgba(0,0,0,0.04)", padding: "6px 5px 5px", fontSize: 15 }}>
          <div style={{ padding: "4px 12px 6px", fontSize: 13.5, color: "#6A6A6A" }}>Hosted</div>
          {(["Ubuntu", "macOS", "Windows"] as const).map((name, i) => (
            <div key={name} style={{ height: 31, borderRadius: 7, background: hover === i ? c.fill : "transparent", display: "flex", alignItems: "center", padding: "0 11px", gap: 9 }}>
              {i === 0 ? <IconUbuntu size={16} /> : i === 1 ? <IconApple size={16} color="#1A1A1A" /> : <IconWindows size={15} />}
              <span>{name}</span>
              {i === 1 ? <span style={{ fontSize: 11, fontWeight: 500, color: c.badgeText, background: c.badgeBg, borderRadius: 5, padding: "1.5px 6px", marginLeft: 1 }}>New</span> : null}
              <div style={{ flex: 1 }} />
              {(i === 0 && env === "ubuntu") || (i === 1 && env === "macos") ? <IconCheck size={15} color="#555" /> : null}
            </div>
          ))}
        </div>
      ) : null}
    </div>
  );
};
