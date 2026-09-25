import React from 'react';
import {Img, staticFile} from 'remotion';
import {FPS} from '../theme';
import {cubic, mix} from '../anim';

export type Waypoint = {t: number; x: number; y: number; click?: boolean};

export const cursorAt = (frame: number, pts: Waypoint[]) => {
  const now = frame / FPS;
  if (now <= pts[0].t) return {x: pts[0].x, y: pts[0].y};
  for (let i = 0; i < pts.length - 1; i++) {
    const a = pts[i];
    const b = pts[i + 1];
    if (now <= b.t) {
      const p = cubic((now - a.t) / (b.t - a.t));
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const arc = Math.sin(Math.PI * p) * 0.12;
      return {x: mix(a.x, b.x, p) - dy * arc, y: mix(a.y, b.y, p) + dx * arc};
    }
  }
  const l = pts[pts.length - 1];
  return {x: l.x, y: l.y};
};

export const clickAmount = (frame: number, pts: Waypoint[]) => {
  const now = frame / FPS;
  let v = 0;
  for (const p of pts) {
    if (!p.click) continue;
    const d = now - p.t;
    if (d > -0.08 && d < 0.14) v = Math.max(v, 1 - Math.abs(d - 0.02) / 0.12);
  }
  return Math.max(0, v);
};

export const Cursor: React.FC<{x: number; y: number; press: number; opacity: number}> = ({x, y, press, opacity}) => (
  <div
    style={{
      position: 'absolute',
      left: x - 6,
      top: y - 4,
      width: 20,
      height: 24,
      opacity,
      transform: `scale(${1 - press * 0.12})`,
      transformOrigin: '6px 4px',
      pointerEvents: 'none',
    }}
  >
    <Img src={staticFile('icons/cursor.svg')} style={{position: 'absolute', left: -4, top: -3, width: 28, height: 32}} />
  </div>
);
