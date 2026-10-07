import { Img, OffthreadVideo, Sequence, interpolate, staticFile } from "remotion";
import { ClickRing, Cursor, cursorAt } from "./Cursor";
import { Icon } from "./Icon";
import { STAGE_H, STAGE_W } from "./Camera";
import { RECORDING_LENGTH, SUMMARY, TESTS } from "./tests";
import { TEST_START } from "./timeline";
import { C, inter, mono, monoText, outQuint, ramp, text } from "./theme";

export const TITLE_HANDOFF = 46;
const RIGHT_W = 416;
const BLEED = 240;
export const VIDEO_W = STAGE_W - RIGHT_W;
const TITLE_H = 40;
const CONTROLS_H = 68;
export const VIDEO_H = STAGE_H - TITLE_H - CONTROLS_H;
const SIMBAR_H = 25;
const PHONE_H = 536;
const BEZEL = 10;
const SCREEN_H = PHONE_H - BEZEL * 2;
const SCREEN_W = (SCREEN_H * 402) / 874;
const PHONE_W = SCREEN_W + BEZEL * 2;
const PHONE_X = (VIDEO_W - PHONE_W) / 2;
const PHONE_Y = SIMBAR_H + (VIDEO_H - SIMBAR_H - PHONE_H) / 2;
export const PLAYER_SCREEN = {
  x: PHONE_X + BEZEL,
  y: TITLE_H + PHONE_Y + BEZEL,
  w: SCREEN_W,
  h: SCREEN_H,
};

const toSec = (s: string) => {
  const [m, x] = s.split(":").map(Number);
  return m * 60 + x;
};
const fmt = (s: number) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, "0")}`;

export const testFrames = (() => {
  let at = TEST_START;
  return TESTS.map((t) => {
    const from = at;
    const dur = Math.round(t.dur * 60);
    at += dur;
    return { from, dur, pass: from + Math.round(dur * 0.72) };
  });
})();
export const TESTS_END = testFrames[testFrames.length - 1].from + testFrames[testFrames.length - 1].dur;

const GROUP_PT = 4;
const ROW_H = 33.875;
const ASSERT_H = 45;

const activeIndex = (f: number) => {
  let a = -1;
  testFrames.forEach((t, i) => {
    if (f >= t.from) a = i;
  });
  return f >= TESTS_END ? TESTS.length : a;
};

const CheckPop: React.FC<{ t: number }> = ({ t }) => {
  const s = interpolate(t, [0, 0.6, 1], [0.4, 1.12, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  return (
    <div style={{ width: 14, height: 14, transform: `scale(${s})`, opacity: Math.min(1, t * 2.5) }}>
      <Icon name="check" size={14} />
    </div>
  );
};

const SimVideo: React.FC<{ f: number }> = ({ f }) => {
  const fade = 8;
  return (
    <>
      {TESTS.map((t, i) => {
        const tf = testFrames[i];
        const isLast = i === TESTS.length - 1;
        const len = tf.dur + (isLast ? 400 : fade);
        const start = i === 0 ? -TEST_START : 0;
        return (
          <Sequence key={i} from={tf.from + start} durationInFrames={len - start} layout="none">
            <div
              style={{
                position: "absolute",
                inset: 0,
                opacity: i === 0 ? 1 : ramp(f, tf.from, tf.from + fade, outQuint),
              }}
            >
              <OffthreadVideo
                src={staticFile("otter.mp4")}
                startFrom={i === 0 ? TITLE_HANDOFF : Math.round(t.src * 60)}
                playbackRate={i === 0 ? 0.4 : 1}
                muted
                style={{ width: "100%", height: "100%", display: "block" }}
              />
            </div>
          </Sequence>
        );
      })}
    </>
  );
};

const phoneCursor = (f: number) => {
  const keys: { f: number; x: number; y: number }[] = [{ f: 0, x: 0.78, y: 0.8 }];
  const clicks: { f: number; x: number; y: number }[] = [];
  TESTS.forEach((t, i) => {
    const tf = testFrames[i];
    t.taps.forEach((tap) => {
      const cf = tf.from + Math.round((tap.t - t.src) * 60);
      keys.push({ f: cf - 34, x: keys[keys.length - 1].x, y: keys[keys.length - 1].y });
      keys.push({ f: cf, x: tap.x, y: tap.y });
      keys.push({ f: cf + 50, x: tap.x + 0.2, y: tap.y + 0.22 });
      clicks.push({ f: cf, x: tap.x, y: tap.y });
    });
  });
  return { pos: cursorAt(f, keys), clicks };
};

export const Player: React.FC<{ frame: number }> = ({ frame }) => {
  const f = frame;
  const active = activeIndex(f);
  const passed = testFrames.filter((t) => f >= t.pass).length;
  const curT = Math.max(0, Math.min(active, TESTS.length - 1));
  const tf = testFrames[curT];
  const elapsed = Math.max(0, Math.min(f - tf.from, tf.dur)) / 60;
  const done = f >= TESTS_END;
  const now = done ? toSec(RECORDING_LENGTH) : toSec(TESTS[curT].at) + elapsed;

  const listH = STAGE_H - TITLE_H - 36.8 - 146;
  const target = (i: number) => Math.max(0, Math.min(i, TESTS.length - 1) * (GROUP_PT + ROW_H + ASSERT_H) - listH + 150);
  let scroll = 0;
  testFrames.forEach((t, i) => {
    scroll = interpolate(f, [t.from - 10, t.from + 30], [scroll, target(i)], {
      easing: outQuint,
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }) || scroll;
  });
  const weights = TESTS.map((t, i) => (i < TESTS.length - 1 ? toSec(TESTS[i + 1].at) - toSec(t.at) : toSec(RECORDING_LENGTH) - toSec(t.at)));
  const setupW = 0.8;
  const trackW = VIDEO_W - 24;
  const totalW = weights.reduce((a, b) => a + b, 0) + setupW;
  const gaps = 2 * TESTS.length;
  const unit = (trackW - gaps) / totalW;

  const { pos, clicks } = phoneCursor(f);

  return (
    <div style={{ position: "absolute", inset: 0, background: C.panel, fontFamily: inter }}>
      <div
        style={{
          height: TITLE_H,
          borderBottom: `0.8px solid ${C.hairline}`,
          boxSizing: "border-box",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "0 16px",
        }}
      >
        <span style={text(13, 18, 500)}>Otter Flap manual gameplay</span>
        <div style={{ width: 32, height: 32, display: "flex", alignItems: "center", justifyContent: "center", marginRight: -8 }}>
          <Icon name="close" size={18} />
        </div>
      </div>

      <div style={{ position: "absolute", left: 0, top: TITLE_H, width: VIDEO_W, height: STAGE_H - TITLE_H, background: "#fff" }}>
        <div style={{ position: "absolute", left: -BLEED, top: 0, width: VIDEO_W + BLEED, height: VIDEO_H, overflow: "hidden", background: "#27323a" }}>
          <Img
            src={staticFile("desktop.jpg")}
            style={{
              position: "absolute",
              left: -60,
              top: -60,
              width: VIDEO_W + BLEED + 120,
              height: VIDEO_H + 120,
              objectFit: "cover",
              filter: "blur(28px) saturate(0.9) brightness(0.92)",
            }}
          />
          <div
            style={{
              position: "absolute",
              left: BLEED,
              top: 0,
              right: 0,
              height: SIMBAR_H,
              background: "#1e1f21",
              display: "flex",
              alignItems: "center",
              padding: "0 10px",
              justifyContent: "space-between",
            }}
          >
            <div style={{ display: "flex", flexDirection: "column", gap: 0 }}>
              <span style={{ fontFamily: inter, fontSize: 7.5, lineHeight: "9px", fontWeight: 600, color: "#e6e6e6" }}>iPhone 17</span>
              <span style={{ fontFamily: inter, fontSize: 6.5, lineHeight: "8px", color: "#8d8d8d" }}>iOS 26.5</span>
            </div>
            <div style={{ display: "flex", gap: 9, alignItems: "center" }}>
              {[0, 1, 2].map((k) => (
                <div key={k} style={{ width: 9, height: 8, border: "1px solid #c9c9c9", borderRadius: k === 0 ? "1px 1px 2px 2px" : 2, boxSizing: "border-box" }} />
              ))}
            </div>
          </div>

          <div
            style={{
              position: "absolute",
              left: BLEED + PHONE_X,
              top: PHONE_Y,
              width: PHONE_W,
              height: PHONE_H,
              borderRadius: 44,
              background: "#0b0b0c",
              boxShadow: "0 0 0 1.6px #6f6f72, 0 0 0 2.6px #1a1a1a, 0 16px 40px rgba(0,0,0,0.28)",
            }}
          >
            <div
              style={{
                position: "absolute",
                left: BEZEL,
                top: BEZEL,
                width: SCREEN_W,
                height: SCREEN_H,
                borderRadius: 35,
                overflow: "hidden",
                background: "#000",
              }}
            >
              <SimVideo f={f} />
              {clicks.map((c, i) => (
                <ClickRing key={i} x={c.x * SCREEN_W} y={c.y * SCREEN_H} age={f - c.f} size={22} />
              ))}
            </div>
            <Cursor x={BEZEL + pos.x * SCREEN_W} y={BEZEL + pos.y * SCREEN_H} size={17} />
          </div>
        </div>

        <div style={{ position: "absolute", left: 0, top: VIDEO_H, width: VIDEO_W, height: CONTROLS_H, padding: "8px 12px 12px", boxSizing: "border-box" }}>
          <div style={{ display: "flex", gap: 2, height: 12 }}>
            {[setupW, ...weights].map((w, i) => {
              const ti = i - 1;
              const fill =
                i === 0
                  ? 1
                  : ramp(f, testFrames[ti].from, testFrames[ti].from + testFrames[ti].dur, (x) => x);
              const setup = i === 0;
              return (
                <div
                  key={i}
                  style={{
                    width: w * unit,
                    height: 12,
                    borderRadius: 4,
                    overflow: "hidden",
                    position: "relative",
                    background: setup ? "rgba(107,114,128,0.2)" : "rgba(52,211,153,0.2)",
                  }}
                >
                  <div
                    style={{
                      position: "absolute",
                      left: 0,
                      top: 0,
                      height: 12,
                      width: w * unit * fill,
                      borderRadius: 4,
                      background: setup ? "#6b7280" : "#34d399",
                      opacity: 0.85,
                    }}
                  />
                </div>
              );
            })}
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 4, height: 28, marginTop: 8 }}>
            {(["prev", "pause", "next"] as const).map((n) => (
              <div key={n} style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
                <Icon name={n} size={n === "pause" ? 16 : 14} />
              </div>
            ))}
            <div style={{ height: 28, padding: "0 6px", display: "flex", alignItems: "center", fontFamily: mono, fontWeight: 500, fontSize: 11, lineHeight: "14px", letterSpacing: 0.11, color: C.muted }}>
              1x
            </div>
            {(["loop", "download"] as const).map((n) => (
              <div key={n} style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
                <Icon name={n} size={16} />
              </div>
            ))}
            <div style={{ flex: 1 }} />
            <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
              <span style={{ ...monoText(C.text), whiteSpace: "nowrap" }}>{TESTS[curT].title}</span>
              <span style={monoText(C.faint)}>|</span>
              <span style={{ ...monoText(C.muted), fontVariantNumeric: "tabular-nums" }}>
                {fmt(now)} / {RECORDING_LENGTH}
              </span>
            </div>
          </div>
        </div>
      </div>

      <div
        style={{
          position: "absolute",
          left: VIDEO_W,
          top: TITLE_H,
          width: RIGHT_W,
          height: STAGE_H - TITLE_H,
          borderLeft: `0.8px solid ${C.hairline}`,
          boxSizing: "border-box",
          background: C.panel,
          display: "flex",
          flexDirection: "column",
        }}
      >
        <div style={{ borderBottom: `0.8px solid ${C.hairline}`, padding: "10px 16px", display: "flex", gap: 12, alignItems: "center" }}>
          <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
            <div style={{ width: 8, height: 8, borderRadius: 9999, background: C.green }} />
            <span style={{ ...text(12, 16, 400, C.muted), fontVariantNumeric: "tabular-nums" }}>{passed} passed</span>
          </div>
          <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
            <div style={{ width: 8, height: 8, borderRadius: 9999, background: C.red }} />
            <span style={text(12, 16, 400, C.muted)}>0 failed</span>
          </div>
        </div>
        <div style={{ borderBottom: `0.8px solid ${C.hairline}`, padding: "12px 16px" }}>
          <p style={{ margin: 0, ...text(12, 19.5, 400, C.muted), letterSpacing: 0 }}>{SUMMARY}</p>
        </div>
        <div style={{ position: "relative", flex: 1, overflow: "hidden" }}>
          <div style={{ position: "absolute", left: 0, top: -scroll, width: RIGHT_W - 0.8, paddingTop: 4 }}>
            {TESTS.map((t, i) => {
              const tfi = testFrames[i];
              const started = f >= tfi.from;
              const a = ramp(f, tfi.pass - 4, tfi.pass + 14, outQuint);
              const hi = ramp(f, tfi.from - 2, tfi.from + 10, outQuint) * (1 - ramp(f, (testFrames[i + 1]?.from ?? TESTS_END) - 2, (testFrames[i + 1]?.from ?? TESTS_END) + 10, outQuint));
              const op = started ? 1 : 0.4;
              return (
                <div key={i} style={{ paddingTop: GROUP_PT, opacity: op }}>
                  <div
                    style={{
                      height: ROW_H,
                      display: "flex",
                      alignItems: "center",
                      gap: 8,
                      padding: "0 12px",
                      background: `rgba(51,125,244,${0.1 * hi})`,
                    }}
                  >
                    <div style={{ width: 32, textAlign: "right", ...monoText(C.faint) }}>{t.at}</div>
                    <Icon name="test" size={14} />
                    <div style={{ ...text(13, 17.875, 500), whiteSpace: "nowrap" }}>{t.title}</div>
                  </div>
                  <div style={{ height: ASSERT_H * a, overflow: "hidden", position: "relative" }}>
                    <div style={{ position: "absolute", left: 59, top: 0, width: 8, height: 22.5, borderLeft: `0.8px solid ${C.hairline}`, borderBottom: `0.8px solid ${C.hairline}`, borderBottomLeftRadius: 6 }} />
                    <div style={{ display: "flex", alignItems: "center", padding: "6px 12px 6px 0" }}>
                      <div style={{ width: 72 }} />
                      <CheckPop t={ramp(f, tfi.pass, tfi.pass + 18, (x) => x)} />
                      <div style={{ paddingLeft: 8, width: 310, ...text(12, 16.5, 400), letterSpacing: 0, opacity: a }}>{t.assertion}</div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
};
