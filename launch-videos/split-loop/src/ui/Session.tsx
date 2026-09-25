import React from 'react';
import {C, inter, VH} from '../theme';
import {Icon, SidebarLeft, ChevronDown, GitHub, DevinMark, Progress, ArrowLeft, ArrowRight, SpeakerOff, Popout} from '../icons';
import {prog, softOut} from '../anim';
import {FPS} from '../theme';

export const LEFT_W = 616;
export const COMPUTER_RECT = {x: 624, y: 116, w: 568, h: 568 / 1.3313};
const CHAT_X = 24;
const CHAT_W = 572;
const HEADER_H = 44;
const INPUT_TOP = VH - 8 - 107.6;

export const PROMPT = 'Build Flappy Bird with an Otter. Then build and test it on iOS.';

const txt14: React.CSSProperties = {fontSize: 14, lineHeight: '20px', letterSpacing: -0.07};
const txt13: React.CSSProperties = {fontSize: 13, lineHeight: '18px', letterSpacing: -0.065};

type RowDef = {t: number; h: number; group?: boolean; node: React.ReactNode};

const Muted: React.FC<{children: React.ReactNode}> = ({children}) => (
  <span style={{...txt13, color: C.text56}}>{children}</span>
);

const StepRow: React.FC<{icon: React.ReactNode; children: React.ReactNode}> = ({icon, children}) => (
  <div style={{display: 'flex', gap: 8, alignItems: 'flex-start'}}>
    <div style={{width: 16, height: 17, paddingTop: 1, display: 'grid', placeItems: 'center'}}>{icon}</div>
    <div style={{display: 'flex', gap: 8, alignItems: 'center'}}>{children}</div>
  </div>
);

const Cmd: React.FC<{text: string; dur?: string; done: boolean}> = ({text, dur, done}) => (
  <div style={{display: 'flex', gap: 16, alignItems: 'flex-start'}}>
    <div style={{...txt14, lineHeight: '18px', color: done ? C.text56 : C.text, flex: 1, wordBreak: 'break-word'}}>{text}</div>
    <div style={{...txt13, color: C.text40, width: 26, textAlign: 'right', opacity: done ? 1 : 0}}>{dur}</div>
  </div>
);

const Think: React.FC<{text: string}> = ({text}) => (
  <div style={{...txt14, lineHeight: '18px', color: C.text56}}>{text}</div>
);

export const RecordingCard: React.FC<{thumb: React.ReactNode; passed: number}> = ({thumb, passed}) => (
  <div
    style={{
      width: 300,
      boxSizing: 'border-box',
      background: C.fill04,
      borderRadius: 14,
      padding: '0 6px 6px',
    }}
  >
    <div style={{height: 40, display: 'flex', alignItems: 'center', gap: 8, padding: '0 8px'}}>
      <Icon name="video" size={16} />
      <span style={{...txt13, fontWeight: 500, color: C.text}}>Otter Flap gameplay test</span>
      <span style={{...txt13, color: C.text56}}>{passed} passed</span>
    </div>
    <div
      style={{
        position: 'relative',
        height: 216,
        borderRadius: 8,
        overflow: 'hidden',
        background: '#fff',
        border: `0.8px solid ${C.border06}`,
        boxShadow: '0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.06)',
      }}
    >
      {thumb}
      <div style={{position: 'absolute', inset: 0, display: 'grid', placeItems: 'center'}}>
        <div
          style={{
            width: 48,
            height: 48,
            borderRadius: 9999,
            background: 'rgba(31,31,31,0.94)',
            border: '0.8px solid rgba(255,255,255,0.04)',
            boxShadow: '0 1px 3px rgba(0,0,0,0.25), 0 1px 2px rgba(0,0,0,0.06)',
            display: 'grid',
            placeItems: 'center',
            paddingLeft: 1,
            boxSizing: 'border-box',
          }}
        >
          <Icon name="play-white" size={20} />
        </div>
      </div>
    </div>
  </div>
);

/** Timeline for the chat, in seconds. */
export const T = {
  user: 5.2,
  reply: 5.85,
  worked: 6.75,
  para: 7.05,
  group: 7.4,
  brew: 7.7,
  thought: 8.35,
  build: 8.8,
  boot: 9.6,
  install: 11.9,
  rec: 12.8,
  tap1: 14.2,
  tap2: 16.3,
  tap3: 18.5,
  stop: 19.35,
  card: 19.6,
};

const REPLY =
  'On it — building an otter Flappy Bird iOS game in dabit3/experiments, then building and testing it on the iOS simulator.';

export const Session: React.FC<{frame: number; thumb: React.ReactNode; rightIn: number}> = ({
  frame,
  thumb,
  rightIn,
}) => {
  const now = frame / FPS;
  const replyWords = REPLY.split(' ');
  const shownWords = Math.floor(
    replyWords.length * prog(frame, T.reply, T.reply + 0.75, (x) => x),
  );
  const workingSecs = Math.max(0, Math.floor(12 + (now - T.group) * 2.2));
  const workingLabel =
    workingSecs >= 60 ? `Working for ${Math.floor(workingSecs / 60)}m ${workingSecs % 60}s` : `Working for ${workingSecs}s`;

  const rows: RowDef[] = [
    {
      t: T.user,
      h: 128,
      node: (
        <div style={{paddingTop: 16, display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 8}}>
          <div style={{...txt14, background: 'rgba(0,0,0,0.05)', borderRadius: 14, padding: '8px 14px', color: C.text}}>
            {PROMPT}
          </div>
          <div
            style={{
              width: 200,
              height: 46,
              boxSizing: 'border-box',
              borderRadius: 12,
              background: 'rgba(0,0,0,0.05)',
              display: 'flex',
              alignItems: 'flex-start',
              padding: 6,
              gap: 10,
            }}
          >
            <div
              style={{
                width: 34,
                height: 34,
                borderRadius: 8,
                background: 'rgba(0,0,0,0.05)',
                display: 'grid',
                placeItems: 'center',
              }}
            >
              <GitHub size={14} />
            </div>
            <span style={{...txt13, fontWeight: 500, color: C.text, paddingTop: 7}}>dabit3/experiments</span>
          </div>
        </div>
      ),
    },
    {
      t: T.reply,
      h: 62,
      node: (
        <div style={{...txt14, color: C.text, paddingTop: 2}}>
          {replyWords.map((w, i) => (
            <span key={i} style={{opacity: i < shownWords ? 1 : 0}}>
              {w}{' '}
            </span>
          ))}
        </div>
      ),
    },
    {
      t: T.worked,
      h: 38,
      node: (
        <StepRow icon={<Icon name="chevron-right" size={16} />}>
          <Muted>Worked for 38s</Muted>
          <span style={{...txt13, color: C.green, padding: '0 4px'}}>+412</span>
        </StepRow>
      ),
    },
    {
      t: T.para,
      h: 42,
      node: <div style={{...txt14, color: C.text, paddingTop: 2}}>Game scaffolded in SpriteKit. Building it for the iOS Simulator next.</div>,
    },
    {
      t: T.group,
      h: 30,
      node: (
        <StepRow icon={<ChevronDown size={16} />}>
          <Muted>{workingLabel}</Muted>
        </StepRow>
      ),
    },
    {
      t: T.brew,
      h: 46,
      group: true,
      node: (
        <Cmd
          text="brew install xcodegen 2>&1 | tail -3; xcrun simctl list devices available | rg -i iphone | head"
          dur="8s"
          done={now > T.thought}
        />
      ),
    },
    {
      t: T.thought,
      h: 28,
      group: true,
      node: (
        <div style={{display: 'flex', alignItems: 'center', gap: 4}}>
          <span style={{...txt14, lineHeight: '18px', color: C.text56}}>Thought for 6s</span>
          <Icon name="chevron-right" size={14} />
        </div>
      ),
    },
    {
      t: T.build,
      h: 46,
      group: true,
      node: (
        <Cmd
          text="xcodegen generate && xcodebuild -scheme OtterFlap -destination 'platform=iOS Simulator,name=iPhone 17' build"
          dur="21s"
          done={now > T.boot}
        />
      ),
    },
    {
      t: T.boot,
      h: 28,
      group: true,
      node: <Cmd text={'xcrun simctl boot "iPhone 17" && open -a Simulator'} dur="6s" done={now > T.install} />,
    },
    {
      t: T.install,
      h: 46,
      group: true,
      node: (
        <Cmd
          text="xcrun simctl install booted build/OtterFlap.app && xcrun simctl launch booted com.dabit3.otterflap"
          dur="4s"
          done={now > T.rec}
        />
      ),
    },
    {
      t: T.rec,
      h: 28,
      group: true,
      node: (
        <div style={{display: 'flex', alignItems: 'center', gap: 8}}>
          <Icon name="record" size={16} />
          <span style={{...txt14, lineHeight: '18px', color: C.text56}}>Started recording</span>
        </div>
      ),
    },
    {t: T.tap1, h: 28, group: true, node: <Think text="Tapped “Tap to flap” — the run starts at score 0." />},
    {t: T.tap2, h: 28, group: true, node: <Think text="The otter clears the first driftwood gap; score is 1." />},
    {t: T.tap3, h: 28, group: true, node: <Think text="Collision shows the Splash! card with the final score." />},
    {
      t: T.stop,
      h: 30,
      node: (
        <StepRow icon={<Icon name="record" size={16} />}>
          <Muted>Stopped recording</Muted>
        </StepRow>
      ),
    },
    {
      t: T.card,
      h: 276,
      node: (
        <div style={{paddingTop: 4}}>
          <RecordingCard thumb={thumb} passed={5} />
        </div>
      ),
    },
  ];

  const status =
    now < T.boot ? 'Preparing iOS build tools' : now < T.install ? 'Booting iOS Simulator' : now < T.rec ? 'Launching Otter Flap' : 'Testing with computer use';
  const statusIn = prog(frame, T.group, T.group + 0.4, softOut) * (1 - prog(frame, T.stop - 0.1, T.stop + 0.2));

  let total = 0;
  const laid = rows.map((r) => {
    const p = prog(frame, r.t, r.t + 0.5, softOut);
    const y = total;
    total += r.h * p;
    return {...r, p, y};
  });
  const statusH = 36 * statusIn;
  const viewH = INPUT_TOP - HEADER_H - 8;
  const scroll = Math.max(0, total + statusH - viewH);

  // Contiguous "group" rule under the Working header.
  const groupRows = laid.filter((r) => r.group && r.p > 0);
  const ruleTop = groupRows.length ? groupRows[0].y : 0;
  const last = groupRows[groupRows.length - 1];
  const ruleBottom = last ? last.y + last.h * last.p - 10 : 0;

  return (
    <div style={{position: 'absolute', inset: 0, background: C.bg, fontFamily: inter, color: C.text}}>
      {/* Left: chat */}
      <div style={{position: 'absolute', left: 0, top: 0, width: LEFT_W, height: VH, overflow: 'hidden'}}>
        <div style={{position: 'absolute', left: 0, right: 0, top: 0, height: HEADER_H, display: 'flex', alignItems: 'center', padding: '0 7px 0 13px', zIndex: 2, background: C.bg}}>
          <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center'}}>
            <SidebarLeft size={18} />
          </div>
          <div style={{...txt13, marginLeft: 11, color: C.text}}>Create Otter Flappy Bird iOS App</div>
          <div
            style={{
              marginLeft: 6,
              height: 20,
              padding: '0 6px',
              borderRadius: 4,
              background: C.blue10,
              display: 'flex',
              alignItems: 'center',
              gap: 4,
            }}
          >
            <Icon name="macos" size={14} />
            <span style={{fontSize: 12, lineHeight: '16px', fontWeight: 500, color: C.blue, letterSpacing: -0.065}}>macOS</span>
          </div>
          <div style={{flex: 1}} />
          {['session-info', 'flag', 'more'].map((n) => (
            <div key={n} style={{width: 28, height: 28, display: 'grid', placeItems: 'center', marginLeft: 1}}>
              <Icon name={n} size={18} />
            </div>
          ))}
        </div>
        <div
          style={{
            position: 'absolute',
            left: CHAT_X,
            width: CHAT_W,
            top: HEADER_H,
            height: viewH,
            overflow: 'hidden',
          }}
        >
          <div style={{position: 'absolute', left: 0, right: 0, top: -scroll}}>
            {groupRows.length ? (
              <div
                style={{
                  position: 'absolute',
                  left: 7.6,
                  top: ruleTop,
                  width: 0.8,
                  height: Math.max(0, ruleBottom - ruleTop),
                  background: C.border08,
                }}
              />
            ) : null}
            {laid.map((r, i) =>
              r.p <= 0 ? null : (
                <div
                  key={i}
                  style={{
                    position: 'absolute',
                    top: r.y,
                    left: r.group ? 24 : 0,
                    right: 0,
                    height: r.h,
                    opacity: r.p,
                    transform: `translateY(${(1 - r.p) * 6}px)`,
                  }}
                >
                  {r.node}
                </div>
              ),
            )}
            <div
              style={{
                position: 'absolute',
                top: total + 6,
                left: 0,
                display: 'flex',
                alignItems: 'center',
                gap: 10,
                opacity: statusIn,
              }}
            >
              <DevinMark size={15} style={{transform: `rotate(${Math.sin(frame / 18) * 6}deg)`}} />
              <span style={{...txt14, color: C.text56}}>{status}</span>
            </div>
          </div>
        </div>
        {/* Input */}
        <div style={{position: 'absolute', left: 8, right: 8, top: INPUT_TOP, padding: '0 6px'}}>
          <div
            style={{
              height: 107.6,
              boxSizing: 'border-box',
              borderRadius: 20,
              background: C.white,
              border: `0.8px solid ${C.border08}`,
              padding: 12,
              position: 'relative',
            }}
          >
            <div style={{...txt14, color: C.text56, padding: 4, display: 'flex', alignItems: 'center'}}>
              Guide Devin while it works, or press
              {['cmd', 'enter'].map((k) => (
                <span key={k} style={{width: 16, height: 16, borderRadius: 2, background: C.fill06, display: 'inline-grid', placeItems: 'center', marginLeft: 3}}>
                  <Icon name={k} size={12} />
                </span>
              ))}
              <span style={{marginLeft: 4}}>to queue</span>
            </div>
            <div style={{position: 'absolute', left: 8, right: 12, bottom: 8, height: 36, display: 'flex', alignItems: 'center', gap: 1, padding: 4, boxSizing: 'border-box'}}>
              <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center'}}><Icon name="plus" size={18} /></div>
              <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center'}}><Icon name="slash" size={18} /></div>
              <div style={{...txt13, color: C.text56, padding: '0 6px'}}>Opus 5.5 (Preview)</div>
              <div style={{flex: 1}} />
              <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center'}}><Icon name="mic" size={18} /></div>
              <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center', marginRight: 4}}><Icon name="voice" size={18} /></div>
              <div style={{width: 28, height: 28, borderRadius: 9999, background: C.black, display: 'grid', placeItems: 'center'}}>
                <div style={{width: 10, height: 10, borderRadius: 2, background: '#fff', opacity: 0.92}} />
              </div>
            </div>
          </div>
        </div>
      </div>
      {/* Divider */}
      <div style={{position: 'absolute', left: LEFT_W, top: 0, width: 0.8, height: VH, background: C.border08, opacity: rightIn}} />
      {/* Right: Devin's Mac */}
      <div
        style={{
          position: 'absolute',
          left: LEFT_W + 0.8,
          top: 0,
          right: 0,
          height: VH,
          opacity: rightIn,
          transform: `translateX(${(1 - rightIn) * 40}px)`,
        }}
      >
        <div style={{position: 'absolute', left: 8, right: 8, top: 8, height: 28, display: 'flex', alignItems: 'center', gap: 4}}>
          <div style={{height: 28, display: 'flex', alignItems: 'center', gap: 2, padding: '3px 6px 3px 3px', boxSizing: 'border-box', borderRadius: 6}}>
            <div style={{width: 22, height: 22, display: 'grid', placeItems: 'center'}}><Progress size={16} /></div>
            <span style={{...txt13, color: C.text56}}>Progress</span>
          </div>
          <div style={{height: 28, display: 'flex', alignItems: 'center', gap: 2, padding: '3px 6px 3px 3px', boxSizing: 'border-box', borderRadius: 6, background: C.fill06}}>
            <div style={{width: 22, height: 22, display: 'grid', placeItems: 'center'}}><Icon name="computer" size={16} /></div>
            <span style={{...txt13, color: C.text}}>Computer</span>
          </div>
          <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center', marginLeft: 4}}><Icon name="plus-tab" size={18} /></div>
          <div style={{flex: 1}} />
          <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center'}}><Icon name="expand" size={18} /></div>
          <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center'}}><Icon name="sidebar-right" size={18} /></div>
        </div>
        <div style={{position: 'absolute', left: 8, right: 8, top: 606, height: 8, borderRadius: 2, background: 'rgba(51,125,244,0.24)'}}>
          <div style={{position: 'absolute', right: 0, top: -2, width: 2, height: 12, borderRadius: 1, background: C.blue}} />
        </div>
        <div style={{position: 'absolute', left: 8, right: 8, top: 628, height: 32, display: 'flex', alignItems: 'center', gap: 4}}>
          <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center'}}><ArrowLeft size={18} /></div>
          <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center'}}><ArrowRight size={18} /></div>
          <div style={{height: 28, marginLeft: 6, padding: '0 10px', boxSizing: 'border-box', borderRadius: 9999, border: `0.8px solid ${C.border08}`, display: 'flex', alignItems: 'center', gap: 6}}>
            <div style={{width: 8, height: 8, borderRadius: 9999, background: C.red}} />
            <span style={{...txt13, color: C.text}}>Live</span>
          </div>
          <div style={{flex: 1}} />
          <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center'}}><SpeakerOff size={17} /></div>
          <div style={{...txt13, color: C.text56, display: 'flex', alignItems: 'center', gap: 4, padding: '0 8px'}}>
            Auto (reduced) <ChevronDown size={14} />
          </div>
          <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center'}}><Popout size={17} /></div>
        </div>
      </div>
    </div>
  );
};

