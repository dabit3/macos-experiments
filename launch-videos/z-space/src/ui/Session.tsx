import React from "react";
import { OffthreadVideo, staticFile } from "remotion";
import { C, INTER } from "../theme";
import { Icon, Laptop, ProgressIcon, GithubMark, Chevron, MutedSpeaker, Popout } from "../icons";
import { Btn, DevinMark, Kbd, Text } from "./common";

export const LEFT_W = 629;

export const SESSION = {
  header: { x: 0, y: 0, w: LEFT_W, h: 44 },
  tabs: { x: LEFT_W + 1, y: 0, w: 1203 - LEFT_W - 1, h: 44 },
  chat: { x: 0, y: 44, w: LEFT_W, h: 520 },
  composer: { x: 15.3, y: 575.4, w: 598.5, h: 106 },
  desktop: { x: 637.9, y: 131.7, w: 557.4, h: 417.4 },
  live: { x: LEFT_W + 1, y: 624, w: 1203 - LEFT_W - 1, h: 66 },
};

export const SessionBase: React.FC = () => (
  <div style={{ position: "absolute", inset: 0, background: C.page }}>
    <div style={{ position: "absolute", left: LEFT_W, top: 0, bottom: 0, width: 1, background: "rgba(0,0,0,0.075)" }} />
  </div>
);

export const MacBadge: React.FC = () => (
  <div style={{ height: 19, padding: "0 6px 0 5px", borderRadius: 5, background: C.badgeBg, display: "flex", alignItems: "center", gap: 4 }}>
    <Laptop size={13} color="#2F6FEB" />
    <Text size={12.2} lh={16} color="#2F6FEB">
      macOS
    </Text>
  </div>
);

export const SessionHeader: React.FC<{ title: string }> = ({ title }) => (
  <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center" }}>
    <div style={{ width: 11.3 }} />
    <Btn icon="sidebar" radius={6} />
    <div style={{ width: 19 }} />
    <Text size={14} lh={20}>{title}</Text>
    <div style={{ width: 7 }} />
    <MacBadge />
    <div style={{ flex: 1 }} />
    <Btn icon="list" radius={6} />
    <div style={{ width: 1 }} />
    <Btn icon="flag" radius={6} />
    <div style={{ width: 1 }} />
    <Btn icon="more" radius={6} />
    <div style={{ width: 7.5 }} />
  </div>
);

export const RightTabs: React.FC<{ computer: number }> = ({ computer }) => (
  <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", paddingLeft: 7 }}>
    <div
      style={{
        height: 28,
        padding: "0 8px 0 6px",
        borderRadius: 7,
        display: "flex",
        alignItems: "center",
        gap: 5,
        background: `rgba(0,0,0,${0.055 * (1 - computer)})`,
      }}
    >
      <ProgressIcon size={17} />
      <Text size={14} lh={20} color={computer > 0.5 ? C.muted : C.text}>Progress</Text>
    </div>
    <div style={{ width: 1 }} />
    <div
      style={{
        height: 28,
        padding: "0 7.6px 0 6px",
        borderRadius: 7,
        display: "flex",
        alignItems: "center",
        gap: 5,
        background: `rgba(0,0,0,${0.055 * computer})`,
      }}
    >
      <Icon name="computer" size={17} />
      <Text size={13.2} lh={20} color={computer > 0.5 ? C.text : C.muted}>Computer</Text>
    </div>
    <div style={{ width: 4 }} />
    <Btn icon="plus" radius={6} />
    <div style={{ flex: 1 }} />
    <Btn icon="expand" radius={6} />
    <div style={{ width: 4 }} />
    <Btn icon="panel" radius={6} />
    <div style={{ width: 7.5 }} />
  </div>
);

const USER_PROMPT = "Build Flappy Bird with an Otter. Then build and test it on iOS.";
export const REPLY =
  "On it — building an otter Flappy Bird iOS game (likely in dabit3/experiments), then building and testing it on the iOS simulator.";

type ChatProps = {
  frame: number;
  replyChars: number;
  rows: number;
  collapsed: number;
  status: "setup" | "build" | "none";
};

const Row: React.FC<{ vis: number; children: React.ReactNode }> = ({ vis, children }) => (
  <div style={{ opacity: vis, transform: `translateY(${(1 - vis) * 6}px)` }}>{children}</div>
);

const Cmd: React.FC<{ text: string; time?: string }> = ({ text, time }) => (
  <div style={{ display: "flex", gap: 12, paddingBottom: 8 }}>
    <div style={{ flex: 1, fontFamily: INTER, fontSize: 13, lineHeight: "18px", color: "rgba(25,25,25,0.72)", letterSpacing: -0.05 }}>{text}</div>
    {time ? <div style={{ fontFamily: INTER, fontSize: 13, lineHeight: "18px", color: C.faint }}>{time}</div> : null}
  </div>
);

const Thought: React.FC<{ label: string; open?: boolean }> = ({ label, open }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 4, paddingBottom: 8 }}>
    <Text size={13} lh={18} color="rgba(25,25,25,0.72)">{label}</Text>
    <Chevron size={14} dir={open ? "down" : "right"} />
  </div>
);

const StatusLine: React.FC<{ frame: number; text: string }> = ({ frame, text }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 5, marginLeft: -3.6 }}>
    <DevinMark size={20} style={{ opacity: 0.75 + 0.25 * Math.sin(frame / 9) }} />
    <div
      style={{
        fontFamily: INTER,
        fontSize: 14,
        lineHeight: "20px",
        letterSpacing: -0.07,
        backgroundImage: `linear-gradient(90deg, rgba(25,25,25,0.72) 0%, rgba(25,25,25,0.72) ${((frame * 1.3) % 160) - 40}%, rgba(25,25,25,0.35) ${((frame * 1.3) % 160) - 20}%, rgba(25,25,25,0.72) ${((frame * 1.3) % 160)}%)`,
        WebkitBackgroundClip: "text",
        color: "transparent",
      }}
    >
      {text}
    </div>
  </div>
);

const ROWS = [
  { k: "cmd", text: "uname -a; ls ~ ~/repos 2>/dev/null; which xcodebuild xcrun xcodegen; xcodebuild -version", time: "11s" },
  { k: "cmd", text: "cd ~/repos/experiments && git status -sb && git log --oneline -5 && ls", time: "6s" },
  { k: "thought", text: "Thought for 5s" },
  { k: "cmd", text: "brew install xcodegen swiftformat 2>&1 | tail -3; xcrun simctl list devices available | rg -i iphone | head", time: "9s" },
  { k: "thought", text: "Thought for 9s" },
  { k: "cmd", text: "mkdir -p OtterFlap/Sources && xcodegen generate && xcodebuild -scheme OtterFlap -sdk iphonesimulator build", time: "4s" },
] as const;

export const Chat: React.FC<ChatProps> = ({ frame, replyChars, rows, collapsed, status }) => {
  const words = REPLY.slice(0, replyChars);
  const open = 1 - collapsed;
  return (
    <div style={{ position: "absolute", inset: 0, padding: "16px 24.6px 0 24.6px" }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 8 }}>
        <div style={{ padding: "8px 14px", borderRadius: 18, background: "#EEEEEE" }}>
          <Text size={14} lh={20}>{USER_PROMPT}</Text>
        </div>
        <div style={{ width: 200, height: 46, borderRadius: 12, background: "#EEEEEE", display: "flex", alignItems: "flex-start", padding: "6px 8px", gap: 10 }}>
          <div style={{ width: 34, height: 34, borderRadius: 8, background: "#E2E2E2", display: "flex", alignItems: "center", justifyContent: "center" }}>
            <GithubMark size={15} />
          </div>
          <Text size={13} lh={18} weight={500} style={{ marginTop: 2 }}>dabit3/experiments</Text>
        </div>
      </div>
      <div style={{ height: 22 }} />
      {status === "setup" ? <StatusLine frame={frame} text="Setting up..." /> : null}
      {replyChars > 0 ? (
        <div style={{ fontFamily: INTER, fontSize: 14, lineHeight: "20px", color: C.text, letterSpacing: -0.07 }}>{words}</div>
      ) : null}
      {rows > 0 ? (
        <div style={{ marginTop: 14 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 6, height: 20, marginLeft: -1 }}>
            <Chevron size={15} dir={collapsed > 0.5 ? "right" : "down"} color="rgba(25,25,25,0.65)" />
            <Text size={14} lh={20} color="rgba(25,25,25,0.72)">
              {collapsed > 0.5 ? "Worked for 38s" : `Working for ${Math.min(38, 4 + Math.floor(rows * 5.4))}s`}
            </Text>
          </div>
          <div style={{ overflow: "hidden", height: open * 250, opacity: open }}>
            <div style={{ marginLeft: 7, marginTop: 8, paddingLeft: 16, borderLeft: "1px solid rgba(0,0,0,0.08)" }}>
              {ROWS.map((r, i) => (
                <Row key={i} vis={Math.max(0, Math.min(1, rows - i))}>
                  {r.k === "cmd" ? <Cmd text={r.text} time={r.time} /> : <Thought label={r.text} />}
                </Row>
              ))}
            </div>
          </div>
        </div>
      ) : null}
      {status === "build" ? (
        <div style={{ marginTop: 16 }}>
          <StatusLine frame={frame} text="Preparing iOS build tools" />
        </div>
      ) : null}
    </div>
  );
};

export const Composer: React.FC<{ running: boolean }> = ({ running }) => (
  <div style={{ position: "absolute", inset: 0, borderRadius: 20, background: C.card, boxShadow: "inset 0 0 0 0.8px rgba(0,0,0,0.13)" }}>
    <div style={{ position: "absolute", left: 16.2, top: 16, fontFamily: INTER, fontSize: 13.8, lineHeight: "20px", color: "rgba(25,25,25,0.58)", letterSpacing: -0.06 }}>
      Guide Devin while it works, or press <Kbd icon="cmd" />
      <Kbd icon="enter" /> to queue
    </div>
    <div style={{ position: "absolute", left: 11.4, right: 12, bottom: 12, height: 28, display: "flex", alignItems: "center" }}>
      <Btn icon="plus" />
      <div style={{ width: 1 }} />
      <Btn icon="slash" />
      <div style={{ width: 8.6 }} />
      <Text size={13} lh={18} color={C.muted}>Opus 5.5 (Preview)</Text>
      <div style={{ flex: 1 }} />
      <Btn icon="mic" />
      <Btn icon="voice" />
      <div style={{ width: 4 }} />
      <div style={{ width: 28, height: 28, borderRadius: 9999, background: running ? "#1A1A1A" : "#818181", display: "flex", alignItems: "center", justifyContent: "center" }}>
        {running ? <div style={{ width: 11, height: 11, borderRadius: 2.5, background: "#fff" }} /> : <Icon name="send" size={18} />}
      </div>
    </div>
  </div>
);

export const DESKTOP_FPS = 30;

export const Desktop: React.FC<{ startFrom: number; radius?: number }> = ({ startFrom, radius = 0 }) => (
  <div style={{ position: "absolute", inset: 0, overflow: "hidden", borderRadius: radius, background: "#1b2a3a" }}>
    <OffthreadVideo
      src={staticFile("media/desktop.mp4")}
      startFrom={Math.max(0, Math.round(startFrom))}
      muted
      style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }}
    />
  </div>
);

export const LiveControls: React.FC<{ progress: number }> = ({ progress }) => (
  <div style={{ position: "absolute", inset: 0 }}>
    <div style={{ position: "absolute", left: 11.4, right: 11.2, top: 7, height: 9, borderRadius: 3, background: "#CCDDFB" }}>
      <div style={{ position: "absolute", left: `${progress * 100}%`, top: -1, width: 2.4, height: 11, borderRadius: 1, background: "#2E6CFF" }} />
    </div>
    <div style={{ position: "absolute", left: 11.4, right: 11, top: 26, height: 28, display: "flex", alignItems: "center" }}>
      <Btn icon="arrow-left" radius={6} />
      <div style={{ width: 4 }} />
      <Btn icon="arrow-left" radius={6} style={{ transform: "scaleX(-1)" }} />
      <div style={{ width: 8 }} />
      <div style={{ height: 28, padding: "0 10px 0 9px", borderRadius: 9999, boxShadow: "inset 0 0 0 0.8px rgba(0,0,0,0.09)", display: "flex", alignItems: "center", gap: 6 }}>
        <div style={{ width: 8, height: 8, borderRadius: 9999, background: "#F03034" }} />
        <Text size={14} lh={20}>Live</Text>
      </div>
      <div style={{ flex: 1 }} />
      <MutedSpeaker size={18} />
      <div style={{ width: 16 }} />
      <Text size={13} lh={20} color="rgba(25,25,25,0.72)">Auto (reduced)</Text>
      <Chevron size={15} color="rgba(25,25,25,0.6)" style={{ marginLeft: 4 }} />
      <div style={{ width: 20 }} />
      <Popout size={18} />
    </div>
  </div>
);
