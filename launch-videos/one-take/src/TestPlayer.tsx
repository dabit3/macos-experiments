import React from "react";
import { C, WIN } from "./tokens";
import { mono, sans } from "./fonts";
import { FIcon } from "./icons";
import { T, TESTS } from "./timeline";
import { clamp01, easeInOut, easeOut, mix, prog } from "./anim";

export const VIDEO = { x: 0, y: 40, w: 787.2, h: 581.6 };
const PANEL_X = 787.2;
const BOUNDS = [0, 2, 6, 13, 19, 25, 31, 72];
const TOTAL = 72;

const fmt = (s: number) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, "0")}`;

export const passedAt = (i: number) => T.results + (i - 1) * T.resultStep;

const SUMMARY =
  "Requested manual flow passed: launch and title screen, first flap, scoring through driftwood gaps, collision and game over, pause/resume, and best score after relaunch. Otter physics and log spacing stayed consistent on iPhone 17; no layout issues found.";

const PendingDot: React.FC = () => (
  <svg width="14" height="14" viewBox="0 0 14 14" style={{ display: "block" }}>
    <circle cx="7" cy="7" r="5.25" fill="none" stroke="rgba(25,25,25,0.22)" strokeWidth="1.2" strokeDasharray="2.2 2" />
  </svg>
);

export const TestPlayer: React.FC<{ t: number; a: number }> = ({ t, a }) => {
  const n = TESTS.length - 1;
  let passed = 0;
  for (let i = 1; i <= n; i++) if (t >= passedAt(i)) passed++;
  const active = Math.min(n, passed + 1);
  const play = mix(2, 33, easeInOut(clamp01((t - T.results + 0.3) / (n * T.resultStep))));
  const playShown = t < T.results - 0.3 ? mix(0, 2, clamp01((t - T.toPlayer) / 1.2)) : play;
  const current = TESTS[Math.max(1, BOUNDS.filter((b) => b <= playShown).length - 1)] ?? TESTS[1];
  const scroll = mix(0, 44, prog(t, passedAt(4), 1.2));
  const hlY = active;

  const totalGap = 2 * (BOUNDS.length - 2);
  const barW = 763.2 - totalGap;

  return (
    <div style={{ position: "absolute", inset: 0, opacity: a, fontFamily: sans, color: C.ink, pointerEvents: "none" }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: WIN.w, height: 40, background: C.white, borderBottom: `0.8px solid ${C.hairline}`, boxSizing: "border-box" }}>
        <div style={{ position: "absolute", left: 16, top: 11, fontSize: 13, fontWeight: 500, lineHeight: "18px", letterSpacing: "-0.065px" }}>Otter Flap manual gameplay</div>
        <div style={{ position: "absolute", right: 16, top: 4, width: 32, height: 32, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <FIcon name="close_727c1" size={18} />
        </div>
      </div>
      <div style={{ position: "absolute", left: VIDEO.x, top: VIDEO.y, width: VIDEO.w, height: VIDEO.h, background: "#101010" }} />
      <div style={{ position: "absolute", left: 0, top: 621.6, width: PANEL_X, height: 68, background: C.white, padding: "8px 12px 12px", boxSizing: "border-box" }}>
        <div style={{ display: "flex", gap: 2, height: 12 }}>
          {BOUNDS.slice(0, -1).map((b, i) => {
            const e = BOUNDS[i + 1];
            const w = ((e - b) / TOTAL) * barW;
            const f = clamp01((playShown - b) / (e - b));
            const gray = i === 0;
            return (
              <div key={i} style={{ width: w, height: 12, borderRadius: 4, overflow: "hidden", position: "relative", background: gray ? "rgba(107,114,128,0.2)" : "rgba(52,211,153,0.2)" }}>
                <div style={{ position: "absolute", left: 0, top: 0, height: 12, width: w * f, background: gray ? "#6B7280" : C.mint, opacity: 0.85, borderRadius: 4 }} />
              </div>
            );
          })}
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 4, height: 36, paddingTop: 8, boxSizing: "border-box" }}>
          {[
            { k: "controls_f0a27", s: 14 },
            { k: "controls_24bbb", s: 16 },
            { k: "controls_85a38", s: 14 },
          ].map((b) => (
            <div key={b.k} style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <FIcon name={b.k} size={b.s} />
            </div>
          ))}
          <div style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 12, color: C.muted }}>1x</div>
          {["controls_8ad55", "controls_b923f"].map((k) => (
            <div key={k} style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <FIcon name={k} size={16} />
            </div>
          ))}
          <div style={{ flex: 1 }} />
          <div style={{ display: "flex", gap: 6, fontFamily: mono, fontSize: 11, lineHeight: "14px", letterSpacing: "0.11px", whiteSpace: "nowrap" }}>
            <span style={{ color: C.ink }}>{current.title}</span>
            <span style={{ color: C.faint }}>|</span>
            <span style={{ color: C.muted }}>
              {fmt(playShown)} / {fmt(TOTAL)}
            </span>
          </div>
        </div>
      </div>

      <div style={{ position: "absolute", left: PANEL_X, top: 40, width: WIN.w - PANEL_X, height: 649.6, background: C.panel, borderLeft: `0.8px solid ${C.hairline}`, boxSizing: "border-box", overflow: "hidden", display: "flex", flexDirection: "column" }}>
        <div style={{ display: "flex", gap: 12, padding: "10px 16px", borderBottom: `0.8px solid ${C.hairline}`, fontSize: 12, lineHeight: "16px", color: C.muted }}>
          <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
            <div style={{ width: 8, height: 8, borderRadius: 4, background: C.green }} />
            {passed} passed
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
            <div style={{ width: 8, height: 8, borderRadius: 4, background: C.red }} />0 failed
          </div>
        </div>
        <div style={{ padding: "12px 16px", borderBottom: `0.8px solid ${C.hairline}`, fontSize: 12, lineHeight: "19.5px", color: C.muted }}>{SUMMARY}</div>
        <div style={{ flex: 1, overflow: "hidden", position: "relative" }}>
        <div style={{ position: "relative", transform: `translateY(${-scroll}px)`, paddingTop: 4 }}>
          {TESTS.map((row, i) => {
            const done = i === 0 || t >= passedAt(i);
            const pop = i === 0 ? 1 : easeOut(clamp01((t - passedAt(i)) / 0.35));
            const hl = i === hlY && t > T.toPlayer + 0.8;
            return (
              <div key={i} style={{ paddingTop: i === 0 ? 0 : 4, background: hl ? "rgba(47,107,234,0.07)" : "transparent" }}>
                <div style={{ display: "flex", gap: 8, alignItems: "center", padding: "8px 12px" }}>
                  <div style={{ width: 32, textAlign: "right", fontFamily: mono, fontSize: 11, lineHeight: "14px", letterSpacing: "0.11px", color: C.faint }}>{row.time}</div>
                  <FIcon name={row.setup ? "rightpanel_b83dd" : "rightpanel_2a298"} size={14} />
                  <div style={{ fontSize: row.setup ? 12 : 13, fontWeight: row.setup ? 400 : 500, lineHeight: row.setup ? "16.5px" : "17.875px", letterSpacing: row.setup ? 0 : "-0.065px", width: 330 }}>{row.title}</div>
                </div>
                {row.note ? (
                  <div style={{ position: "relative", display: "flex", alignItems: "flex-start", padding: "6px 12px 6px 72px" }}>
                    <div style={{ position: "absolute", left: 59, top: 0, width: 8, height: 13.5, borderLeft: `0.8px solid ${C.hairline}`, borderBottom: `0.8px solid ${C.hairline}`, borderBottomLeftRadius: 6 }} />
                    <div style={{ width: 14, height: 16.5, display: "flex", alignItems: "center", position: "relative" }}>
                      <div style={{ position: "absolute", opacity: 1 - pop }}>
                        <PendingDot />
                      </div>
                      <div style={{ position: "absolute", opacity: done ? pop : 0, transform: `scale(${0.6 + 0.4 * pop})` }}>
                        <FIcon name="rightpanel_834f0" size={14} />
                      </div>
                    </div>
                    <div style={{ paddingLeft: 8, width: 310, fontSize: 12, lineHeight: "16.5px", color: done ? C.ink : C.faint }}>{row.note}</div>
                  </div>
                ) : null}
              </div>
            );
          })}
        </div>
        </div>
      </div>
    </div>
  );
};
