import { AX, GAP, GROUND, H, LOG_W, OTTER_X, W, gapCenter, otterAt, pipeX, scoreAt } from "./sim";
import { font } from "../theme";

const Cloud = ({ x, y, s = 1 }: { x: number; y: number; s?: number }) => (
  <g transform={`translate(${x} ${y}) scale(${s})`} fill="#FFFFFF">
    <ellipse cx="0" cy="10" rx="34" ry="11" />
    <circle cx="-12" cy="2" r="13" />
    <circle cx="8" cy="-2" r="16" />
    <circle cx="24" cy="6" r="10" />
  </g>
);

const wrap = (x: number, span: number) => ((x % span) + span) % span;

const Mountains = ({ off }: { off: number }) => {
  const peaks = [
    [0, 640], [40, 590], [70, 612], [112, 548], [150, 600], [190, 575], [238, 618], [282, 560], [322, 604], [360, 570], [393, 610],
  ];
  const span = 393;
  return (
    <g>
      {[0, 1].map((k) => {
        const dx = -wrap(off, span) + k * span;
        const pts = peaks.map(([x, y]) => `${x + dx},${y}`).join(" ");
        return (
          <g key={k}>
            <polygon points={`${dx},700 ${pts} ${dx + span},700`} fill="#8D88C9" />
            {peaks.filter((p) => p[1] < 580).map(([x, y], i) => (
              <polygon key={i} points={`${x + dx - 13},${y + 17} ${x + dx},${y} ${x + dx + 13},${y + 17} ${x + dx + 5},${y + 13} ${x + dx - 3},${y + 18}`} fill="#F4F4FB" />
            ))}
          </g>
        );
      })}
    </g>
  );
};

const Pines = ({ off, color, base, h, step, seed }: { off: number; color: string; base: number; h: number; step: number; seed: number }) => {
  const n = Math.ceil(W / step) + 2;
  const o = wrap(off, step);
  return (
    <g fill={color}>
      {Array.from({ length: n }).map((_, i) => {
        const idx = i + Math.floor(off / step);
        const hh = h * (0.7 + (((Math.sin((idx + seed) * 7.13) * 1000) % 1) + 1) % 1 * 0.5);
        const x = i * step - o;
        return <polygon key={i} points={`${x - 11},${base} ${x},${base - hh} ${x + 11},${base}`} />;
      })}
    </g>
  );
};

const Log = ({ x, top, bottom }: { x: number; top: boolean; bottom: number }) => {
  const y0 = top ? -20 : bottom;
  const y1 = top ? bottom : GROUND;
  const capY = top ? y1 - 18 : y0;
  return (
    <g>
      <rect x={x - LOG_W / 2} y={y0} width={LOG_W} height={y1 - y0} fill="#A26D44" />
      <rect x={x - LOG_W / 2} y={y0} width={9} height={y1 - y0} fill="#B98356" />
      <rect x={x + LOG_W / 2 - 10} y={y0} width={10} height={y1 - y0} fill="#8A5B37" />
      <path d={`M${x - 10} ${y0} V${y1} M${x + 8} ${y0} V${y1}`} stroke="#8F5E39" strokeWidth={2} />
      <rect x={x - LOG_W / 2 - 4} y={capY} width={LOG_W + 8} height={18} rx={4} fill="#B98356" stroke="#8A5B37" strokeWidth={2} />
      <rect x={x - LOG_W / 2 - 4} y={top ? capY + 14 : capY - 3} width={LOG_W + 8} height={5} rx={2.5} fill="#5DBE4C" />
    </g>
  );
};

const Otter = ({ y, v }: { y: number; v: number }) => {
  const rot = Math.max(-24, Math.min(40, v * 0.06));
  return (
    <g transform={`translate(${OTTER_X} ${y}) rotate(${rot})`}>
      <path d="M-20 4 Q-36 10 -40 2 Q-32 0 -22 -2 Z" fill="#6E4422" />
      <ellipse cx="-2" cy="2" rx="21" ry="12" fill="#8B5A2B" />
      <ellipse cx="0" cy="7" rx="14" ry="6" fill="#C98E55" />
      <circle cx="17" cy="-5" r="11" fill="#8B5A2B" />
      <circle cx="11" cy="-14" r="3.4" fill="#6E4422" />
      <ellipse cx="23" cy="-1" rx="7" ry="5.4" fill="#E2B27E" />
      <circle cx="20" cy="-8" r="2.2" fill="#1B1B1B" />
      <circle cx="28" cy="-2.6" r="1.8" fill="#2A1A10" />
      <path d="M-4 12 q4 6 9 1" stroke="#6E4422" strokeWidth={3} strokeLinecap="round" fill="none" />
    </g>
  );
};

const RoundBtn = ({ x, y, children }: { x: number; y: number; children: React.ReactNode }) => (
  <g transform={`translate(${x} ${y})`}>
    <circle r="18" fill="rgba(20,30,45,0.28)" />
    {children}
  </g>
);

export const GameScene = ({ t, paused, menu }: { t: number; paused: number; menu: number }) => {
  const scroll = t * 150;
  const { y, v } = otterAt(t);
  const score = scoreAt(t);
  const first = Math.max(0, Math.floor((scroll - 500) / 230));
  const bob = Math.sin(t * 5) * 2;
  const s = 0.9 + 0.1 * menu;
  return (
    <svg width="100%" height="100%" viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="xMidYMid slice" style={{ display: "block" }}>
      <defs>
        <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#5FA8E4" />
          <stop offset="0.72" stopColor="#B7DDF3" />
        </linearGradient>
      </defs>
      <rect width={W} height={H} fill="url(#sky)" />
      <circle cx="318" cy="252" r="44" fill="#FFF3C4" opacity="0.55" />
      <circle cx="318" cy="252" r="27" fill="#FFE071" />
      <Cloud x={wrap(120 - scroll * 0.08, 520) - 60} y={190} />
      <Cloud x={wrap(330 - scroll * 0.08, 520) - 60} y={262} s={0.9} />
      <Cloud x={wrap(20 - scroll * 0.08, 520) - 60} y={392} s={0.7} />
      <Cloud x={wrap(460 - scroll * 0.08, 520) - 60} y={320} s={0.65} />
      <Mountains off={scroll * 0.15} />
      <Pines off={scroll * 0.3} color="#3E8C73" base={GROUND} h={70} step={17} seed={3} />
      <Pines off={scroll * 0.5} color="#1E6450" base={GROUND} h={52} step={21} seed={9} />
      {Array.from({ length: 5 }).map((_, k) => {
        const i = first + k;
        const x = pipeX(i, t);
        const gc = gapCenter(i);
        return (
          <g key={i}>
            <Log x={x} top bottom={gc - GAP / 2} />
            <Log x={x} top={false} bottom={gc + GAP / 2} />
          </g>
        );
      })}
      <rect x="0" y={GROUND} width={W} height={16} fill="#5DBE4C" />
      <rect x="0" y={GROUND} width={W} height={3} fill="#7AD066" />
      <rect x="0" y={GROUND + 16} width={W} height={H - GROUND - 16} fill="#3A8ED6" />
      {Array.from({ length: 28 }).map((_, i) => {
        const row = i % 4;
        const x = wrap(i * 53 + row * 21 - scroll * 0.9, W + 40) - 20;
        return <path key={i} d={`M${x} ${GROUND + 34 + row * 22} q6 -4 12 0`} stroke="#6DB2EA" strokeWidth={2} fill="none" strokeLinecap="round" />;
      })}
      <Otter y={y + (paused > 0 ? bob * 0 : 0)} v={v} />
      <text x={W / 2} y={200} textAnchor="middle" fontFamily={font.sans} fontWeight={800} fontSize={46} fill="#FFFFFF" stroke="#16263A" strokeWidth={6} paintOrder="stroke" strokeLinejoin="round">
        {score}
      </text>
      <RoundBtn x={AX.pause.x + 18} y={AX.pause.y + 18}>
        <rect x="-6" y="-7.5" width="4" height="15" rx="1.4" fill="#FFF" />
        <rect x="2" y="-7.5" width="4" height="15" rx="1.4" fill="#FFF" />
      </RoundBtn>
      <RoundBtn x={AX.sound.x + 18} y={AX.sound.y + 18}>
        <path d="M-8 -3.5h4l5 -4.5v16l-5 -4.5h-4z" fill="#FFF" />
        <path d="M4.5 -3.5q3 3.5 0 7M7 -6.5q5.5 6.5 0 13" stroke="#FFF" strokeWidth={1.8} fill="none" strokeLinecap="round" />
      </RoundBtn>
      {paused > 0 ? (
        <g opacity={paused}>
          <rect width={W} height={H} fill="rgba(12,26,42,0.42)" />
          <g transform={`translate(${W / 2} 418) scale(${s}) translate(${-W / 2} -418)`}>
            <rect x="84" y="294" width="225" height="246" rx="26" fill="#FFF8EC" stroke="#7A4B26" strokeWidth={4} />
            <text x={W / 2} y={AX.heading.y + 32} textAnchor="middle" fontFamily={font.sans} fontWeight={800} fontSize={30} letterSpacing={2} fill="#7A4B26">
              PAUSED
            </text>
            <rect x={AX.resume.x} y={AX.resume.y} width={AX.resume.w} height={AX.resume.h} rx="16" fill="#5DBE4C" stroke="#3E8D34" strokeWidth={3} />
            <text x={W / 2} y={AX.resume.y + 33} textAnchor="middle" fontFamily={font.sans} fontWeight={800} fontSize={20} letterSpacing={1} fill="#FFFFFF">
              RESUME
            </text>
            <rect x={AX.restart.x} y={AX.restart.y} width={AX.restart.w} height={AX.restart.h} rx="16" fill="#F1E1C6" stroke="#B98B5E" strokeWidth={3} />
            <text x={W / 2} y={AX.restart.y + 33} textAnchor="middle" fontFamily={font.sans} fontWeight={800} fontSize={20} letterSpacing={1} fill="#7A4B26">
              RESTART
            </text>
          </g>
        </g>
      ) : null}
    </svg>
  );
};
