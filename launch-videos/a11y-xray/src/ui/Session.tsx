import type { ReactNode } from "react";
import { Img, staticFile } from "remotion";
import {
  IconArrowLeft, IconArrowRight, IconChevronDown, IconChevronRight, IconComputer, IconDots, IconExpand, IconFlag, IconGithub,
  IconLaptop, IconList, IconMic, IconMute, IconPanelRight, IconPlus, IconPopout, IconProgress, IconSidebar, IconSlash, IconWave,
} from "../icons";
import { lerp } from "../motion";
import { c, font } from "../theme";

export const USER_TEXT = "Build Flappy Bird with an Otter. Then build and test it on iOS.";
export const REPLY = "On it — building an otter Flappy Bird iOS game (likely in dabit3/experiments), then building and testing it on the iOS simulator.";

type Row = { kind: "cmd" | "thought"; text: string; dur?: string };
export const ROWS: Row[] = [
  { kind: "cmd", text: "uname -a; ls ~ ~/repos 2>/dev/null; which xcodebuild xcrun xcodegen; xcodebuild -version 2>/dev/null", dur: "11s" },
  { kind: "cmd", text: "cd ~/repos/experiments && git status -sb && git log --oneline -5 && ls", dur: "6s" },
  { kind: "thought", text: "Thought for 5s" },
  { kind: "cmd", text: "brew install xcodegen swiftformat 2>&1 | tail -3; xcrun simctl list devices available | rg -i iphone | head", dur: "9s" },
  { kind: "thought", text: "Thought for 9s" },
  { kind: "cmd", text: "xcodegen generate && xcodebuild -scheme FlappyOtter -destination 'platform=iOS Simulator,name=iPhone 17' build", dur: "4s" },
];

export const RIGHT = { x: 656, w: 624 };
/** Desktop capture placement inside the right pane (CSS px, relative to pane). */
export const DESK_IN_PANE = { x: 9, y: 137, w: 581 };

const Shimmer = ({ text, f }: { text: string; f: number }) => {
  const p = ((f % 110) / 110) * 180 - 40;
  return (
    <span style={{ backgroundImage: `linear-gradient(90deg, #555 ${p - 30}%, #0A0A0A ${p}%, #555 ${p + 30}%)`, WebkitBackgroundClip: "text", backgroundClip: "text", color: "transparent" }}>{text}</span>
  );
};

const Kbd = ({ children }: { children: ReactNode }) => (
  <span style={{ display: "inline-flex", alignItems: "center", justifyContent: "center", minWidth: 16, height: 17, borderRadius: 3.5, background: "#EDEDED", fontSize: 11.5, color: "#555", margin: "0 1.5px", verticalAlign: "1px" }}>{children}</span>
);

const Input = ({ x, w }: { x: number; w: number }) => (
  <div style={{ position: "absolute", left: x, top: 600, width: w, height: 110, borderRadius: 18, background: c.surface, boxShadow: `0 0 0 0.7px ${c.border}` }}>
    <div style={{ position: "absolute", left: 17, top: 15, fontSize: 16, lineHeight: "24px", color: "#6A6A6A", whiteSpace: "nowrap" }}>
      Guide Devin while it works, or press <Kbd>⌘</Kbd><Kbd>↵</Kbd> to queue
    </div>
    <div style={{ position: "absolute", left: 17, top: 74, display: "flex", alignItems: "center", gap: 12 }}>
      <IconPlus size={19} color="#444" />
      <IconSlash size={18} color="#444" />
      <div style={{ marginLeft: 3, fontSize: 15, color: "#454545" }}>Opus 5.5 (Preview)</div>
    </div>
    <div style={{ position: "absolute", right: 86, top: 74 }}><IconMic size={18} color="#444" /></div>
    <div style={{ position: "absolute", right: 57, top: 74 }}><IconWave size={18} color="#444" /></div>
    <div style={{ position: "absolute", right: 13, top: 69, width: 29, height: 29, borderRadius: 99, background: "#141414", display: "flex", alignItems: "center", justifyContent: "center" }}>
      <div style={{ width: 11, height: 11, borderRadius: 2.5, background: "#EDEDED" }} />
    </div>
  </div>
);

const Header = ({ w, split }: { w: number; split: number }) => (
  <div style={{ position: "absolute", left: 0, top: 0, width: w, height: 46 }}>
    <div style={{ position: "absolute", left: 17, top: 14 }}><IconSidebar size={18} color="#505050" /></div>
    <div style={{ position: "absolute", left: 61, top: 12, display: "flex", alignItems: "center", gap: 7, fontSize: 15, color: c.text }}>
      <span>Create Otter Flappy Bird iOS App</span>
      <span style={{ display: "inline-flex", alignItems: "center", gap: 4, height: 20, padding: "0 6px 0 5px", borderRadius: 4.5, background: c.badgeBg, color: c.badgeText, fontSize: 14 }}>
        <IconLaptop size={14} color={c.badgeText} sw={1.4} />macOS
      </span>
    </div>
    <div style={{ position: "absolute", right: split > 0.5 ? 13 : 38, top: 14, display: "flex", gap: 12 }}>
      <IconList size={18} color="#505050" />
      <IconFlag size={18} color="#505050" />
      <IconDots size={18} color="#505050" />
      {split > 0.5 ? null : <IconPanelRight size={18} color="#505050" />}
    </div>
  </div>
);

export type SessionState = {
  f: number;
  split: number;
  replyChars: number;
  rows: number;
  preparing: number;
  scroll: number;
  pane?: ReactNode;
};

export const Session = ({ f, split, replyChars, rows, preparing, scroll, pane }: SessionState) => {
  const paneW = lerp(1280, RIGHT.x, split);
  const colW = Math.min(722, paneW - 52);
  const colX = (paneW - colW) / 2;
  const inW = Math.min(742, paneW - 32);
  const inX = (paneW - inW) / 2;
  const reply = REPLY.slice(0, replyChars);
  return (
    <div style={{ position: "absolute", inset: 0, background: c.page, fontFamily: font.sans, color: c.text, overflow: "hidden" }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: paneW, height: 720, overflow: "hidden" }}>
        <div style={{ position: "absolute", left: colX, top: 46, width: colW, height: 548, overflow: "hidden", WebkitMaskImage: "linear-gradient(180deg, transparent 0, #000 14px, #000 calc(100% - 10px), transparent 100%)" }}>
          <div style={{ position: "absolute", left: 0, top: 23 - scroll, width: colW }}>
            <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 8 }}>
              <div style={{ background: c.fill, borderRadius: 18, padding: "8px 15px", fontSize: 16, lineHeight: "21px", maxWidth: colW - 80 }}>{USER_TEXT}</div>
              <div style={{ background: c.fill, borderRadius: 11, width: 208, height: 47, position: "relative" }}>
                <div style={{ position: "absolute", left: 6, top: 6, width: 35, height: 35, borderRadius: 8, background: "#E3E3E3", display: "flex", alignItems: "center", justifyContent: "center" }}><IconGithub size={16} /></div>
                <div style={{ position: "absolute", left: 50, top: 7, fontSize: 14.5, fontWeight: 500 }}>dabit3/experiments</div>
              </div>
            </div>
            <div style={{ marginTop: 26, fontSize: 16, lineHeight: "21px", minHeight: 42 }}>{reply}</div>
            {rows > 0 ? (
              <div style={{ marginTop: 25, fontSize: 15, lineHeight: "19px" }}>
                <div style={{ display: "flex", alignItems: "center", gap: 7, color: "#333", marginLeft: -1 }}>
                  <IconChevronDown size={15} color="#555" />
                  <span>Working for {Math.min(38, Math.round(4 + rows * 6))}s</span>
                </div>
                <div style={{ position: "relative", marginTop: 8, paddingLeft: 23 }}>
                  <div style={{ position: "absolute", left: 7, top: 0, bottom: 0, width: 0.8, background: "#E3E3E3" }} />
                  {ROWS.slice(0, Math.ceil(rows)).map((r, i) => {
                    const o = Math.min(1, rows - i);
                    return (
                      <div key={i} style={{ opacity: o, transform: `translateY(${(1 - o) * 4}px)`, display: "flex", gap: 12, marginBottom: 8, color: "#484848" }}>
                        {r.kind === "cmd" ? <span style={{ flex: 1 }}>{r.text}</span> : (
                          <span style={{ display: "inline-flex", alignItems: "center", gap: 6, color: "#555" }}>{r.text}<IconChevronRight size={14} color="#777" /></span>
                        )}
                        {r.dur ? <span style={{ color: "#9A9A9A", fontVariantNumeric: "tabular-nums" }}>{r.dur}</span> : null}
                      </div>
                    );
                  })}
                </div>
              </div>
            ) : null}
            {preparing > 0 ? (
              <div style={{ opacity: preparing, marginTop: 20, display: "flex", alignItems: "center", gap: 9, fontSize: 16, marginLeft: 1 }}>
                <Img src={staticFile("devin-mark-black.png")} style={{ height: 17 }} />
                <Shimmer text="Preparing iOS build tools" f={f} />
              </div>
            ) : null}
          </div>
        </div>
        <Header w={paneW} split={split} />
        <Input x={inX} w={inW} />
      </div>
      {split > 0 ? (
        <div style={{ position: "absolute", left: paneW, top: 0, width: RIGHT.w, height: 720, borderLeft: "0.8px solid #E4E4E4", background: c.page, overflow: "hidden" }}>
          <div style={{ position: "absolute", left: 10, top: 9, height: 28, display: "flex", alignItems: "center", gap: 6, fontSize: 15 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 6, padding: "0 8px", height: 28, color: "#555" }}><IconProgress size={17} color="#555" />Progress</div>
            <div style={{ display: "flex", alignItems: "center", gap: 6, padding: "0 8px", height: 28, borderRadius: 7, background: c.fillStrong, color: c.text }}><IconComputer size={17} color="#333" />Computer</div>
            <div style={{ padding: "0 6px" }}><IconPlus size={17} color="#555" /></div>
          </div>
          <div style={{ position: "absolute", right: 67, top: 14 }}><IconExpand size={17} color="#555" /></div>
          <div style={{ position: "absolute", right: 34, top: 14 }}><IconPanelRight size={18} color="#505050" /></div>
          {pane}
          <div style={{ position: "absolute", left: 13, top: 657, width: 573, height: 11, background: "#CCDDFB" }}>
            <div style={{ position: "absolute", right: 0, top: -2, width: 2.5, height: 15, background: "#1F63E6" }} />
          </div>
          <div style={{ position: "absolute", left: 18, top: 684 }}><IconArrowLeft size={17} color="#555" /></div>
          <div style={{ position: "absolute", left: 52, top: 684 }}><IconArrowRight size={17} color="#555" /></div>
          <div style={{ position: "absolute", left: 84, top: 678, height: 29, padding: "0 11px 0 10px", borderRadius: 99, boxShadow: "0 0 0 0.8px #DEDEDE", display: "flex", alignItems: "center", gap: 7, fontSize: 15 }}>
            <div style={{ width: 8, height: 8, borderRadius: 9, background: "#E5352B" }} />Live
          </div>
          <div style={{ position: "absolute", left: 396, top: 684 }}><IconMute size={17} color="#555" /></div>
          <div style={{ position: "absolute", left: 434, top: 683, display: "flex", alignItems: "center", gap: 6, fontSize: 15, color: "#454545" }}>Auto (reduced)<IconChevronDown size={14} color="#555" /></div>
          <div style={{ position: "absolute", left: 562, top: 684 }}><IconPopout size={17} color="#555" /></div>
        </div>
      ) : null}
    </div>
  );
};
