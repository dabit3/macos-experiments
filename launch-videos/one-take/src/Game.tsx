import React from "react";
import { rounded } from "./fonts";
import { GAME, T, otterAt, pipes, scoreAt } from "./timeline";
import { fadeIn } from "./anim";

const outline = (w: number): React.CSSProperties => ({ paintOrder: "stroke", stroke: "#2A211B", strokeWidth: w, strokeLinejoin: "round" });

const Otter: React.FC<{ x: number; y: number; rot: number; flap: number }> = ({ x, y, rot, flap }) => (
  <g transform={`translate(${x} ${y}) rotate(${rot})`}>
    <path d="M-20 4 C-34 6 -40 -2 -44 -8 C-36 -4 -28 -2 -18 -4 Z" fill="#6E4122" />
    <ellipse cx="-2" cy="2" rx="22" ry="13" fill="#8A5530" />
    <ellipse cx="2" cy="7" rx="14" ry="7" fill="#D9B085" />
    <path d={`M-8 ${8 + flap * 2} q-6 ${6 + flap * 3} -12 ${3 + flap * 2}`} stroke="#6E4122" strokeWidth="5" strokeLinecap="round" fill="none" />
    <circle cx="16" cy="-6" r="12" fill="#8A5530" />
    <circle cx="9" cy="-16" r="3.6" fill="#6E4122" />
    <ellipse cx="24" cy="-2" rx="7.5" ry="5.6" fill="#E4C49C" />
    <ellipse cx="29.5" cy="-4.5" rx="2.6" ry="2" fill="#2A1A10" />
    <circle cx="18" cy="-10" r="2.7" fill="#FFFFFF" />
    <circle cx="18.8" cy="-10" r="1.7" fill="#1B120C" />
  </g>
);

const Log: React.FC<{ x: number; top: number; bottom: number; cap: "top" | "bottom" }> = ({ x, top, bottom, cap }) => {
  const w = GAME.pipeW;
  const capY = cap === "top" ? bottom - 18 : top;
  return (
    <g>
      <rect x={x - w / 2} y={top} width={w} height={bottom - top} fill="#9A6337" />
      <rect x={x - w / 2 + 8} y={top} width={9} height={bottom - top} fill="#AE7646" />
      <rect x={x + 6} y={top} width={5} height={bottom - top} fill="#86532C" />
      <rect x={x + w / 2 - 10} y={top} width={10} height={bottom - top} fill="#7C4B27" />
      <rect x={x - w / 2 - 7} y={capY} width={w + 14} height={18} rx={4} fill="#A86F40" />
      <rect x={x - w / 2 - 7} y={cap === "top" ? capY + 14 : capY} width={w + 14} height={4} rx={2} fill="#7DC04A" />
    </g>
  );
};

const Cloud: React.FC<{ x: number; y: number; s: number }> = ({ x, y, s }) => (
  <g transform={`translate(${x} ${y}) scale(${s})`} fill="#FFFFFF">
    <ellipse cx="0" cy="8" rx="34" ry="12" />
    <circle cx="-10" cy="0" r="14" />
    <circle cx="10" cy="-4" r="17" />
  </g>
);

const wrap = (v: number, span: number) => ((v % span) + span) % span;

export const Game: React.FC<{ t: number }> = ({ t }) => {
  const g = t - T.gameStart;
  const playing = g >= 0;
  const gg = Math.max(0, g);
  const o = playing ? otterAt(gg) : { y: 420 + Math.sin(t * 3.2) * 9, v: Math.cos(t * 3.2) * 30 };
  const rot = playing ? Math.max(-24, Math.min(55, o.v * 0.05)) : Math.sin(t * 3.2) * -4;
  const flap = (Math.sin(t * 22) + 1) / 2;
  const titleA = 1 - fadeIn(t, T.gameStart, 0.25);
  const scoreA = fadeIn(t, T.gameStart + 0.05, 0.25);
  const scroll = gg * GAME.speed + t * 6;
  const mtnScroll = gg * 14;
  const treeScroll = gg * 42;

  return (
    <svg width="100%" height="100%" viewBox={`0 0 ${GAME.w} ${GAME.h}`} preserveAspectRatio="xMidYMid slice" style={{ display: "block" }}>
      <defs>
        <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#4DA6E6" />
          <stop offset="0.72" stopColor="#C2E1F1" />
        </linearGradient>
      </defs>
      <rect width={GAME.w} height={GAME.h} fill="url(#sky)" />
      <circle cx="300" cy="228" r="62" fill="#FFFFFF" opacity="0.32" />
      <circle cx="300" cy="228" r="34" fill="#F7D44E" />
      {[
        { x: 110, y: 214, s: 1, sp: 5 },
        { x: 322, y: 262, s: 0.9, sp: 7 },
        { x: 40, y: 420, s: 0.8, sp: 6 },
        { x: 380, y: 360, s: 0.7, sp: 4 },
      ].map((c, i) => (
        <Cloud key={i} x={wrap(c.x - t * c.sp - gg * 8, GAME.w + 120) - 60} y={c.y} s={c.s} />
      ))}
      {[0, 1, 2].map((k) => {
        const ox = -wrap(mtnScroll, 260) + k * 260 - 40;
        return (
          <g key={k} transform={`translate(${ox} 0)`}>
            <path d="M0 720 L80 600 L150 690 L215 610 L300 720 Z" fill="#8F93DA" />
            <path d="M80 600 L66 621 L80 616 L93 624 Z M215 610 L203 628 L215 622 L228 630 Z" fill="#FFFFFF" />
          </g>
        );
      })}
      {Array.from({ length: 16 }, (_, k) => {
        const x = -wrap(treeScroll, 30) + k * 30 - 20;
        const h = 60 + ((k * 37) % 5) * 9;
        return <path key={k} d={`M${x} 762 L${x + 14} ${762 - h} L${x + 28} 762 Z`} fill={k % 2 ? "#2E7B4E" : "#38905C"} />;
      })}
      {pipes.map((pp, k) => {
        const x = GAME.otterX + (pp.arrive - gg) * GAME.speed;
        if (!playing || x < -60 || x > GAME.w + 60) return null;
        return (
          <g key={k}>
            <Log x={x} top={-10} bottom={pp.gapC - GAME.gap / 2} cap="top" />
            <Log x={x} top={pp.gapC + GAME.gap / 2} bottom={GAME.ground} cap="bottom" />
          </g>
        );
      })}
      <rect x="0" y={GAME.ground} width={GAME.w} height="14" fill="#74C04B" />
      <rect x="0" y={GAME.ground + 12} width={GAME.w} height="3" fill="#5BA63B" />
      <rect x="0" y={GAME.ground + 15} width={GAME.w} height={GAME.h - GAME.ground} fill="#3F8FD4" />
      {Array.from({ length: 3 }, (_, row) =>
        Array.from({ length: 12 }, (_, k) => {
          const x = -wrap(scroll + row * 17, 40) + k * 40 - 20;
          const y = GAME.ground + 32 + row * 20;
          return <path key={`${row}-${k}`} d={`M${x} ${y} q10 -7 20 0`} stroke="#79B6EA" strokeWidth="2.5" fill="none" strokeLinecap="round" />;
        }),
      )}
      <Otter x={GAME.otterX} y={o.y} rot={rot} flap={flap} />
      <g transform="translate(352 150)">
        <circle r="18" fill="#000" opacity="0.12" />
        <path d="M-7 -3 h4 l5 -5 v16 l-5 -5 h-4 z" fill="#FFF" />
        <path d="M5 -4 q3 4 0 8" stroke="#FFF" strokeWidth="1.8" fill="none" strokeLinecap="round" />
      </g>
      {titleA > 0.001 ? (
        <g opacity={titleA} fontFamily={rounded} textAnchor="middle">
          <text x="195" y="345" fontSize="58" fontWeight="900" fill="#FFFFFF" style={outline(9)}>
            Otter Flap
          </text>
          <text x="195" y="386" fontSize="18" fontWeight="800" fill="#2A211B">
            Paddle through the driftwood
          </text>
          <text x="195" y="690" fontSize="23" fontWeight="900" fill="#FFFFFF" style={outline(6)}>
            Tap to flap
          </text>
          <rect x="155" y="714" width="80" height="30" rx="15" fill="#4A3426" opacity="0.72" />
          <text x="195" y="735" fontSize="16" fontWeight="800" fill="#F3DFC4">
            Best 3
          </text>
        </g>
      ) : null}
      {scoreA > 0 ? (
        <text x="195" y="178" textAnchor="middle" fontFamily={rounded} fontSize="66" fontWeight="900" fill="#FFFFFF" opacity={scoreA} style={outline(10)}>
          {scoreAt(gg)}
        </text>
      ) : null}
    </svg>
  );
};
