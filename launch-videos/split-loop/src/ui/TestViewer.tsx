import React from 'react';
import {C, inter, mono, VH, VW} from '../theme';
import {Icon} from '../icons';

export const VIDEO_RECT = {x: 0, y: 40, w: VW - 416, h: VH - 40 - 68};
export const REC_LEN = 15;

type Test = {t: number; title: string; setup?: boolean; checks: string[]};

export const TESTS: Test[] = [
  {t: 0, setup: true, title: 'Fresh install on iPhone 17 Simulator (iOS 26.5); default settings.', checks: []},
  {
    t: 1.5,
    title: 'It should start a run from the title screen',
    checks: ['Otter Flap title and “Tap to flap” shown; a tap starts the run at 0'],
  },
  {t: 3, title: 'It should flap the otter on each tap', checks: ['Each tap lifts the otter; gravity pulls it back down between taps']},
  {t: 4.5, title: 'It should score through the driftwood gaps', checks: ['Score climbs 1 → 3 as the otter clears each gap']},
  {t: 9.5, title: 'It should end the run on collision', checks: ['Splash! card shows the final score and best']},
  {t: 11.5, title: 'It should relaunch to the title screen', checks: ['Quit from Home and relaunched; Otter Flap title restored']},
];

const fmt = (s: number) => {
  const v = Math.max(0, Math.floor(s));
  return `${Math.floor(v / 60)}:${String(v % 60).padStart(2, '0')}`;
};

export const currentTest = (r: number) => {
  let i = 0;
  TESTS.forEach((t, k) => {
    if (r >= t.t) i = k;
  });
  return i;
};

const Btn: React.FC<{children: React.ReactNode; w?: number; active?: boolean}> = ({children, w = 28, active}) => (
  <div
    style={{
      minWidth: w,
      height: 28,
      borderRadius: 6,
      display: 'grid',
      placeItems: 'center',
      background: active ? 'rgba(0,0,0,0.06)' : 'transparent',
      padding: w === 28 ? 0 : '0 6px',
      boxSizing: 'border-box',
    }}
  >
    {children}
  </div>
);

export const TestViewer: React.FC<{r: number; chrome: number; rowsIn: (i: number) => number}> = ({
  r,
  chrome,
  rowsIn,
}) => {
  const cur = currentTest(r);
  const bounds = TESTS.map((t, i) => [t.t, i + 1 < TESTS.length ? TESTS[i + 1].t : REC_LEN]);
  const passed = TESTS.filter((t) => !t.setup).length;
  const trackW = VIDEO_RECT.w - 24;
  const gap = 2;
  const usable = trackW - gap * (TESTS.length - 1);
  return (
    <div style={{position: 'absolute', inset: 0, fontFamily: inter, color: C.text}}>
      <div style={{position: 'absolute', inset: 0, background: C.surface, opacity: chrome}} />
      {/* Title bar */}
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          top: 0,
          height: 40,
          borderBottom: `0.8px solid ${C.border06}`,
          boxSizing: 'border-box',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '0 12px 0 16px',
          opacity: chrome,
        }}
      >
        <span style={{fontSize: 13, lineHeight: '18px', fontWeight: 500, letterSpacing: -0.065}}>Otter Flap gameplay test</span>
        <div style={{width: 32, height: 32, display: 'grid', placeItems: 'center'}}>
          <Icon name="close" size={18} />
        </div>
      </div>
      {/* Timeline + controls */}
      <div
        style={{
          position: 'absolute',
          left: 0,
          top: VIDEO_RECT.y + VIDEO_RECT.h,
          width: VIDEO_RECT.w,
          height: 68,
          background: C.white,
          boxSizing: 'border-box',
          padding: '8px 12px 12px',
          opacity: chrome,
        }}
      >
        <div style={{display: 'flex', gap, height: 12}}>
          {bounds.map(([a, b], i) => {
            const w = ((b - a) / REC_LEN) * usable;
            const fill = Math.min(1, Math.max(0, (r - a) / (b - a)));
            const setup = TESTS[i].setup;
            const active = i === cur;
            return (
              <div
                key={i}
                style={{
                  position: 'relative',
                  width: w,
                  height: 12,
                  borderRadius: 4,
                  overflow: 'hidden',
                  background: setup ? 'rgba(107,114,128,0.2)' : C.mint20,
                }}
              >
                <div
                  style={{
                    position: 'absolute',
                    left: 0,
                    top: 0,
                    height: 12,
                    width: w * fill,
                    borderRadius: 4,
                    background: setup ? '#6B7280' : C.mint,
                    opacity: active ? 1 : 0.85,
                  }}
                />
              </div>
            );
          })}
        </div>
        <div style={{display: 'flex', alignItems: 'center', gap: 4, paddingTop: 8, height: 36, boxSizing: 'border-box'}}>
          <Btn><Icon name="prev" size={14} /></Btn>
          <Btn><Icon name="pause" size={16} /></Btn>
          <Btn><Icon name="next" size={14} /></Btn>
          <Btn w={0}>
            <span style={{fontFamily: mono, fontSize: 11, fontWeight: 500, color: C.text56, letterSpacing: 0.11}}>2x</span>
          </Btn>
          <Btn><Icon name="loop" size={16} /></Btn>
          <Btn><Icon name="download" size={16} /></Btn>
          <div style={{flex: 1}} />
          <div style={{display: 'flex', gap: 6, fontFamily: mono, fontSize: 11, lineHeight: '14px', letterSpacing: 0.11}}>
            <span style={{color: C.text}}>{TESTS[cur].setup ? 'Setup' : TESTS[cur].title}</span>
            <span style={{color: C.text40}}>|</span>
            <span style={{color: C.text56}}>
              {fmt(r)} / {fmt(REC_LEN)}
            </span>
          </div>
        </div>
      </div>
      {/* Results panel */}
      <div
        style={{
          position: 'absolute',
          left: VIDEO_RECT.w,
          top: 40,
          width: 416,
          bottom: 0,
          borderLeft: `0.8px solid ${C.border06}`,
          boxSizing: 'border-box',
          background: C.surface,
          overflow: 'hidden',
          opacity: chrome,
          transform: `translateX(${(1 - chrome) * 24}px)`,
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 12,
            padding: '10px 16px',
            borderBottom: `0.8px solid ${C.border06}`,
            fontSize: 12,
            lineHeight: '16px',
            color: C.text56,
          }}
        >
          <div style={{display: 'flex', alignItems: 'center', gap: 6}}>
            <div style={{width: 8, height: 8, borderRadius: 9999, background: C.green}} />
            {passed} passed
          </div>
          <div style={{display: 'flex', alignItems: 'center', gap: 6}}>
            <div style={{width: 8, height: 8, borderRadius: 9999, background: C.red}} />0 failed
          </div>
        </div>
        <div
          style={{
            padding: '12px 16px',
            borderBottom: `0.8px solid ${C.border06}`,
            fontSize: 12,
            lineHeight: '19.5px',
            color: C.text56,
          }}
        >
          Built Otter Flap, installed it on the iPhone 17 Simulator and played it with computer use: start, flap, score
          through the gaps, crash, then quit and relaunch. All five checks passed with no layout or input issues.
        </div>
        <div style={{padding: '4px 0'}}>
          {TESTS.map((t, i) => {
            const a = rowsIn(i);
            const active = i === cur;
            return (
              <div
                key={i}
                style={{
                  paddingTop: i === 0 ? 0 : 4,
                  opacity: a,
                  transform: `translateY(${(1 - a) * 8}px)`,
                }}
              >
                <div
                  style={{
                    display: 'flex',
                    gap: 8,
                    alignItems: 'center',
                    padding: '8px 12px',
                    background: active ? C.blue10 : 'transparent',
                  }}
                >
                  <div
                    style={{
                      width: 32,
                      textAlign: 'right',
                      fontFamily: mono,
                      fontSize: 11,
                      lineHeight: '14px',
                      letterSpacing: 0.11,
                      color: C.text40,
                    }}
                  >
                    {fmt(t.t)}
                  </div>
                  <div style={{width: 14, display: 'grid', placeItems: 'center'}}>
                    <Icon name={t.setup ? 'setup' : 'test'} size={14} />
                  </div>
                  <div
                    style={{
                      flex: 1,
                      fontSize: 13,
                      lineHeight: '17.875px',
                      fontWeight: t.setup ? 400 : 500,
                      letterSpacing: -0.065,
                      color: C.text,
                    }}
                  >
                    {t.title}
                  </div>
                </div>
                {t.checks.map((c, k) => (
                  <div key={k} style={{position: 'relative', display: 'flex', alignItems: 'center', padding: '6px 12px 6px 0'}}>
                    <div style={{width: 72}} />
                    <div
                      style={{
                        position: 'absolute',
                        left: 59,
                        top: 0,
                        width: 8,
                        height: 16,
                        borderLeft: `0.8px solid ${C.border06}`,
                        borderBottom: `0.8px solid ${C.border06}`,
                        borderBottomLeftRadius: 6,
                      }}
                    />
                    <div style={{width: 14, display: 'grid', placeItems: 'center'}}>
                      <Icon name="check-green" size={14} />
                    </div>
                    <div style={{flex: 1, paddingLeft: 8, fontSize: 12, lineHeight: '16.5px', color: C.text}}>{c}</div>
                  </div>
                ))}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};
