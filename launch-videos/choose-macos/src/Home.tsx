import React from "react";
import { C, FONT, T, VH, VW } from "./theme";
import { CheckIcon, Icon, IconBox, SidebarIcon, StarIcon, UbuntuIcon, WindowsIcon } from "./Icon";

export const PROMPT = { w: 688, h: 121.6, x: (VW - 688) / 2, y: VH / 2 - 121.6 / 2 };
export const CHIP = { x: PROMPT.x + 10.5, y: PROMPT.y + PROMPT.h + 23, h: 16 };
export const MENU = { x: PROMPT.x + 9.5, y: PROMPT.y + PROMPT.h + 42, w: 221, rowH: 30 };
/** Centers (app px) of interactive targets, used for cursor choreography. */
export const TARGETS = {
  chip: { x: CHIP.x + 34, y: CHIP.y + 8 },
  macRow: { x: MENU.x + 64, y: MENU.y + 80 },
  send: { x: PROMPT.x + PROMPT.w - 12 - 40, y: PROMPT.y + PROMPT.h - 26 },
};

export type Env = "ubuntu" | "macos";

export type HomeProps = {
  text: string;
  caret: boolean;
  sendActive: number;
  sendPress: number;
  menu: number;
  hoverRow: number;
  env: Env;
  chipPress: number;
  chipOpacity: number;
};

const EnvGlyph: React.FC<{ env: Env; size: number }> = ({ env, size }) =>
  env === "ubuntu" ? <UbuntuIcon size={size} /> : <Icon name="apple" size={size} style={{ filter: "brightness(0)", opacity: 0.9 }} />;

export const NewBadge: React.FC = () => (
  <div
    style={{
      height: 18,
      padding: "0 6px",
      borderRadius: 9999,
      background: C.badgeBg,
      color: C.badgeText,
      fontSize: 11,
      lineHeight: "18px",
      fontWeight: 500,
      letterSpacing: 0.05,
    }}
  >
    New
  </div>
);

export const EnvChip: React.FC<{ env: Env; press?: number }> = ({ env, press = 0 }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 4, height: 16, paddingRight: 8, transform: `scale(${1 - press * 0.04})`, transformOrigin: "left center" }}>
    <EnvGlyph env={env} size={14} />
    <div style={{ ...T.t12, color: C.text, fontFamily: FONT }}>{env === "ubuntu" ? "Ubuntu" : "macOS"}</div>
    <Icon name="chevron-14" size={14} />
  </div>
);

const MenuRow: React.FC<{ icon: React.ReactNode; label: string; extra?: React.ReactNode; checked: boolean; hover: number }> = ({
  icon,
  label,
  extra,
  checked,
  hover,
}) => (
  <div style={{ position: "relative", height: 30, display: "flex", alignItems: "center", padding: "0 0 0 14px" }}>
    <div style={{ position: "absolute", left: 4, right: 4, top: 0.5, bottom: 0.5, borderRadius: 6, background: C.fill06, opacity: hover }} />
    <div style={{ position: "relative", display: "flex", alignItems: "center", gap: 8, flex: 1 }}>
      <div style={{ width: 16, display: "flex", justifyContent: "center" }}>{icon}</div>
      <div style={{ ...T.t13, color: C.text }}>{label}</div>
      {extra}
    </div>
    <div style={{ position: "relative", width: 14, marginRight: 14 }}>{checked ? <CheckIcon size={14} /> : null}</div>
  </div>
);

export const EnvMenu: React.FC<{ open: number; hoverRow: number; env: Env }> = ({ open, hoverRow, env }) => (
  <div
    style={{
      position: "absolute",
      left: MENU.x,
      top: MENU.y,
      width: MENU.w,
      padding: "4px 0",
      background: "#fff",
      border: `0.8px solid ${C.border08}`,
      borderRadius: 10,
      boxShadow: "0 4px 16px rgba(0,0,0,0.06), 0 1px 3px rgba(0,0,0,0.04)",
      opacity: open,
      transform: `translateY(${(1 - open) * -4}px) scale(${0.97 + open * 0.03})`,
      transformOrigin: "top left",
    }}
  >
    <div style={{ ...T.t12, color: C.text56, padding: "5px 16px 3px", height: 24, boxSizing: "border-box" }}>Hosted</div>
    <MenuRow icon={<UbuntuIcon size={16} />} label="Ubuntu" extra={<StarIcon size={14} filled />} checked={env === "ubuntu"} hover={hoverRow === 0 ? 1 : 0} />
    <MenuRow
      icon={<Icon name="apple" size={16} style={{ filter: "brightness(0)", opacity: 0.92 }} />}
      label="macOS"
      extra={
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <StarIcon size={14} />
          <NewBadge />
        </div>
      }
      checked={env === "macos"}
      hover={hoverRow >= 1 ? hoverRow : 0}
    />
    <MenuRow icon={<WindowsIcon size={15} />} label="Windows" checked={false} hover={0} />
  </div>
);

const Toggle: React.FC = () => (
  <div style={{ display: "flex", alignItems: "center", height: 28, padding: 1, borderRadius: 9999, background: C.fill04, fontFamily: FONT }}>
    <div
      style={{
        ...T.t13,
        height: 26,
        width: 60.6,
        boxSizing: "border-box",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        borderRadius: 9999,
        background: "#fff",
        border: `0.8px solid ${C.border08}`,
        boxShadow: "0 1px 2px rgba(0,0,0,0.04)",
        color: C.text,
      }}
    >
      Agent
    </div>
    <div style={{ ...T.t13, width: 48.6, textAlign: "center", color: C.text56 }}>Ask</div>
  </div>
);

const Caret: React.FC = () => (
  <span style={{ display: "inline-block", width: 1.2, height: 17, marginRight: -1.2, marginLeft: 0.5, background: C.text, verticalAlign: "-3px" }} />
);

export const Home: React.FC<HomeProps> = ({ text, caret, sendActive, sendPress, menu, hoverRow, env, chipPress, chipOpacity }) => (
  <div style={{ position: "absolute", inset: 0, fontFamily: FONT, color: C.text }}>
    <div style={{ position: "absolute", left: 16, top: 13 }}>
      <SidebarIcon size={18} />
    </div>
    {/* Logo + Agent/Ask */}
    <div
      style={{
        position: "absolute",
        left: PROMPT.x + 9.5,
        width: PROMPT.w - 15.5,
        top: PROMPT.y - 44,
        height: 28,
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 8.5 }}>
        <Icon name="devin-mark" size={0} w={19.36} h={22} />
        <Icon name="devin-wordmark" size={0} w={55.09} h={16.75} />
      </div>
      <Toggle />
    </div>
    {/* Prompt box */}
    <div
      style={{
        position: "absolute",
        left: PROMPT.x,
        top: PROMPT.y,
        width: PROMPT.w,
        height: PROMPT.h,
        boxSizing: "border-box",
        background: "#fff",
        border: `0.8px solid ${C.border08}`,
        borderRadius: 20,
        padding: 12,
      }}
    >
      <div style={{ padding: 4, height: 54, boxSizing: "border-box" }}>
        <div style={{ ...T.t14, color: text ? C.text : C.text56, whiteSpace: "nowrap" }}>
          {caret && !text ? <Caret /> : null}
          {text || "Ask Devin to build features, fix bugs, or work on your code"}
          {caret && text ? <Caret /> : null}
        </div>
      </div>
      <div style={{ position: "absolute", left: 12, right: 12, bottom: 12, height: 28, display: "flex", alignItems: "center" }}>
        <IconBox icon="plus" iconSize={18} />
        <div style={{ width: 1 }} />
        <IconBox icon="slash" iconSize={18} />
        <div style={{ width: 1 }} />
        <div style={{ position: "relative" }}>
          <IconBox icon="settings" iconSize={18} />
          <div style={{ position: "absolute", left: 18.5, top: 3, width: 6, height: 6, borderRadius: 9999, background: "#2b7fff" }} />
        </div>
        <div style={{ ...T.t13, color: C.text56, marginLeft: 12.5 }}>Fusion</div>
        <div style={{ flex: 1 }} />
        <IconBox icon="mic" iconSize={18} />
        <IconBox icon="voice" iconSize={18} />
        <div style={{ width: 4 }} />
        <div
          style={{
            width: 54,
            height: 28,
            borderRadius: 9999,
            background: C.dark,
            opacity: 0.5 + 0.5 * sendActive,
            display: "flex",
            alignItems: "center",
            overflow: "hidden",
            transform: `scale(${1 - sendPress * 0.06})`,
          }}
        >
          <div style={{ width: 27, display: "flex", justifyContent: "center", paddingLeft: 2 }}>
            <Icon name="arrow-up" size={18} />
          </div>
          <div style={{ width: 0.8, height: 28, background: "rgba(255,255,255,0.18)" }} />
          <div style={{ flex: 1, display: "flex", justifyContent: "center" }}>
            <Icon name="chevron-16" size={16} />
          </div>
        </div>
      </div>
    </div>
    {/* Environment picker */}
    <div style={{ position: "absolute", left: CHIP.x, top: CHIP.y, opacity: chipOpacity }}>
      <EnvChip env={env} press={chipPress} />
    </div>
    {menu > 0.001 ? <EnvMenu open={menu} hoverRow={hoverRow} env={env} /> : null}
  </div>
);
