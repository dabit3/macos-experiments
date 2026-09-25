import React from 'react';
import {Img, staticFile} from 'remotion';
import {C, inter} from '../theme';

export const EndCard: React.FC<{logo: number; line: number}> = ({logo, line}) => (
  <div style={{position: 'absolute', inset: 0, background: '#FAFAFB', fontFamily: inter}}>
    <div
      style={{
        position: 'absolute',
        left: 0,
        right: 0,
        top: 396,
        display: 'flex',
        justifyContent: 'center',
        opacity: logo,
        transform: `translateY(${(1 - logo) * 14}px) scale(${0.985 + 0.015 * logo})`,
      }}
    >
      <Img src={staticFile('devin-lockup-black.png')} style={{width: 600, height: 206}} />
    </div>
    <div
      style={{
        position: 'absolute',
        left: 0,
        right: 0,
        top: 640,
        textAlign: 'center',
        fontSize: 34,
        fontWeight: 500,
        letterSpacing: -0.4,
        color: C.text56,
        opacity: line,
        transform: `translateY(${(1 - line) * 10}px)`,
      }}
    >
      Devin, now on macOS
    </div>
  </div>
);
