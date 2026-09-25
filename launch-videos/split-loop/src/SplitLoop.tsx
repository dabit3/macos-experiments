import React from 'react';
import {AbsoluteFill, Freeze, OffthreadVideo, staticFile, useCurrentFrame} from 'remotion';
import './fonts';
import {C, FPS, S, VH, VW} from './theme';
import {f, mix, prog, quint, softOut, typedCount, typingSchedule, cubic} from './anim';
import {Home} from './ui/Home';
import {Session, COMPUTER_RECT, PROMPT, T} from './ui/Session';
import {TestViewer, VIDEO_RECT} from './ui/TestViewer';
import {Cursor, cursorAt, clickAmount, Waypoint} from './ui/Cursor';
import {EndCard} from './ui/EndCard';

export const DURATION = f(30.5);

const TYPE_START = 2.3;
const typing = typingSchedule(PROMPT, 29);

const CURSOR: Waypoint[] = [
  {t: 0.3, x: 760, y: 560},
  {t: 0.95, x: 301, y: 423, click: true},
  {t: 1.55, x: 330, y: 515},
  {t: 1.8, x: 331, y: 515, click: true},
  {t: 2.2, x: 560, y: 330, click: true},
  {t: 4.0, x: 600, y: 350},
  {t: 4.65, x: 893, y: 371},
  {t: 4.78, x: 893, y: 371, click: true},
  {t: 5.3, x: 893, y: 371},
  {t: 19.7, x: 905, y: 420},
  {t: 20.45, x: 176, y: 428},
  {t: 20.55, x: 176, y: 428, click: true},
];

/** Footage time (seconds into mac.mp4) shown in the Computer pane. */
const liveFootage = (now: number) => {
  if (now < T.boot) return 2.0;
  if (now < 12.65) return 2.0 + ((now - T.boot) * 7) / (12.65 - T.boot);
  return Math.min(19.05, 9 + (now - 12.65) * 1.5);
};
/** Recording playback time in the test viewer. */
const recTime = (now: number) => Math.min(14.5, Math.max(0, (now - 21.2) * 2.2));

const Footage: React.FC<{t: number}> = ({t}) => (
  <Freeze frame={Math.round(t * FPS)}>
    <OffthreadVideo
      muted
      src={staticFile('footage/mac.mp4')}
      style={{position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover'}}
    />
  </Freeze>
);

const camera = (frame: number) => {
  const toSplit = prog(frame, 4.85, 5.9, quint);
  const push = prog(frame, 22.2, 26.8, cubic);
  const z = mix(mix(1.34, 1.37, prog(frame, 0, 4.85, (x) => x)), 1, toSplit) * (1 + 0.07 * push);
  const cx = mix(mix(600, 600, toSplit), 820, push);
  const cy = mix(mix(334, VH / 2, toSplit), 330, push);
  return {z, cx, cy};
};

export const SplitLoop: React.FC = () => {
  const frame = useCurrentFrame();
  const now = frame / FPS;

  const typed = typedCount(frame, TYPE_START, typing);
  const typingActive = now > TYPE_START && typed < PROMPT.length;
  const focused = now > 2.2;
  const blink = Math.floor(frame / 32) % 2 === 0;
  const menuOpen = prog(frame, 1.0, 1.18, softOut);
  const menuClose = 1 - prog(frame, 1.84, 1.98, softOut);

  const homeOut = prog(frame, 4.9, 5.35, cubic);
  const sessionIn = prog(frame, 4.9, 5.45, cubic);
  const rightIn = prog(frame, 5.3, 6.3, quint);
  const merge = prog(frame, 20.6, 21.6, quint);
  const chrome = prog(frame, 20.95, 21.7, softOut);
  const viewerOut = prog(frame, 27.1, 27.7, cubic);
  const endLogo = prog(frame, 27.45, 28.3, softOut);
  const endLine = prog(frame, 28.0, 28.8, softOut);

  const cam = camera(frame);
  const scale = S * cam.z;
  const tx = 960 - cam.cx * scale;
  const ty = 540 - cam.cy * scale;

  const r = recTime(now);
  const swap = prog(frame, 20.8, 21.35, cubic);
  const rect = {
    x: mix(COMPUTER_RECT.x, VIDEO_RECT.x, merge),
    y: mix(COMPUTER_RECT.y, VIDEO_RECT.y, merge),
    w: mix(COMPUTER_RECT.w, VIDEO_RECT.w, merge),
    h: mix(COMPUTER_RECT.h, VIDEO_RECT.h, merge),
  };
  const footageVisible = now > 5.2 && viewerOut < 1;

  const cur = cursorAt(frame, CURSOR);
  const cursorOpacity =
    prog(frame, 0.25, 0.5) * (1 - prog(frame, 5.0, 5.3)) + prog(frame, 19.7, 19.95) * (1 - prog(frame, 20.8, 21.1));

  return (
    <AbsoluteFill style={{background: C.bg, overflow: 'hidden'}}>
      <div
        style={{
          position: 'absolute',
          left: 0,
          top: 0,
          width: VW,
          height: VH,
          transformOrigin: '0 0',
          transform: `translate(${tx}px, ${ty}px) scale(${scale})`,
          opacity: 1 - viewerOut,
        }}
      >
        {homeOut < 1 ? (
          <div style={{position: 'absolute', inset: 0, opacity: 1 - homeOut, transform: `translateY(${-homeOut * 10}px)`}}>
            <Home
              s={{
                text: PROMPT.slice(0, typed),
                caret: focused && now < 4.9 && (typingActive || blink),
                env: now < 1.8 ? 'ubuntu' : 'macos',
                menu: Math.min(menuOpen, menuClose),
                hover: now > 1.45 && now < 1.9 ? 'macos' : 'none',
                sendPress: clickAmount(frame, CURSOR.slice(7, 8)),
              }}
            />
          </div>
        ) : null}
        {sessionIn > 0 && merge < 1 ? (
          <div
            style={{
              position: 'absolute',
              inset: 0,
              opacity: sessionIn * (1 - merge),
              transform: `translateY(${(1 - sessionIn) * 10}px) translateX(${-merge * 24}px)`,
            }}
          >
            <Session frame={frame} rightIn={rightIn} thumb={<Footage t={10} />} />
          </div>
        ) : null}
        {chrome > 0 ? <TestViewer r={r} chrome={chrome} rowsIn={(i) => prog(frame, 21.25 + i * 0.09, 21.85 + i * 0.09, softOut)} /> : null}
        {footageVisible ? (
          <div
            style={{
              position: 'absolute',
              left: rect.x,
              top: rect.y,
              width: rect.w,
              height: rect.h,
              overflow: 'hidden',
              background: '#000',
              opacity: now < 7 ? rightIn : 1,
            }}
          >
            <Footage t={liveFootage(now)} />
            {swap > 0 ? (
              <div style={{position: 'absolute', inset: 0, opacity: swap}}>
                <Footage t={10.2 + r} />
              </div>
            ) : null}
          </div>
        ) : null}
        {cursorOpacity > 0 ? (
          <Cursor x={cur.x} y={cur.y} press={clickAmount(frame, CURSOR)} opacity={cursorOpacity} />
        ) : null}
      </div>
      {endLogo > 0 ? (
        <div style={{position: 'absolute', inset: 0, opacity: prog(frame, 27.2, 27.8, cubic)}}>
          <EndCard logo={endLogo} line={endLine} />
        </div>
      ) : null}
    </AbsoluteFill>
  );
};
