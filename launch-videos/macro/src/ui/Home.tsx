import React from "react";
import { C, H, W, text } from "../theme";
import { Btn, Icon, UbuntuIcon, WindowsIcon } from "./Icon";

export const HOME = {
  colX: 250,
  promptTop: 279,
  textX: 256 + 0.8 + 12 + 4,
  textY: 279 + 0.8 + 12 + 4,
  send: { x: 891.2, y: 373.8 },
  env: { x: 266, y: 412.6 },
  menu: { x: 266, y: 438.5, w: 221 },
};

export type Env = "ubuntu" | "macos";

export type HomeProps = {
  typed: string;
  caret: boolean;
  env: Env;
  menu: number;
  hover: Env | null;
  press: number;
};


export const NewBadge: React.FC = () => (
  <div style={{ background: C.blueBg, borderRadius: 4, height: 16, padding: "0 5px", display: "flex", alignItems: "center" }}>
    <span style={{ ...text(11, 16, C.blue, 500, 0) }}>New</span>
  </div>
);

const MenuRow: React.FC<{ icon: React.ReactNode; label: string; hover: boolean; star?: boolean; check?: boolean; badge?: boolean }> = ({ icon, label, hover, star, check, badge }) => (
  <div style={{ height: 30, borderRadius: 6, background: hover ? "rgba(0,0,0,0.05)" : "transparent", display: "flex", alignItems: "center", padding: "0 10px", gap: 8 }}>
    {icon}
    <span style={text(13, 18)}>{label}</span>
    {star ? (
      <svg width={13} height={13} viewBox="0 0 24 24" style={{ display: "block" }}>
        <path d="M12 2.8l2.83 5.73 6.33.92-4.58 4.46 1.08 6.3L12 17.24l-5.66 2.97 1.08-6.3L2.84 9.45l6.33-.92z" fill="#191919" />
      </svg>
    ) : null}
    {badge ? <NewBadge /> : null}
    <div style={{ flex: 1 }} />
    {check ? (
      <svg width={14} height={14} viewBox="0 0 14 14" style={{ display: "block" }}>
        <path d="M2.8 7.3 5.6 10.1 11.2 4.2" fill="none" stroke={C.grey} strokeWidth={1.1} strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    ) : null}
  </div>
);

export const Home: React.FC<HomeProps> = ({ typed, caret, env, menu, hover, press }) => {
  const has = typed.length > 0;
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: W, height: H, background: C.bg, overflow: "hidden" }}>
      <Btn radius={6} style={{ position: "absolute", left: 10, top: 8 }}>
        <Icon n="sidebar_74b9c" s={18} />
      </Btn>
      <div style={{ position: "absolute", left: HOME.colX, top: HOME.promptTop - 44, width: 700, height: 28, padding: "0 12px 0 16px", boxSizing: "border-box", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <div style={{ width: 82.819, height: 22, position: "relative" }}>
          <Icon n="home_fb89d" s={19.358} h={22} style={{ position: "absolute", left: 0, top: 0 }} />
          <Icon n="home_1e515" s={55.09} h={16.754} style={{ position: "absolute", left: 82.819 * 0.3337, top: 22 * 0.1241 }} />
        </div>
        <div style={{ background: "rgba(0,0,0,0.04)", borderRadius: 20, display: "flex", gap: 1, alignItems: "center" }}>
          <div style={{ background: "#fff", border: "0.8px solid rgba(0,0,0,0.06)", boxShadow: "0 1px 1px rgba(0,0,0,0.05)", borderRadius: 9999, padding: "4px 12px" }}>
            <span style={text(13, 18)}>Agent</span>
          </div>
          <div style={{ border: "0.8px solid transparent", borderRadius: 9999, padding: "4px 12px" }}>
            <span style={text(13, 18, C.grey)}>Ask</span>
          </div>
        </div>
      </div>

      <div style={{ position: "absolute", left: HOME.colX + 6, top: HOME.promptTop, width: 688, height: 121.6, boxSizing: "border-box", background: "#fff", border: `0.8px solid ${C.border}`, borderRadius: 20, padding: 12, display: "flex", flexDirection: "column" }}>
        <div style={{ flex: 1, padding: 4, position: "relative" }}>
          <div style={{ position: "relative", height: 20, display: "flex", alignItems: "center" }}>
            {has ? <span style={text(14, 20)}>{typed}</span> : null}
            <span style={{ display: "inline-block", width: 1, height: 17, background: C.ink, opacity: caret ? 1 : 0, marginLeft: has ? 0.5 : 0, transform: "translateY(0.5px)" }} />
            {!has ? <span style={{ ...text(14, 20, C.grey), position: "absolute", left: 0, top: 0 }}>Ask Devin to build features, fix bugs, or work on your code</span> : null}
          </div>
        </div>
        <div style={{ display: "flex", gap: 8, alignItems: "center", height: 28 }}>
          <div style={{ flex: 1 }} />
          <div style={{ display: "flex", gap: 4, alignItems: "center" }}>
            <div style={{ width: 24, height: 28, position: "relative" }}>
              <Btn style={{ position: "absolute", left: 0, top: 0 }}>
                <Icon n="home_11456" s={18} />
              </Btn>
            </div>
            <Btn>
              <Icon n="home_70d60" s={18} />
            </Btn>
            <div style={{ background: press > 0 ? `rgb(${31 - 31 * press * 0.6},${31 - 31 * press * 0.6},${31 - 31 * press * 0.6})` : "#1f1f1f", opacity: has ? 1 : 0.5, width: 54, height: 28, borderRadius: 9999, display: "flex", overflow: "hidden" }}>
              <div style={{ width: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
                <Icon n="home_bc3a8" s={18} style={{ transform: `translateY(${press * 1.2}px) scale(${1 - press * 0.12})` }} />
              </div>
              <div style={{ width: 1, background: "rgba(255,255,255,0.08)" }} />
              <div style={{ width: 25, display: "flex", alignItems: "center", justifyContent: "center", paddingRight: 1 }}>
                <Icon n="home_f856e" s={16} />
              </div>
            </div>
          </div>
        </div>
        <div style={{ position: "absolute", left: 8, top: 76, height: 36, padding: 4, boxSizing: "border-box", display: "flex", gap: 1, alignItems: "center" }}>
          <Btn>
            <Icon n="home_2c01e" s={18} />
          </Btn>
          <Btn>
            <Icon n="home_38518" s={18} />
          </Btn>
          <Btn style={{ position: "relative" }}>
            <Icon n="home_cd006" s={18} />
            <div style={{ position: "absolute", left: 19, top: 3, width: 6, height: 6, borderRadius: 9999, background: "#317cff" }} />
          </Btn>
          <div style={{ height: 28, padding: "0 10px", display: "flex", alignItems: "center", border: "0.8px solid transparent" }}>
            <span style={text(13, 18, C.grey)}>Opus 5.5 (Preview)</span>
          </div>
        </div>
      </div>

      <div style={{ position: "absolute", left: HOME.env.x, top: HOME.env.y, height: 16, display: "flex", alignItems: "center", gap: 4, paddingRight: 8 }}>
        {env === "macos" ? <Icon n="home_32f69" s={14} /> : <UbuntuIcon />}
        <span style={text(12, 16, C.grey, 400, 0)}>{env === "macos" ? "macOS" : "Ubuntu"}</span>
        <Icon n="home_fc52a" s={14} />
      </div>

      {menu > 0 ? (
        <div
          style={{
            position: "absolute",
            left: HOME.menu.x,
            top: HOME.menu.y,
            width: HOME.menu.w,
            boxSizing: "border-box",
            background: "#fff",
            border: `0.8px solid ${C.border}`,
            borderRadius: 10,
            boxShadow: "0 4px 12px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04)",
            padding: 4,
            opacity: menu,
            transform: `translateY(${(1 - menu) * -3}px) scale(${0.98 + 0.02 * menu})`,
            transformOrigin: "top left",
          }}
        >
          <div style={{ height: 28, padding: "0 10px", display: "flex", alignItems: "center" }}>
            <span style={text(12, 16, C.grey, 400, 0)}>Hosted</span>
          </div>
          <MenuRow icon={<UbuntuIcon />} label="Ubuntu" star hover={hover === "ubuntu"} check={env === "ubuntu"} />
          <MenuRow icon={<Icon n="home_32f69" s={14} style={{ opacity: 0.75 }} />} label="macOS" badge hover={hover === "macos"} check={env === "macos"} />
          <MenuRow icon={<WindowsIcon />} label="Windows" hover={false} />
        </div>
      ) : null}
    </div>
  );
};
