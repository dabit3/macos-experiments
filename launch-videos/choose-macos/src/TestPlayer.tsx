import React from "react";
import { C, FONT, T, VH, VW } from "./theme";
import { Icon } from "./Icon";
import { FootageFrame } from "./Footage";
import { easeInOut, easeOut, prog } from "./anim";

export const PLAYER_TITLE = "Otter Flap gameplay test";
export const TOTAL_S = 72;

export const TESTS = [
  { t: 2, title: "It should launch to the title screen", note: "Otter Flap title and Tap to start render inside the safe area." },
  { t: 6, title: "It should start a run on tap", note: "First tap starts the run; the otter flaps and gravity pulls it down." },
  { t: 13, title: "It should score by clearing each log gap", note: "Score increments 0 → 3 as the otter clears each pair of logs." },
  { t: 21, title: "It should end the run on collision", note: "Hitting a log shows the Splash! card with score and best." },
  { t: 27, title: "It should pause when the app is backgrounded", note: "Home gesture pauses the scene; returning shows Resume." },
  { t: 33, title: "It should relaunch with the best score saved", note: "Quit and relaunch keeps best score 3 on the title screen." },
];

const SUMMARY =
  "Requested gameplay flow passed: launch, tap to flap, scoring through log gaps, collision and game over, pause on background, quit and relaunch. Flap physics stay consistent at 60 fps and the best score persists across relaunch. No layout issues on iPhone 17.";

const fmt = (s: number) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, "0")}`;

const VIDEO_W = 787.2;
const CTRL_H = 68;
const VIDEO_H = VH - 40 - CTRL_H;
const BAR_W = 763.2;
const GAP = 2;

/** Phone + Simulator toolbar crop inside the source footage (px). */
const PHONE = { x: 326, y: 40, w: 256, h: 538 };

export type PlayerState = { time: number; footageN: number; tap: number; tapPos: { x: number; y: number } | null; listIn: number };

const segments = () => {
  const starts = [0, ...TESTS.map((x) => x.t)];
  const ends = [...TESTS.map((x) => x.t), TOTAL_S];
  const usable = BAR_W - GAP * (starts.length - 1);
  return starts.map((s, i) => ({ s, e: ends[i], w: ((ends[i] - s) / TOTAL_S) * usable, setup: i === 0 }));
};

const Video: React.FC<{ st: PlayerState }> = ({ st }) => {
  const scale = (VIDEO_H - 36) / PHONE.h;
  const pw = PHONE.w * scale;
  const ph = PHONE.h * scale;
  const px = (VIDEO_W - pw) / 2;
  const py = 22;
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: VIDEO_W, height: VIDEO_H, overflow: "hidden", background: "#1c2b36" }}>
      <div style={{ position: "absolute", inset: -40, filter: "blur(28px) saturate(1.05) brightness(0.92)" }}>
        <FootageFrame n={st.footageN} scale={(VIDEO_W + 80) / 874} offsetY={60} />
      </div>
      <div style={{ position: "absolute", left: px, top: py, width: pw, height: ph, overflow: "hidden", borderRadius: 12 }}>
        <FootageFrame n={st.footageN} scale={scale} offsetX={PHONE.x} offsetY={PHONE.y} />
      </div>
      {st.tapPos ? (
        <>
          <div
            style={{
              position: "absolute",
              left: px + st.tapPos.x * pw - 16,
              top: py + st.tapPos.y * ph - 16,
              width: 32,
              height: 32,
              borderRadius: 9999,
              border: "2px solid rgba(255,255,255,0.9)",
              background: "rgba(49,124,255,0.35)",
              transform: `scale(${0.6 + st.tap * 0.8})`,
              opacity: st.tap > 0 ? 1 - st.tap : 0,
            }}
          />
          <Icon name="pointer" size={0} w={28} h={32} style={{ position: "absolute", left: px + st.tapPos.x * pw - 6, top: py + st.tapPos.y * ph - 4 }} />
        </>
      ) : null}
    </div>
  );
};

const Controls: React.FC<{ time: number }> = ({ time }) => {
  const segs = segments();
  const current = [...TESTS].reverse().find((x) => time >= x.t);
  return (
    <div style={{ position: "absolute", left: 0, top: VIDEO_H, width: VIDEO_W, height: CTRL_H, background: "#fff", padding: "8px 12px 12px", boxSizing: "border-box" }}>
      <div style={{ display: "flex", gap: GAP, height: 12 }}>
        {segs.map((s, i) => {
          const fill = Math.max(0, Math.min(1, (time - s.s) / (s.e - s.s)));
          const base = s.setup ? "107,114,128" : "52,211,153";
          return (
            <div key={i} style={{ position: "relative", width: s.w, height: 12, borderRadius: 4, overflow: "hidden", background: `rgba(${base},0.2)` }}>
              <div style={{ position: "absolute", left: 0, top: 0, height: 12, width: s.w * fill, borderRadius: 4, background: `rgb(${base})`, opacity: 0.85 }} />
            </div>
          );
        })}
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 4, height: 36, paddingTop: 8, boxSizing: "border-box" }}>
        {[
          ["prev", 14],
          ["pause", 16],
          ["next", 14],
        ].map(([n, s]) => (
          <div key={n} style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <Icon name={n as string} size={s as number} />
          </div>
        ))}
        <div style={{ ...T.mono11, fontWeight: 500, color: C.text56, padding: "0 6px" }}>1x</div>
        {["loop", "download"].map((n) => (
          <div key={n} style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <Icon name={n} size={16} />
          </div>
        ))}
        <div style={{ flex: 1 }} />
        <div style={{ display: "flex", gap: 6, ...T.mono11 }}>
          <span style={{ color: C.text }}>{current ? current.title : "iPhone 17, iOS 26.5"}</span>
          <span style={{ color: C.text40 }}>|</span>
          <span style={{ color: C.text56 }}>
            {fmt(time)} / {fmt(TOTAL_S)}
          </span>
        </div>
      </div>
    </div>
  );
};

const TestRow: React.FC<{ t: number; title: string; note: string; active: boolean; inP: number }> = ({ t, title, note, active, inP }) => (
  <div style={{ paddingTop: 4, height: 83, boxSizing: "border-box", opacity: inP, transform: `translateY(${(1 - inP) * 8}px)` }}>
    <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "8px 12px", background: active ? "#eaf1fe" : undefined }}>
      <div style={{ width: 32, textAlign: "right", ...T.mono11, color: C.text40 }}>{fmt(t)}</div>
      <Icon name="test-step" size={14} />
      <div style={{ fontSize: 13, lineHeight: "17.875px", letterSpacing: -0.065, fontWeight: 400, color: C.text, whiteSpace: "nowrap" }}>{title}</div>
    </div>
    <div style={{ position: "relative", display: "flex", alignItems: "center", padding: "6px 12px 6px 0" }}>
      <div style={{ width: 72 }} />
      <div style={{ transform: `scale(${0.4 + 0.6 * inP})` }}>
        <Icon name="check-circle" size={14} />
      </div>
      <div style={{ paddingLeft: 8, width: 310, fontSize: 12, lineHeight: "16.5px", color: C.text }}>{note}</div>
      <div
        style={{
          position: "absolute",
          left: 59,
          top: 0,
          width: 8,
          height: 22.5,
          borderLeft: `0.8px solid ${C.border06}`,
          borderBottom: `0.8px solid ${C.border06}`,
          borderBottomLeftRadius: 6,
        }}
      />
    </div>
  </div>
);

const Panel: React.FC<{ time: number; listIn: number }> = ({ time, listIn }) => {
  const activeIdx = TESTS.reduce((acc, x, i) => (time >= x.t ? i : acc), -1);
  const rowsPassed = TESTS.reduce((acc, x) => acc + easeInOut(Math.max(0, Math.min(1, (time - x.t) / 1.6))), 0);
  const scroll = Math.max(0, 57 + (rowsPassed - 1) * 83 - 230);
  return (
    <div style={{ position: "absolute", left: VIDEO_W, top: 0, width: VW - VIDEO_W, height: VH - 40, background: C.panel, borderLeft: `0.8px solid ${C.border06}`, boxSizing: "border-box" }}>
      <div style={{ display: "flex", gap: 12, padding: "10px 16px", borderBottom: `0.8px solid ${C.border06}` }}>
        {[
          [C.green, `${TESTS.length} passed`],
          [C.red, "0 failed"],
        ].map(([c, l]) => (
          <div key={l} style={{ display: "flex", alignItems: "center", gap: 6 }}>
            <div style={{ width: 8, height: 8, borderRadius: 9999, background: c }} />
            <div style={{ ...T.t12, color: C.text56 }}>{l}</div>
          </div>
        ))}
      </div>
      <div style={{ padding: "12px 16px", borderBottom: `0.8px solid ${C.border06}`, fontSize: 12, lineHeight: "19.5px", color: C.text56 }}>{SUMMARY}</div>
      <div style={{ position: "relative", overflow: "hidden", height: 480 }}>
        <div style={{ transform: `translateY(${-scroll}px)`, paddingTop: 4 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "8px 12px", opacity: listIn }}>
            <div style={{ width: 32, textAlign: "right", ...T.mono11, color: C.text40 }}>0:00</div>
            <Icon name="setup-step" size={14} />
            <div style={{ fontSize: 12, lineHeight: "16.5px", color: C.text, width: 330 }}>iPhone 17, iOS 26.5; Xcode 26.6. Fresh install of Otter Flap, clean save data.</div>
          </div>
          {TESTS.map((x, i) => (
            <TestRow key={x.t} {...x} active={i === activeIdx} inP={prog(listIn * 100, i * 10, i * 10 + 40, easeOut)} />
          ))}
        </div>
      </div>
    </div>
  );
};


export const TestPlayer: React.FC<{ st: PlayerState }> = ({ st }) => (
  <div style={{ position: "absolute", left: 0, top: 0, width: VW, height: VH, background: C.panel, fontFamily: FONT, color: C.text, overflow: "hidden" }}>
    <div style={{ height: 40, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 16px", borderBottom: `0.8px solid ${C.border06}`, boxSizing: "border-box" }}>
      <div style={{ ...T.t13, fontWeight: 500 }}>{PLAYER_TITLE}</div>
      <Icon name="close" size={18} />
    </div>
    <div style={{ position: "absolute", left: 0, top: 40, width: VW, height: VH - 40 }}>
      <Video st={st} />
      <Controls time={st.time} />
      <Panel time={st.time} listIn={st.listIn} />
    </div>
  </div>
);

