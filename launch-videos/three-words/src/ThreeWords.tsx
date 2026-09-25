import { AbsoluteFill, Img, OffthreadVideo, Sequence, staticFile, useCurrentFrame } from "remotion";
import { cursorAt, lerp, outCubic, outQuint, press, quint, ramp } from "./anim";
import { INTER } from "./fonts";
import { C, S } from "./theme";
import { PROMPT_HEAD, PROMPT_TAIL, T, TYPE_END, TYPE_TIMES } from "./timeline";
import { Home, MENU_ROW, PICKER, PROMPT_POS, SEND } from "./ui/Home";
import { Camera, type Cam, Cursor, toScreen } from "./ui/primitives";
import {
  COL_FULL,
  COL_SPLIT,
  ComputerPane,
  Guide,
  PANE,
  Para,
  type Row,
  STATUS_TEXT_DX,
  STATUS_Y,
  SessionHeader,
  Status,
  Streamed,
  UserBubble,
  VNC,
  WorkBlock,
} from "./ui/Session";
import { REC_LEN, TITLE_POS, VIDEO_H, VIDEO_W, Viewer } from "./ui/Viewer";

const WORD_PX = 120;
const PROMPT = PROMPT_HEAD + PROMPT_TAIL;
const REPLY = "On it — building an otter Flappy Bird iOS game (likely in dabit3/experiments), then building and testing it on the iOS simulator.";
const RUN_STATUS = "Running Otter Flap in the iOS Simulator";

const camLerp = (a: Cam, b: Cam, t: number): Cam => ({ z: Math.exp(lerp(Math.log(a.z), Math.log(b.z), t)), x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t) });

const MorphWord: React.FC<{
  f: number;
  word: string;
  suffix: string;
  inAt: number;
  morph: readonly [number, number];
  fs: number;
  lh: number;
  target: { x: number; y: number };
  sigmaEnd: number;
}> = ({ f, word, suffix, inAt, morph, fs, lh, target, sigmaEnd }) => {
  const [a, b] = morph;
  if (f < inAt || f > b) return null;
  const e = ramp(f, inAt, inAt + 30, outQuint);
  const t = ramp(f, a, b, quint);
  const s0 = WORD_PX / fs;
  const sig = Math.exp(lerp(Math.log(s0), Math.log(sigmaEnd), t));
  const L = { x: lerp(960, target.x, t), y: lerp(540, target.y, t) };
  const p = 1 - t;
  const fade = 1 - ramp(f, b - 8, b, outCubic);
  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        top: 0,
        transformOrigin: "0 0",
        transform: `translate(${L.x}px, ${L.y + (1 - e) * 18}px) scale(${sig}) translate(${-p * 50}%, ${-p * 50}%)`,
        fontFamily: INTER,
        fontWeight: 500,
        fontSize: fs,
        lineHeight: `${lh}px`,
        letterSpacing: "-0.005em",
        color: C.ink,
        whiteSpace: "nowrap",
        opacity: e * fade,
        filter: e < 1 ? `blur(${(1 - e) * 0.9}px)` : undefined,
        zIndex: 40,
      }}
    >
      {word}
      <span style={{ opacity: 1 - ramp(f, a, a + (b - a) * 0.45, outCubic) }}>{suffix}</span>
    </div>
  );
};

const HOME_CAM_A: Cam = { z: 1.36, x: 612.5, y: 345 };
const HOME_CAM_B: Cam = { z: 1.22, x: 612.5, y: 352 };
const HOME_CAM_C: Cam = { z: 1.2, x: 600, y: 372 };

const homeCam = (f: number): Cam => {
  const [a, b] = T.buildMorph;
  if (f < b) return camLerp(HOME_CAM_A, HOME_CAM_B, ramp(f, a, b, quint));
  return camLerp(HOME_CAM_B, HOME_CAM_C, ramp(f, TYPE_END - 20, T.pickerClick, quint));
};

const HomeScene: React.FC<{ f: number }> = ({ f }) => {
  const [a, b] = T.buildMorph;
  const cam = homeCam(f);
  const typed = TYPE_TIMES.filter((t) => f >= t).length;
  const prompt = f >= b - 10 ? PROMPT_HEAD + PROMPT_TAIL.slice(0, typed) : "";
  const uiIn = ramp(f, b - 20, b + 6, outCubic);
  const macos = f >= T.macClick + 2;
  const menuOpen = ramp(f, T.pickerClick + 1, T.pickerClick + 13, outQuint) * (1 - ramp(f, T.macClick + 6, T.macClick + 16, outCubic));
  const cursorStart = { x: 780, y: 560 };
  const pickerPt = { x: PICKER.x + 44, y: PICKER.y + 9 };
  const macRow = MENU_ROW(1);
  const macPt = { x: macRow.x + 70, y: macRow.y + 16 };
  const sendPt = { x: SEND.x + 13, y: SEND.y + 14 };
  const cp = cursorAt(f, cursorStart, [
    { t0: T.cursorIn, t1: T.pickerClick - 3, to: pickerPt, bend: 0.12 },
    { t0: T.pickerClick + 12, t1: T.macClick - 3, to: macPt, bend: -0.2 },
    { t0: T.macClick + 14, t1: T.sendClick - 3, to: sendPt, bend: 0.16 },
  ]);
  const hover =
    menuOpen > 0 && cp.x > macRow.x && cp.x < macRow.x + macRow.w
      ? [0, 1, 2].find((i) => cp.y >= MENU_ROW(i).y && cp.y < MENU_ROW(i).y + 30) ?? -1
      : -1;
  const pr = Math.max(press(f, T.pickerClick), press(f, T.macClick), press(f, T.sendClick));
  const caretOn = f < TYPE_END + 6 || Math.floor((f - TYPE_END) / 32) % 2 === 1;
  const out = 1 - ramp(f, T.homeOut, T.homeOut + 14, outCubic);
  return (
    <>
      <Camera cam={cam}>
        <div style={{ position: "absolute", inset: 0, opacity: uiIn * out }}>
          <Home
            prompt={prompt}
            promptOpacity={ramp(f, b - 10, b - 2, outCubic)}
            placeholder={1 - ramp(f, a, a + 14, outCubic)}
            caret={f >= b && f < T.sendClick && caretOn}
            env={macos ? "macos" : "ubuntu"}
            menu={menuOpen}
            hover={hover}
            sendPress={press(f, T.sendClick)}
          />
          <Cursor p={cp} pressed={pr} opacity={ramp(f, T.cursorIn - 6, T.cursorIn + 8, outCubic)} />
        </div>
      </Camera>
      <MorphWord f={f} word="Build" suffix="." inAt={T.buildIn} morph={T.buildMorph} fs={14} lh={20} target={toScreen(cam, PROMPT_POS)} sigmaEnd={S * cam.z} />
    </>
  );
};

const SESSION_ROWS: Row[] = [
  { kind: "cmd", text: "uname -a; sw_vers; ls ~/repos; which xcodebuild xcrun xcodegen; xcodebuild -version", dur: "11s" },
  { kind: "cmd", text: "cd ~/repos/experiments && git status -sb && git log --oneline -5 && ls && cat validate-native-apps.sh | head -80", dur: "6s" },
  { kind: "thought", text: "Thought for 5s" },
  { kind: "cmd", text: "xcrun simctl list runtimes; xcrun simctl list devices available | rg 'iPhone 17'", dur: "4s" },
  { kind: "cmd", text: "brew install xcodegen && xcodegen --version", dur: "14s" },
  { kind: "thought", text: "Thought for 3s" },
];

const SessionScene: React.FC<{ f: number }> = ({ f }) => {
  const s = T.session;
  const k = f - s;
  const cam = camLerp({ z: 1.0, x: 612.5, y: 344.5 }, { z: 1.045, x: 612.5, y: 350 }, ramp(f, s, T.runCut, (t) => t));
  const inO = ramp(f, s, s + 18, outCubic);
  const shown = SESSION_ROWS.map((_, i) => ramp(k, 104 + i * 18, 118 + i * 18, outCubic));
  const secs = 36 + Math.min(2, Math.floor(Math.max(0, k - 90) / 60));
  return (
    <Camera cam={cam}>
      <div style={{ position: "absolute", inset: 0, opacity: inO, transform: `translateY(${(1 - inO) * 6}px)` }}>
        <SessionHeader right={1225} />
        <div style={{ position: "absolute", left: COL_FULL.x, top: 66, width: COL_FULL.w }}>
          <UserBubble msg={PROMPT} opacity={1} />
          <Para>
            <Streamed full={REPLY} words={(k - 26) / 2.2} />
          </Para>
          {k >= 84 ? (
            <div style={{ opacity: ramp(k, 84, 98, outCubic) }}>
              <WorkBlock label={`Working for ${secs}s`} rows={SESSION_ROWS} shown={shown} />
            </div>
          ) : null}
        </div>
        <div style={{ position: "absolute", left: COL_FULL.x, top: STATUS_Y, opacity: ramp(k, 70, 86, outCubic) }}>
          <Status label="Preparing iOS build tools" />
        </div>
        <Guide x={(1225 - 712) / 2} w={712} />
      </div>
    </Camera>
  );
};

const SPLIT_ROWS: Row[] = [
  {
    kind: "cmd",
    text: "cd ~/repos/experiments/ios-otter-flap && xcodegen generate && xcodebuild -project OtterFlap.xcodeproj -scheme OtterFlap -sdk iphonesimulator -derivedDataPath build build",
    dur: "41s",
  },
  { kind: "thought", text: "Thought for 4s" },
  { kind: "cmd", text: 'xcrun simctl boot "iPhone 17" && open -a Simulator', dur: "9s" },
  { kind: "cmd", text: "xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/OtterFlap.app && xcrun simctl launch booted com.devin.OtterFlap", dur: "3s" },
  { kind: "thought", text: "Thought for 6s" },
  { kind: "cmd", text: "computer query --app Simulator", dur: "2s" },
];

const splitCam = (f: number): Cam => {
  const base: Cam = { z: 1, x: 612.5, y: 344.5 };
  const vnc: Cam = { z: 1.46, x: VNC.x + VNC.w / 2, y: VNC.y + VNC.h / 2 + 4 };
  return camLerp(base, vnc, ramp(f, T.split + 150, T.split + 250, quint));
};

const tapTimes = (start: number, n: number, gap: number) => Array.from({ length: n }, (_, i) => start + i * gap + (i % 2) * 5);

const Taps: React.FC<{ f: number; at: { x: number; y: number }; times: number[]; appear: number; scale: number }> = ({ f, at, times, appear, scale }) => {
  if (f < appear) return null;
  const jitter = Math.sin(f / 23) * 3 * scale;
  const p = { x: at.x + 26 * scale + jitter, y: at.y + 34 * scale - Math.cos(f / 31) * 2 * scale };
  const move = ramp(f, appear, appear + 40, outQuint);
  const cur = { x: lerp(p.x + 90 * scale, at.x, move), y: lerp(p.y + 60 * scale, at.y, move) };
  const pr = Math.max(0, ...times.map((t) => press(f, t)));
  return (
    <>
      {times.map((t) => {
        const d = f - t;
        if (d < 0 || d > 22) return null;
        const u = ramp(d, 0, 22, outCubic);
        const r = (7 + 13 * u) * scale;
        return (
          <div
            key={t}
            style={{
              position: "absolute",
              left: cur.x - r,
              top: cur.y - r,
              width: r * 2,
              height: r * 2,
              borderRadius: 9999,
              border: `${1.4 * scale}px solid rgba(255,255,255,${0.9 * (1 - u)})`,
              background: `rgba(0,0,0,${0.18 * (1 - u)})`,
              boxSizing: "border-box",
            }}
          />
        );
      })}
      <div style={{ position: "absolute", left: 0, top: 0, transformOrigin: `${cur.x}px ${cur.y}px`, transform: `scale(${scale})` }}>
        <Cursor p={cur} pressed={pr} opacity={ramp(f, appear, appear + 12, outCubic)} />
      </div>
    </>
  );
};

const SplitScene: React.FC<{ f: number }> = ({ f }) => {
  const sp = T.split;
  const k = f - sp;
  const cam = splitCam(f);
  const [a, b] = T.runMorph;
  const inO = ramp(f, b - 20, b + 6, outCubic);
  const shown = SPLIT_ROWS.map((_, i) => (i < 4 ? 1 : ramp(k, 60 + (i - 4) * 70, 76 + (i - 4) * 70, outCubic)));
  const vscale = VNC.w / 874;
  const phoneTap = { x: 452 * vscale, y: 390 * vscale };
  const gameplay = T.runCut + 300;
  return (
    <>
      <Camera cam={cam}>
        <div style={{ position: "absolute", inset: 0, opacity: inO }}>
          <SessionHeader right={PANE} panelIcon={false} />
          <div style={{ position: "absolute", left: 0, top: 44, width: PANE, height: STATUS_Y - 44 - 8, overflow: "hidden" }}>
            <div style={{ position: "absolute", left: COL_SPLIT.x, bottom: 0, width: COL_SPLIT.w }}>
              <UserBubble msg={PROMPT} opacity={1} />
              <Para>{REPLY}</Para>
              <WorkBlock label={`Working for 1m ${12 + Math.floor(Math.max(0, k) / 60)}s`} rows={SPLIT_ROWS} shown={shown} />
            </div>
          </div>
          <div style={{ position: "absolute", left: COL_SPLIT.x, top: STATUS_Y }}>
            <Status label={RUN_STATUS} labelOpacity={ramp(f, b - 10, b - 2, outCubic)} />
          </div>
          <Guide x={15.3} w={598.5} />
          <ComputerPane progress={1}>
            <Sequence from={T.runCut} layout="none">
              <OffthreadVideo src={staticFile("media/computer.mp4")} startFrom={0} playbackRate={2} muted style={{ width: "100%", height: "100%", display: "block" }} />
            </Sequence>
            <Taps f={f} at={phoneTap} times={tapTimes(gameplay + 26, 6, 22)} appear={gameplay} scale={vscale * 1.25} />
          </ComputerPane>
        </div>
      </Camera>
      <MorphWord
        f={f}
        word="Run"
        suffix="."
        inAt={T.runCut + 4}
        morph={T.runMorph}
        fs={13}
        lh={18}
        target={toScreen(cam, { x: COL_SPLIT.x + STATUS_TEXT_DX, y: STATUS_Y })}
        sigmaEnd={S * cam.z}
      />
    </>
  );
};

const viewerCam = (f: number): Cam => camLerp({ z: 1, x: 612.5, y: 344.5 }, { z: 1.06, x: 660, y: 348 }, ramp(f, T.viewer + 70, T.end - 20, quint));

const ViewerScene: React.FC<{ f: number }> = ({ f }) => {
  const [a, b] = T.verifyMorph;
  const vw = T.viewer;
  const cam = viewerCam(f);
  const inO = ramp(f, b - 20, b + 6, outCubic);
  const now = lerp(2, 35.4, ramp(f, vw + 40, T.end - 30, (t) => t));
  const vs = VIDEO_W / 874;
  const vh = 656 * vs;
  const dy = (VIDEO_H - vh) / 2;
  const tapAt = { x: 452 * vs, y: 392 * vs + dy };
  return (
    <>
      <Camera cam={cam} bg={C.bg}>
        <div style={{ position: "absolute", inset: 0, opacity: inO }}>
          <Viewer
            now={Math.min(REC_LEN, now)}
            titleOpacity={ramp(f, b - 10, b - 2, outCubic)}
            video={
              <>
                <Sequence from={T.verifyCut} layout="none">
                  <OffthreadVideo src={staticFile("media/computer.mp4")} startFrom={11 * 60 - (vw - T.verifyCut)} muted style={{ position: "absolute", left: 0, top: dy, width: VIDEO_W, height: vh }} />
                </Sequence>
                <div style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,0.04)" }} />
                <Taps f={f} at={tapAt} times={tapTimes(vw + 50, 14, 26)} appear={vw + 20} scale={vs * 1.2} />
              </>
            }
          />
        </div>
      </Camera>
      <MorphWord f={f} word="Verify" suffix="." inAt={T.verifyCut + 4} morph={T.verifyMorph} fs={13} lh={18} target={toScreen(cam, TITLE_POS)} sigmaEnd={S * cam.z} />
    </>
  );
};

const EndCard: React.FC<{ f: number }> = ({ f }) => {
  const e = T.end;
  const lo = ramp(f, e + 6, e + 46, outQuint);
  const tl = ramp(f, e + 26, e + 62, outQuint);
  return (
    <AbsoluteFill style={{ background: C.bg, alignItems: "center", justifyContent: "center", opacity: ramp(f, e - 16, e, outCubic) }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 34 }}>
        <Img
          src={staticFile("lockup-black.png")}
          style={{ width: 460, opacity: lo, transform: `translateY(${(1 - lo) * 10}px) scale(${0.985 + 0.015 * lo})`, filter: lo < 1 ? `blur(${(1 - lo) * 6}px)` : undefined }}
        />
        <div
          style={{
            fontFamily: INTER,
            fontSize: 30,
            lineHeight: "36px",
            fontWeight: 400,
            letterSpacing: "-0.005em",
            color: C.ink56,
            opacity: tl,
            transform: `translateY(${(1 - tl) * 8}px)`,
          }}
        >
          Devin, now on macOS
        </div>
      </div>
    </AbsoluteFill>
  );
};

export const ThreeWords: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill style={{ background: C.bg }}>
      {f < T.session + 4 ? <HomeScene f={f} /> : null}
      {f >= T.session && f < T.runCut ? <SessionScene f={f} /> : null}
      {f >= T.runCut && f < T.verifyCut ? <SplitScene f={f} /> : null}
      {f >= T.verifyCut && f < T.end ? <ViewerScene f={f} /> : null}
      {f >= T.end - 16 ? <EndCard f={f} /> : null}
    </AbsoluteFill>
  );
};
