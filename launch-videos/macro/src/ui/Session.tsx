import React from "react";
import { C, H, W, text } from "../theme";
import { Btn, DevinMark, Icon, ProgressIcon } from "./Icon";

export const LEFT_W = 589;
export const DESK = { x: LEFT_W + 0.8 + 7.5, y: 108, w: 596, h: 447 };

export const SESSION = {
  worked: { x: 24, y: 176 },
  status: { x: 24, y: 350 },
};

const Chevron: React.FC<{ dir: "down" | "right"; s?: number }> = ({ dir, s = 16 }) => (
  <Icon n="chev_ba2e5" s={s} style={{ opacity: 0.56, transform: dir === "down" ? "rotate(90deg)" : undefined }} />
);

const Cmd: React.FC<{ children: React.ReactNode; t?: string }> = ({ children, t }) => (
  <div style={{ display: "flex", gap: 16, paddingBottom: 8, alignItems: "flex-start" }}>
    <div style={{ ...text(13, 18, C.grey), whiteSpace: "normal", flex: 1 }}>{children}</div>
    {t ? <div style={{ ...text(13, 18, C.faint), width: 22, textAlign: "right" }}>{t}</div> : null}
  </div>
);

const Thought: React.FC<{ s: number }> = ({ s }) => (
  <div style={{ display: "flex", gap: 4, alignItems: "center", paddingBottom: 8 }}>
    <span style={text(13, 18, C.grey)}>Thought for {s}s</span>
    <Chevron dir="right" s={12} />
  </div>
);

export type SessionProps = {
  workSec: number;
  done: boolean;
  phase: number;
  screen: React.ReactNode;
};

export const Session: React.FC<SessionProps> = ({ workSec, done, phase, screen }) => (
  <div style={{ position: "absolute", left: 0, top: 0, width: W, height: H, background: C.bg, overflow: "hidden" }}>
    <div style={{ position: "absolute", left: 0, top: 0, width: LEFT_W, height: H }}>
      <div style={{ height: 44, position: "relative" }}>
        <Btn radius={6} style={{ position: "absolute", left: 10, top: 8 }}>
          <Icon n="sidebar_74b9c" s={18} />
        </Btn>
        <div style={{ position: "absolute", left: 52, top: 9, height: 26, display: "flex", alignItems: "center" }}>
          <div style={{ padding: "4px 6px", borderRadius: 6 }}>
            <span style={text(13, 18)}>Create Otter Flappy Bird iOS App</span>
          </div>
          <div style={{ background: C.blueBg, height: 20, padding: "2px 6px", boxSizing: "border-box", borderRadius: 4, display: "flex", gap: 4, alignItems: "center" }}>
            <Icon n="hdr_6188d" s={14} />
            <span style={text(12, 16, C.blue, 500, -0.065)}>macOS</span>
          </div>
        </div>
        <div style={{ position: "absolute", right: 7, top: 8, display: "flex", gap: 1 }}>
          <Btn radius={6}>
            <Icon n="hdr_be3ff" s={18} />
          </Btn>
          <Btn radius={6}>
            <Icon n="hdr_3a1cc" s={18} />
          </Btn>
          <Btn radius={6}>
            <Icon n="hdr_8e71e" s={16} />
          </Btn>
        </div>
      </div>

      <div style={{ position: "absolute", left: 24, right: 24, top: 60 }}>
        <div style={{ display: "flex", justifyContent: "flex-end" }}>
          <div style={{ maxWidth: 445, background: "rgba(0,0,0,0.04)", padding: "8px 14px", borderRadius: "16px 4px 16px 16px" }}>
            <div style={{ ...text(14, 20), whiteSpace: "normal" }}>Build Flappy Bird with an Otter. Then build and test it on iOS.</div>
          </div>
        </div>
        <div style={{ ...text(14, 20), whiteSpace: "normal", marginTop: 24 }}>
          On it — building an otter Flappy Bird iOS game (likely in dabit3/experiments), then building and testing it on the iOS simulator.
        </div>
        <div style={{ display: "flex", gap: 8, alignItems: "flex-start", marginTop: 16, height: 18 }}>
          <div style={{ width: 16, height: 18, display: "flex", alignItems: "center" }}>
            <Chevron dir={done ? "right" : "down"} />
          </div>
          <span style={{ ...text(13, 18, C.grey), fontVariantNumeric: "tabular-nums" }}>
            {done ? "Worked" : "Working"} for {workSec}s
          </span>
        </div>
        <div style={{ ...text(14, 20), whiteSpace: "normal", marginTop: 16 }}>
          Scaffolding a SpriteKit project and booting the iPhone 17 simulator.
        </div>
        <div style={{ marginTop: 12, marginLeft: 7.5, paddingLeft: 23.5, borderLeft: `0.8px solid ${C.line}` }}>
          <Cmd t="12s">xcodegen generate && xcodebuild -scheme OtterFlap -destination 'platform=iOS Simulator,name=iPhone 17' build</Cmd>
          <Thought s={6} />
          <Cmd t="3s">xcrun simctl boot "iPhone 17" && open -a Simulator</Cmd>
        </div>
        <div style={{ display: "flex", gap: 6, alignItems: "flex-start", paddingTop: 12 }}>
          <DevinMark phase={phase} />
          <span style={text(13, 18, C.grey)}>Preparing iOS build tools</span>
        </div>
      </div>

      <div style={{ position: "absolute", left: 8, right: 8, bottom: 8, padding: "0 6px" }}>
        <div style={{ background: "#fff", border: `0.8px solid ${C.border}`, borderRadius: 20, height: 107.6, boxSizing: "border-box", padding: 12, position: "relative", display: "flex", flexDirection: "column" }}>
          <div style={{ flex: 1, padding: 4 }}>
            <div style={{ height: 20, display: "flex", alignItems: "center" }}>
              <span style={{ ...text(14, 20, C.grey), whiteSpace: "pre" }}>Guide Devin while it works, or press </span>
              <div style={{ display: "flex", gap: 2 }}>
                {["in_0ca65", "in_5ba73"].map((k) => (
                  <div key={k} style={{ width: 16, height: 16, borderRadius: 2, background: "rgba(0,0,0,0.06)", display: "flex", alignItems: "center", justifyContent: "center" }}>
                    <Icon n={k} s={12} />
                  </div>
                ))}
              </div>
              <span style={{ ...text(14, 20, C.grey), whiteSpace: "pre" }}> to queue</span>
            </div>
          </div>
          <div style={{ display: "flex", gap: 8, alignItems: "center", minHeight: 28 }}>
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
              <Btn style={{ background: "#1f1f1f" }}>
                <Icon n="in_ad966" s={18} />
              </Btn>
            </div>
          </div>
          <div style={{ position: "absolute", left: 8, top: 62, height: 36, padding: 4, boxSizing: "border-box", display: "flex", gap: 1, alignItems: "center" }}>
            <Btn>
              <Icon n="home_2c01e" s={18} />
            </Btn>
            <Btn>
              <Icon n="home_38518" s={18} />
            </Btn>
            <div style={{ height: 28, padding: "0 6px", display: "flex", alignItems: "center" }}>
              <span style={text(13, 18, C.grey)}>Opus 5.5 (Preview)</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div style={{ position: "absolute", left: LEFT_W, top: 0, width: W - LEFT_W, height: H, borderLeft: `0.8px solid ${C.line}`, boxSizing: "border-box" }}>
      <div style={{ height: 44, padding: 8, boxSizing: "border-box", display: "flex", alignItems: "center", gap: 4 }}>
        <div style={{ height: 28, padding: "3px 6px 3px 3px", boxSizing: "border-box", borderRadius: 6, display: "flex", alignItems: "center", gap: 2 }}>
          <div style={{ width: 22, height: 22, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <ProgressIcon />
          </div>
          <span style={text(13, 18, C.grey)}>Progress</span>
        </div>
        <div style={{ height: 28, padding: "3px 6px 3px 3px", boxSizing: "border-box", borderRadius: 6, background: "rgba(0,0,0,0.06)", display: "flex", alignItems: "center", gap: 2 }}>
          <div style={{ width: 22, height: 22, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <Icon n="tab_e686f" s={16} />
          </div>
          <span style={text(13, 18)}>Computer</span>
        </div>
        <Btn radius={6}>
          <Icon n="home_2c01e" s={18} />
        </Btn>
        <div style={{ flex: 1 }} />
        <Btn radius={6}>
          <Icon n="tab_88457" s={18} />
        </Btn>
        <Btn radius={6}>
          <Icon n="tab_c8a98" s={18} />
        </Btn>
      </div>
      <div style={{ position: "absolute", left: DESK.x - LEFT_W, top: DESK.y, width: DESK.w, height: DESK.h, overflow: "hidden", background: "#000" }}>{screen}</div>
      <div style={{ position: "absolute", left: 8, right: 8, top: 614, padding: "4px 4px" }}>
        <div style={{ height: 10, borderRadius: 4, background: "rgba(49,124,255,0.22)", position: "relative" }}>
          <div style={{ position: "absolute", right: 0, top: 0, width: 2, height: 10, background: "#317cff", borderRadius: 1 }} />
        </div>
      </div>
      <div style={{ position: "absolute", left: 8, right: 8, top: 636, height: 30, display: "flex", alignItems: "center", gap: 4 }}>
        <Btn radius={6}>
          <Icon n="bar_f2c32" s={18} />
        </Btn>
        <Btn radius={6}>
          <Icon n="bar_a75fe" s={18} />
        </Btn>
        <div style={{ height: 26, borderRadius: 9999, border: `0.8px solid ${C.border}`, padding: "0 10px 0 9px", display: "flex", alignItems: "center", gap: 6, marginLeft: 4 }}>
          <div style={{ width: 8, height: 8, borderRadius: 9999, background: C.red }} />
          <span style={text(13, 18)}>Live</span>
        </div>
        <div style={{ flex: 1 }} />
        <Btn radius={6}>
          <Icon n="bar_70d39" s={18} />
        </Btn>
        <div style={{ height: 28, padding: "0 6px", display: "flex", alignItems: "center", gap: 4 }}>
          <span style={text(13, 18, C.grey)}>Auto</span>
          <Icon n="home_fc52a" s={14} style={{ opacity: 0.7 }} />
        </div>
        <Btn radius={6}>
          <Icon n="bar_9e415" s={18} />
        </Btn>
      </div>
    </div>
  </div>
);
