import { Img, staticFile } from "remotion";
import { ramp, easeOutCubic } from "../ease";
import { T } from "../timeline";
import { ComposerBox, ComposerToolbar, DevinMark } from "./Composer";
import { Icon } from "./Icon";
import { Apple, Check, ChevronDown, Star, Ubuntu, Windows } from "./glyphs";
import { C, inter, t13, t14, UI_W } from "./tokens";
import { PROMPT, typedLength } from "./typing";

export const HOME = {
  colLeft: (UI_W - 688) / 2,
  boxTop: 284.4,
  boxH: 121,
  pickerY: 430.1,
};

const MenuRow: React.FC<{ icon: React.ReactNode; label: string; highlighted?: boolean; checked?: boolean; starred?: boolean; star?: boolean; badge?: boolean }> = ({
  icon,
  label,
  highlighted,
  checked,
  star,
  starred,
  badge,
}) => (
  <div
    style={{
      height: 21.7,
      margin: "0 3.2px",
      borderRadius: 5,
      background: highlighted ? C.active : "transparent",
      display: "flex",
      alignItems: "center",
      padding: "0 6px",
      gap: 6,
    }}
  >
    <div style={{ width: 14, display: "flex", justifyContent: "center" }}>{icon}</div>
    <div style={{ ...t13, color: C.text }}>{label}</div>
    {badge && (
      <div style={{ fontFamily: inter, fontSize: 10.5, lineHeight: "15px", fontWeight: 500, color: C.blue, background: C.blueTint, borderRadius: 4, padding: "0 5px" }}>New</div>
    )}
    {star && <Star size={12} color={starred ? "rgba(25,25,25,0.72)" : C.faint} />}
    <div style={{ flex: 1 }} />
    {checked && <Check size={13} color={C.text} />}
  </div>
);

export const Home: React.FC<{ frame: number }> = ({ frame }) => {
  const L = HOME.colLeft;
  const n = typedLength(frame);
  const typed = PROMPT.slice(0, n);
  const macos = frame >= T.envPick;
  const menuIn = ramp(frame, T.envOpen, T.envOpen + 9, easeOutCubic);
  const menuOut = ramp(frame, T.envPick + 4, T.envPick + 14, easeOutCubic);
  const menuOpacity = menuIn * (1 - menuOut);
  const hoverMac = frame >= T.envPick - 22;
  const caretOn = n > 0 && frame < T.send && Math.floor(frame / 32) % 2 === 0;
  const press = ramp(frame, T.send - 4, T.send, easeOutCubic) * (1 - ramp(frame, T.send, T.send + 8, easeOutCubic));

  return (
    <div style={{ position: "absolute", inset: 0, background: C.page }}>
      <div style={{ position: "absolute", left: 12, top: 8, width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
        <Icon name="sidebar" size={18} />
      </div>

      <DevinMark height={22.66} style={{ position: "absolute", left: L + 9.6, top: 243.1 }} />
      <Img src={staticFile("brand/wordmark.png")} style={{ position: "absolute", left: L + 37.7, top: 246.1, height: 16.9 }} />

      <div
        style={{
          position: "absolute",
          left: L + 570.8,
          top: 240.3,
          width: 113.6,
          height: 27,
          borderRadius: 9999,
          background: "rgba(0,0,0,0.05)",
          display: "flex",
          alignItems: "center",
          padding: 2,
          boxSizing: "border-box",
        }}
      >
        <div
          style={{
            width: 56.3,
            height: 23,
            borderRadius: 9999,
            background: C.surface,
            boxShadow: "0 0 0 0.8px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.04)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            ...t13,
            color: C.text,
          }}
        >
          Agent
        </div>
        <div style={{ flex: 1, textAlign: "center", ...t13, color: C.muted }}>Ask</div>
      </div>

      <div style={{ position: "absolute", left: L, top: HOME.boxTop }}>
        <ComposerBox width={688} height={HOME.boxH} toolbar={<ComposerToolbar model="Opus 5.5" sendActive={n > 0} pressSend={press} />}>
          {n === 0 ? (
            <span style={{ color: C.muted }}>Ask Devin to build features, fix bugs, or work on your code</span>
          ) : (
            <span style={{ ...t14, color: C.text, whiteSpace: "pre-wrap" }}>
              {typed}
              <span style={{ display: "inline-block", width: 1, height: 17, marginLeft: 1, verticalAlign: -3, background: caretOn ? C.text : "transparent" }} />
            </span>
          )}
        </ComposerBox>
      </div>

      <div style={{ position: "absolute", left: L + 6, top: HOME.pickerY - 10, height: 20, display: "flex", alignItems: "center", gap: 6, padding: "0 5px", borderRadius: 6 }}>
        {macos ? <Apple size={13} color="rgba(25,25,25,0.6)" /> : <Ubuntu size={14} />}
        <div style={{ ...t13, color: "rgba(25,25,25,0.72)" }}>{macos ? "macOS" : "Ubuntu"}</div>
        <ChevronDown size={14} style={{ marginLeft: -2 }} />
      </div>

      {menuOpacity > 0.001 && (
        <div
          style={{
            position: "absolute",
            left: L + 3.2,
            top: HOME.pickerY + 7.4,
            width: 160,
            paddingBottom: 3.5,
            background: C.surface,
            borderRadius: 8,
            boxShadow: "0 0 0 0.8px rgba(0,0,0,0.08), 0 4px 14px rgba(0,0,0,0.07)",
            opacity: menuOpacity,
            transform: `translateY(${(1 - menuIn) * -3}px) scale(${0.98 + 0.02 * menuIn})`,
            transformOrigin: "top left",
          }}
        >
          <div style={{ ...t13, fontSize: 12, color: C.muted, height: 24, display: "flex", alignItems: "center", padding: "2px 9px 0" }}>Hosted</div>
          <MenuRow icon={<Ubuntu size={14} />} label="Ubuntu" star starred checked={!macos} highlighted={!hoverMac && !macos} />
          <MenuRow icon={<Apple size={14} />} label="macOS" badge star={hoverMac} checked={macos} highlighted={hoverMac} />
          <MenuRow icon={<Windows size={13} />} label="Windows" />
        </div>
      )}
    </div>
  );
};
