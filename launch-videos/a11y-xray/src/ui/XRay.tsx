import { AX, H, W } from "../game/sim";
import { IconComputer, IconPassed } from "../icons";
import { clamp01, ease, prog } from "../motion";
import { c, font } from "../theme";

type Node = { key: keyof typeof AX; ref: string; role: string; name: string; action?: string; side: "above" | "below" | "belowRight" };
export const NODES: Node[] = [
  { key: "pause", ref: "@i12", role: "button", name: "Pause", action: "press", side: "below" },
  { key: "sound", ref: "@i13", role: "button", name: "Sound", action: "press", side: "belowRight" },
  { key: "score", ref: "@i14", role: "text", name: "6", side: "below" },
  { key: "heading", ref: "@i16", role: "heading", name: "Paused", side: "above" },
  { key: "resume", ref: "@i17", role: "button", name: "Resume", action: "press", side: "above" },
  { key: "restart", ref: "@i18", role: "button", name: "Restart", action: "press", side: "below" },
];

const FS = 12.5;
const CW = FS * 0.6;

/** Accessibility-tree overlay drawn in iPhone points, on top of the game. */
export const XRayOverlay = ({ f, start, select, press, out }: { f: number; start: number; select: number; press: number; out: number }) => {
  const sel = prog(f, select, 24);
  const gone = prog(f, out, 30);
  const pr = clamp01((f - press) / 28);
  return (
    <svg width="100%" height="100%" viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="xMidYMid slice" style={{ position: "absolute", inset: 0 }}>
      <rect width={W} height={H} fill="rgba(249,249,249,1)" opacity={0.18 * prog(f, start, 30) * (1 - gone)} />
      {NODES.map((n, i) => {
        const b = AX[n.key];
        const d0 = start + i * 6;
        const draw = prog(f, d0, 26, ease.outCubic);
        const target = n.key === "resume";
        const dimmed = target ? 1 : 1 - 0.55 * sel;
        const o = Math.min(draw, 1) * (1 - gone) * dimmed;
        if (o <= 0) return null;
        const hasLabel = n.key !== "sound";
        const per = 2 * (b.w + b.h);
        const label = `${n.ref} ${n.role} "${n.name}"${n.action ? ` {${n.action}}` : ""}`;
        const lw = label.length * CW + 12;
        const lh = FS + 9;
        let lx = b.x;
        let ly = n.side === "above" ? b.y - lh - 5 : b.y + b.h + 5;
        if (n.side === "belowRight") lx = b.x + b.w - lw;
        if (n.key === "resume") lx = W / 2 - lw / 2;
        if (n.key === "restart") lx = W / 2 - lw / 2;
        if (n.key === "score") lx = W / 2 - lw / 2;
        if (n.key === "heading") { lx = W / 2 - lw / 2; ly = b.y - lh - 36; }
        const labelO = prog(f, d0 + 10, 18, ease.outCubic);
        const stroke = target && sel > 0 ? c.blue : "rgba(25,25,25,0.72)";
        const halo = target ? 1 + 0.08 * Math.sin(Math.PI * clamp01(pr * 1.4)) : 1;
        return (
          <g key={n.key} opacity={o}>
            <g transform={`translate(${b.x + b.w / 2} ${b.y + b.h / 2}) scale(${halo}) translate(${-(b.x + b.w / 2)} ${-(b.y + b.h / 2)})`}>
              {target ? <rect x={b.x - 3} y={b.y - 3} width={b.w + 6} height={b.h + 6} rx={7} fill={c.blue} opacity={0.14 * sel} /> : null}
              <rect x={b.x - 3} y={b.y - 3} width={b.w + 6} height={b.h + 6} rx={7} fill="none" stroke="rgba(255,255,255,0.9)" strokeWidth={3} strokeDasharray={per + 60} strokeDashoffset={(per + 60) * (1 - draw)} />
              <rect x={b.x - 3} y={b.y - 3} width={b.w + 6} height={b.h + 6} rx={7} fill="none" stroke={stroke} strokeWidth={target ? 1.2 + 0.8 * sel : 1.1} strokeDasharray={per + 60} strokeDashoffset={(per + 60) * (1 - draw)} />
            </g>
            {hasLabel ? <g opacity={labelO} transform={`translate(0 ${(1 - labelO) * 3})`}>
              <rect x={lx} y={ly} width={lw} height={lh} rx={4} fill="#FCFCFC" stroke={target && sel > 0 ? "rgba(51,125,244,0.45)" : "rgba(0,0,0,0.1)"} strokeWidth={0.8} />
              <text x={lx + 6} y={ly + lh / 2 + FS * 0.36} fontFamily={font.mono} fontSize={FS} fill={c.ink} xmlSpace="preserve">
                <tspan fill={c.blue}>{n.ref}</tspan>
                <tspan fill={c.text3}> {n.role} </tspan>
                <tspan fill={c.ink}>&quot;{n.name}&quot;</tspan>
                {n.action ? <tspan fill={c.text3}> {`{${n.action}}`}</tspan> : null}
              </text>
            </g> : null}
          </g>
        );
      })}
    </svg>
  );
};

const Code = ({ lines, chars, hi }: { lines: string[]; chars: number; hi?: boolean }) => {
  let left = chars;
  return (
    <div style={{ marginTop: 6, padding: "8px 10px", borderRadius: 6, background: hi ? c.blueSoft : "#F2F2F2", fontFamily: font.mono, fontSize: 12, lineHeight: "18px", color: c.ink, whiteSpace: "pre", minHeight: lines.length * 18 }}>
      {lines.map((l, i) => {
        const shown = l.slice(0, Math.max(0, left));
        left -= l.length;
        return <div key={i}>{shown.length ? shown : "\u00a0"}</div>;
      })}
    </div>
  );
};

const Step = ({ n, label, o, children }: { n: number; label: string; o: number; children: React.ReactNode }) => (
  <div style={{ opacity: o, transform: `translateY(${(1 - o) * 6}px)`, marginTop: n === 1 ? 0 : 14 }}>
    <div style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 12, lineHeight: "16px", color: c.text3 }}>
      <span style={{ fontFamily: font.mono, fontSize: 11, color: c.text4, width: 10 }}>{n}</span>
      <span style={{ fontFamily: font.mono, fontSize: 11.5, color: c.ink }}>{label}</span>
    </div>
    <div style={{ paddingLeft: 18 }}>{children}</div>
  </div>
);

const Q1 = ['{ "action": "query", "target": "ios",', '  "role": "button", "name": "Resume" }'];
const A1 = ['{ "action": "act", "target": "ios",', '  "reference": "@i17", "operation": "press" }'];
const len = (ls: string[]) => ls.reduce((a, l) => a + l.length, 0);

/** Observe → reference → act card, in CSS px (rendered at 1.5x). */
export const ToolCard = ({ f, query, result, act, done }: { f: number; query: number; result: number; act: number; done: number }) => {
  const qChars = Math.floor(clamp01((f - query - 8) / 50) * len(Q1));
  const aChars = Math.floor(clamp01((f - act - 8) / 50) * len(A1));
  return (
    <div style={{ width: 396, padding: "12px 14px 14px", borderRadius: 12, background: c.panel, boxShadow: "0 0 0 0.8px rgba(0,0,0,0.08), 0 10px 30px rgba(0,0,0,0.06)", fontFamily: font.sans, color: c.ink }}>
      <div style={{ display: "flex", alignItems: "center", gap: 7, fontSize: 13, fontWeight: 500, letterSpacing: -0.065, marginBottom: 12 }}>
        <IconComputer size={15} color="#444" />computer
        <span style={{ fontFamily: font.mono, fontWeight: 400, fontSize: 11, color: c.text4, marginLeft: 2 }}>target: ios</span>
      </div>
      <Step n={1} label="query" o={prog(f, query, 16, ease.outCubic)}>
        <Code lines={Q1} chars={qChars} />
      </Step>
      <Step n={2} label="result" o={prog(f, result, 16, ease.outCubic)}>
        <div style={{ marginTop: 6, padding: "8px 10px", borderRadius: 6, background: c.blueSoft, fontFamily: font.mono, fontSize: 12, lineHeight: "18px", whiteSpace: "pre" }}>
          <span style={{ color: c.blue }}>@i17</span><span style={{ color: c.text3 }}> button </span><span>&quot;Resume&quot;</span><span style={{ color: c.text3 }}> {"{press}"}</span>
        </div>
      </Step>
      <Step n={3} label="act" o={prog(f, act, 16, ease.outCubic)}>
        <Code lines={A1} chars={aChars} />
      </Step>
      <div style={{ opacity: prog(f, done, 16, ease.outCubic), transform: `translateY(${(1 - prog(f, done, 16, ease.outCubic)) * 6}px)`, marginTop: 14, paddingLeft: 18, display: "flex", alignItems: "center", gap: 8, fontSize: 12, lineHeight: "16.5px" }}>
        <div style={{ transform: `scale(${ease.outBack(clamp01((f - done) / 18))})` }}><IconPassed /></div>
        <span>Pause menu dismissed; game resumed at score 6</span>
      </div>
    </div>
  );
};
