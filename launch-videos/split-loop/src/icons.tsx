import React from 'react';
import {Img, staticFile} from 'remotion';

const G = '#191919';

export const Icon: React.FC<{name: string; size: number; style?: React.CSSProperties}> = ({
  name,
  size,
  style,
}) => (
  <Img
    src={staticFile(`icons/${name}.svg`)}
    style={{width: size, height: size, display: 'block', flexShrink: 0, ...style}}
  />
);

type P = {size?: number; color?: string; opacity?: number};

const Svg: React.FC<P & {children: React.ReactNode; vb?: number}> = ({
  size = 18,
  color = G,
  opacity = 0.56,
  vb = 18,
  children,
}) => (
  <svg
    width={size}
    height={size}
    viewBox={`0 0 ${vb} ${vb}`}
    fill="none"
    stroke={color}
    strokeOpacity={opacity}
    strokeWidth={1.35}
    strokeLinecap="round"
    strokeLinejoin="round"
    style={{display: 'block', flexShrink: 0}}
  >
    {children}
  </svg>
);

export const SidebarLeft: React.FC<P> = (p) => (
  <Svg {...p}>
    <rect x="2.4" y="3.4" width="13.2" height="11.2" rx="2.2" />
    <path d="M6.6 3.6v10.8" />
  </Svg>
);

export const Sliders: React.FC<P & {dot?: boolean}> = ({dot = true, ...p}) => (
  <div style={{position: 'relative', width: p.size ?? 18, height: p.size ?? 18}}>
    <Svg {...p}>
      <circle cx="5.5" cy="6" r="1.9" />
      <path d="M5.5 8.2v6.4" />
      <circle cx="12.5" cy="12" r="1.9" />
      <path d="M12.5 3.4v6.4" />
    </Svg>
    {dot ? (
      <div
        style={{
          position: 'absolute',
          right: -1.5,
          top: -2.5,
          width: 6,
          height: 6,
          borderRadius: 9999,
          background: '#337DF4',
        }}
      />
    ) : null}
  </div>
);

export const ChevronDown: React.FC<P> = (p) => (
  <Svg vb={16} {...p}>
    <path d="M4.5 6.5 8 10l3.5-3.5" />
  </Svg>
);

export const Check: React.FC<P> = (p) => (
  <Svg vb={16} {...p}>
    <path d="m3.5 8.4 2.9 2.9 6.1-6.6" />
  </Svg>
);

export const ArrowUp: React.FC<P> = (p) => (
  <Svg vb={16} opacity={1} {...p}>
    <path d="M8 13V3.4M3.8 7.4 8 3.2l4.2 4.2" strokeWidth={1.5} />
  </Svg>
);

export const ArrowLeft: React.FC<P> = (p) => (
  <Svg {...p}>
    <path d="M14.5 9h-11M7.5 4.8 3.3 9l4.2 4.2" />
  </Svg>
);
export const ArrowRight: React.FC<P> = (p) => (
  <Svg {...p}>
    <path d="M3.5 9h11M10.5 4.8 14.7 9l-4.2 4.2" />
  </Svg>
);

export const SpeakerOff: React.FC<P> = (p) => (
  <Svg {...p}>
    <path d="M8.6 3.6 5.4 6.4H3.2v5.2h2.2l3.2 2.8V3.6Z" />
    <path d="M11.6 7.1c.5.5.8 1.2.8 1.9M13.8 5c1 1.1 1.6 2.5 1.6 4M2.5 2.5l13 13" />
  </Svg>
);

export const Popout: React.FC<P> = (p) => (
  <Svg {...p}>
    <rect x="2.5" y="4.5" width="10" height="10" rx="2" />
    <path d="M9.5 2.5h6v6M15.3 2.7 9 9" />
  </Svg>
);

export const Progress: React.FC<P> = (p) => (
  <Svg vb={16} {...p}>
    <path d="M9.2 14H4.4c-.8 0-1.4-.6-1.4-1.4V3.4C3 2.6 3.6 2 4.4 2h5.1L13 5.5v2.2" />
    <path d="M9.3 2v3.6H13M5.6 7.2h3.2M5.6 9.8h1.8" />
    <circle cx="11.2" cy="11.2" r="1.9" />
    <path d="m12.6 12.6 1.4 1.4" />
  </Svg>
);

export const Star: React.FC<P & {filled?: boolean}> = ({filled, size = 16, opacity = 0.56}) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{display: 'block'}}>
    <path
      d="m8 1.9 1.85 3.9 4.25.55-3.1 2.95.8 4.2L8 11.45 4.2 13.5l.8-4.2-3.1-2.95 4.25-.55L8 1.9Z"
      fill={filled ? G : 'none'}
      fillOpacity={opacity + 0.1}
      stroke={G}
      strokeOpacity={opacity + 0.1}
      strokeWidth={1.25}
      strokeLinejoin="round"
    />
  </svg>
);

export const Apple: React.FC<{size?: number; color?: string}> = ({size = 16, color = '#5c5c5c'}) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{display: 'block'}}>
    <path
      fill={color}
      d="M11.2 8.46c-.02-1.7 1.39-2.52 1.45-2.56-.79-1.16-2.02-1.32-2.46-1.34-1.05-.1-2.04.61-2.57.61-.53 0-1.35-.6-2.22-.58-1.14.02-2.2.66-2.78 1.69-1.19 2.06-.3 5.1.85 6.77.57.82 1.24 1.73 2.12 1.7.85-.03 1.17-.55 2.2-.55 1.02 0 1.31.55 2.21.53.91-.01 1.49-.83 2.05-1.65.65-.95.91-1.87.93-1.92-.02-.01-1.78-.68-1.8-2.7ZM9.53 3.46c.47-.57.78-1.35.7-2.14-.67.03-1.49.45-1.97 1.01-.43.5-.81 1.3-.71 2.07.75.06 1.51-.38 1.98-.94Z"
    />
  </svg>
);

export const Ubuntu: React.FC<{size?: number}> = ({size = 16}) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{display: 'block'}}>
    <g fill="none" stroke="#E95420" strokeWidth={1.7}>
      <path d="M10.6 3.4A5 5 0 0 0 3.2 7" />
      <path d="M3.2 9a5 5 0 0 0 7.4 3.6" />
      <path d="M12.6 10.6a5 5 0 0 0 0-5.2" />
    </g>
    <g fill="#E95420">
      <circle cx="2.4" cy="8" r="1.6" />
      <circle cx="11.2" cy="2.9" r="1.6" />
      <circle cx="11.2" cy="13.1" r="1.6" />
    </g>
  </svg>
);

export const Windows: React.FC<{size?: number}> = ({size = 16}) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{display: 'block'}}>
    <rect x="1.5" y="1.5" width="6.2" height="6.2" fill="#F25022" />
    <rect x="8.3" y="1.5" width="6.2" height="6.2" fill="#7FBA00" />
    <rect x="1.5" y="8.3" width="6.2" height="6.2" fill="#00A4EF" />
    <rect x="8.3" y="8.3" width="6.2" height="6.2" fill="#FFB900" />
  </svg>
);

export const GitHub: React.FC<{size?: number}> = ({size = 16}) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{display: 'block'}}>
    <path
      fill="#191919"
      d="M8 .2a8 8 0 0 0-2.53 15.59c.4.07.55-.17.55-.38v-1.49c-2.23.48-2.7-.94-2.7-.94-.36-.93-.89-1.17-.89-1.17-.73-.5.05-.49.05-.49.8.06 1.23.83 1.23.83.72 1.23 1.88.87 2.34.67.07-.52.28-.87.51-1.07-1.78-.2-3.65-.89-3.65-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82a7.6 7.6 0 0 1 4 0c1.53-1.03 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.28.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48v2.2c0 .21.15.46.55.38A8 8 0 0 0 8 .2Z"
    />
  </svg>
);

export const DevinMark: React.FC<{size: number; style?: React.CSSProperties}> = ({size, style}) => (
  <Img
    src={staticFile('devin-mark.png')}
    style={{width: size, height: (size * 780) / 680, display: 'block', ...style}}
  />
);
