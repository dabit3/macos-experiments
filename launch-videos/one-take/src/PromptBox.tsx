import React from "react";
import { C } from "./tokens";
import { sans } from "./fonts";
import { ArrowUp, Chevron, FIcon, Sliders } from "./icons";
import { PROMPT, T, typedCount, typeEnd } from "./timeline";
import { Rect, fadeIn, mix, prog } from "./anim";

export const HOME_FONT = 15;

export const PromptBox: React.FC<{ t: number; rect: Rect; p: number }> = ({ t, rect, p }) => {
  const n = typedCount(t);
  const text = PROMPT.slice(0, n);
  const sent = t >= T.toSession ? 1 : fadeIn(t, T.sendClick + 0.06, 0.5) * 0.15;
  const idle = t < T.typeStart - 0.05 || (t > typeEnd + 0.45 && t < T.sendClick);
  const blink = idle ? (Math.cos(((t % 1.06) / 1.06) * Math.PI * 2) > -0.2 ? 1 : 0) : 1;
  const caretOn = t < T.sendClick + 0.05 ? blink : 0;
  const hasText = n > 0 && t < T.sendClick + 0.1;
  const press = 1 - 0.06 * Math.sin(Math.PI * Math.min(1, Math.max(0, (t - T.sendClick + 0.04) / 0.18)));
  const sendW = mix(54, 28, p);
  const sendBg = p > 0.02 ? C.ink2 : hasText ? C.ink2 : "#8F8F8F";
  const sessionIn = prog(t, T.toSession + T.sessionDur * 0.55, 0.4);
  const homeOut = 1 - prog(t, T.toSession, 0.3);
  const fontSize = HOME_FONT;

  return (
    <div
      style={{
        position: "absolute",
        left: rect.x,
        top: rect.y,
        width: rect.w,
        height: rect.h,
        boxSizing: "border-box",
        borderRadius: 20,
        background: C.field,
        boxShadow: "0 0 0 0.8px rgba(0,0,0,0.09), 0 1px 3px rgba(0,0,0,0.025)",
        fontFamily: sans,
        overflow: "hidden",
      }}
    >
      <div style={{ position: "absolute", left: mix(16.6, 16, p), top: mix(15.2, 16.8, p), right: 16, height: 22, fontSize, lineHeight: "22px", letterSpacing: "-0.01em" }}>
        {n === 0 && t < T.sendClick ? (
          <span style={{ position: "absolute", left: 0, top: 0, color: C.muted, whiteSpace: "nowrap" }}>
            Ask Devin to build features, fix bugs, or work on your code
          </span>
        ) : null}
        <span style={{ position: "absolute", left: 0, top: 0, color: C.ink, whiteSpace: "nowrap", opacity: 1 - sent }}>
          {text}
          <span
            style={{
              display: "inline-block",
              width: 1.2,
              height: 17,
              marginLeft: 0.6,
              verticalAlign: "-3px",
              background: C.ink,
              opacity: caretOn,
            }}
          />
        </span>
        <span
          style={{
            position: "absolute",
            left: 0,
            top: -0.8,
            fontSize: 14,
            color: C.muted,
            whiteSpace: "nowrap",
            opacity: sessionIn,
            display: "flex",
            alignItems: "center",
            letterSpacing: "-0.07px",
          }}
        >
          <span style={{ width: 0, height: 17, borderLeft: "1.2px solid #191919", marginRight: 0, opacity: 0 }} />
          Guide Devin while it works, or press&nbsp;
          <span style={{ display: "inline-flex", gap: 2, margin: "0 4px 0 0" }}>
            {["input_0ca65", "input_5ba73"].map((k) => (
              <span key={k} style={{ width: 16, height: 16, borderRadius: 2, background: C.fillStrong, display: "flex", alignItems: "center", justifyContent: "center" }}>
                <FIcon name={k} size={12} />
              </span>
            ))}
          </span>
          to queue
        </span>
      </div>

      <div style={{ position: "absolute", left: 12, right: 12.8, bottom: 12, height: 28, display: "flex", alignItems: "center" }}>
        <div style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <FIcon name="input_2c01e" size={18} />
        </div>
        <div style={{ width: 28, height: 28, marginLeft: 1, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <FIcon name="input_38518" size={18} />
        </div>
        <div style={{ width: mix(28, 0, p), overflow: "hidden", opacity: homeOut, marginLeft: 1, position: "relative", height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Sliders size={18} />
          <div style={{ position: "absolute", left: 18.5, top: 4, width: 6, height: 6, borderRadius: 3, background: C.blue }} />
        </div>
        <div style={{ position: "relative", marginLeft: 6, height: 18, fontSize: 13, lineHeight: "18px", color: C.muted, letterSpacing: "-0.065px", whiteSpace: "nowrap" }}>
          <span style={{ opacity: 1 - sessionIn }}>Opus 5.5</span>
          <span style={{ position: "absolute", left: 0, top: 0, opacity: sessionIn }}>Opus 5.5 (Preview)</span>
        </div>
        <div style={{ flex: 1 }} />
        <div style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <FIcon name="input_11456" size={18} />
        </div>
        <div style={{ width: 28, height: 28, marginLeft: 0, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <FIcon name="input_70d60" size={18} />
        </div>
        <div
          style={{
            marginLeft: 4,
            width: sendW,
            height: 28,
            borderRadius: 999,
            background: sendBg,
            display: "flex",
            alignItems: "center",
            overflow: "hidden",
            transform: `scale(${press})`,
            position: "relative",
          }}
        >
          <div style={{ position: "absolute", left: 5, top: 5, opacity: 1 - p }}>
            <ArrowUp size={18} color="#FFFFFF" stroke={1.5} />
          </div>
          <div style={{ position: "absolute", left: 27, top: 5, bottom: 5, width: 0.8, background: "rgba(255,255,255,0.22)", opacity: 1 - p }} />
          <div style={{ position: "absolute", left: 32.5, top: 6, opacity: 1 - p }}>
            <Chevron size={16} color="rgba(255,255,255,0.85)" stroke={1.5} />
          </div>
          <div style={{ position: "absolute", left: 5, top: 5, opacity: p }}>
            <FIcon name="input_ad966" size={18} />
          </div>
        </div>
      </div>
    </div>
  );
};
