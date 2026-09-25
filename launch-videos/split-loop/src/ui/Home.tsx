import React from 'react';
import {Img, staticFile} from 'remotion';
import {C, inter} from '../theme';
import {Icon, Sliders, ChevronDown, Apple, Ubuntu, Windows, Star, Check, ArrowUp, SidebarLeft} from '../icons';

export const HOME = {
  cardX: 258,
  cardY: 277,
  cardW: 688,
  cardH: 120,
  pickerX: 268,
  pickerY: 410,
};

export type HomeState = {
  text: string;
  caret: boolean;
  env: 'ubuntu' | 'macos';
  menu: number; // 0..1 open progress
  hover: 'none' | 'macos';
  sendPress: number; // 0..1
};

const Row: React.FC<{
  icon: React.ReactNode;
  label: string;
  extra?: React.ReactNode;
  checked?: boolean;
  hover?: boolean;
}> = ({icon, label, extra, checked, hover}) => (
  <div
    style={{
      height: 30,
      borderRadius: 6,
      display: 'flex',
      alignItems: 'center',
      padding: '0 10px 0 12px',
      gap: 10,
      background: hover ? C.fill06 : 'transparent',
    }}
  >
    {icon}
    <span style={{fontSize: 14, color: C.text, letterSpacing: -0.07}}>{label}</span>
    {extra}
    <div style={{flex: 1}} />
    {checked ? <Check size={16} opacity={0.56} /> : null}
  </div>
);

export const NewBadge: React.FC = () => (
  <div
    style={{
      height: 18,
      padding: '0 6px',
      borderRadius: 4,
      background: C.blue10,
      color: C.blue,
      fontSize: 11,
      fontWeight: 500,
      lineHeight: '18px',
      letterSpacing: -0.05,
    }}
  >
    New
  </div>
);

export const Home: React.FC<{s: HomeState}> = ({s}) => {
  const hasText = s.text.length > 0;
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        background: C.bg,
        fontFamily: inter,
        color: C.text,
      }}
    >
      <div style={{position: 'absolute', left: 13, top: 8}}>
        <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center'}}>
          <SidebarLeft size={18} />
        </div>
      </div>
      {/* Logo row */}
      <div
        style={{
          position: 'absolute',
          left: HOME.cardX + 8,
          top: 236,
          display: 'flex',
          alignItems: 'center',
          gap: 6,
        }}
      >
        <Img src={staticFile('devin-mark.png')} style={{width: 22, height: 25.2}} />
        <Img src={staticFile('devin-wordmark.png')} style={{width: 60, height: 19.1}} />
      </div>
      {/* Agent / Ask */}
      <div
        style={{
          position: 'absolute',
          left: 828,
          top: 240,
          height: 28,
          width: 112,
          borderRadius: 9999,
          background: C.fill04,
          display: 'flex',
          alignItems: 'center',
          padding: 1.5,
          fontSize: 13,
          letterSpacing: -0.065,
        }}
      >
        <div
          style={{
            height: 25,
            width: 60,
            borderRadius: 9999,
            background: C.white,
            border: `0.8px solid ${C.border08}`,
            boxShadow: '0 1px 2px rgba(0,0,0,0.04)',
            display: 'grid',
            placeItems: 'center',
            color: C.text,
          }}
        >
          Agent
        </div>
        <div style={{flex: 1, textAlign: 'center', color: C.text56}}>Ask</div>
      </div>
      {/* Prompt card */}
      <div
        style={{
          position: 'absolute',
          left: HOME.cardX,
          top: HOME.cardY,
          width: HOME.cardW,
          height: HOME.cardH,
          boxSizing: 'border-box',
          borderRadius: 20,
          background: C.white,
          border: `0.8px solid ${C.border08}`,
        }}
      >
        <div
          style={{
            position: 'absolute',
            left: 16,
            top: 17,
            fontSize: 14.6,
            lineHeight: '20px',
            letterSpacing: -0.07,
            color: hasText ? C.text : C.text56,
            whiteSpace: 'nowrap',
          }}
        >
          {hasText ? s.text : ''}
          {s.caret ? (
            <span
              style={{
                display: 'inline-block',
                width: 1.2,
                height: 17,
                background: C.text,
                verticalAlign: -3,
                marginLeft: 0.5,
              }}
            />
          ) : null}
          {hasText ? null : 'Ask Devin to build features, fix bugs, or work on your code'}
        </div>
        <div
          style={{
            position: 'absolute',
            left: 12,
            right: 13,
            bottom: 12,
            height: 28,
            display: 'flex',
            alignItems: 'center',
            gap: 1,
          }}
        >
          <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center'}}>
            <Icon name="plus" size={18} />
          </div>
          <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center'}}>
            <Icon name="slash" size={18} />
          </div>
          <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center'}}>
            <Sliders size={18} />
          </div>
          <div style={{marginLeft: 8, fontSize: 14, color: C.text56, letterSpacing: -0.07}}>
            Opus 5.5
          </div>
          <div style={{flex: 1}} />
          <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center'}}>
            <Icon name="mic" size={18} />
          </div>
          <div style={{width: 28, height: 28, display: 'grid', placeItems: 'center', marginRight: 4}}>
            <Icon name="voice" size={18} />
          </div>
          <div
            style={{
              width: 54,
              height: 28,
              borderRadius: 9999,
              background: C.black,
              opacity: hasText ? 1 : 0.55,
              display: 'flex',
              alignItems: 'center',
              transform: `scale(${1 - 0.06 * s.sendPress})`,
            }}
          >
            <div style={{width: 28, display: 'grid', placeItems: 'center'}}>
              <ArrowUp size={16} color="#fff" />
            </div>
            <div style={{width: 0.8, height: 16, background: 'rgba(255,255,255,0.18)'}} />
            <div style={{flex: 1, display: 'grid', placeItems: 'center'}}>
              <ChevronDown size={14} color="#fff" opacity={1} />
            </div>
          </div>
        </div>
      </div>
      {/* Environment picker */}
      <div
        style={{
          position: 'absolute',
          left: HOME.pickerX,
          top: HOME.pickerY,
          height: 24,
          display: 'flex',
          alignItems: 'center',
          gap: 5,
          padding: '0 6px',
          fontSize: 14,
          letterSpacing: -0.07,
          color: C.text,
        }}
      >
        {s.env === 'ubuntu' ? <Ubuntu size={14} /> : <Apple size={14} />}
        <span>{s.env === 'ubuntu' ? 'Ubuntu' : 'macOS'}</span>
        <ChevronDown size={14} opacity={0.7} />
      </div>
      {s.menu > 0 ? (
        <div
          style={{
            position: 'absolute',
            left: HOME.pickerX,
            top: HOME.pickerY + 30,
            width: 220,
            boxSizing: 'border-box',
            padding: 4,
            borderRadius: 10,
            background: C.white,
            border: `0.8px solid ${C.border08}`,
            boxShadow: '0 6px 20px rgba(0,0,0,0.08), 0 1px 3px rgba(0,0,0,0.05)',
            opacity: s.menu,
            transform: `translateY(${(1 - s.menu) * -4}px) scale(${0.98 + 0.02 * s.menu})`,
            transformOrigin: 'top left',
          }}
        >
          <div
            style={{
              height: 26,
              padding: '0 12px',
              display: 'flex',
              alignItems: 'center',
              fontSize: 12,
              fontWeight: 500,
              color: C.text56,
            }}
          >
            Hosted
          </div>
          <Row
            icon={<Ubuntu size={16} />}
            label="Ubuntu"
            extra={<Star filled size={14} />}
            checked={s.env === 'ubuntu'}
          />
          <Row
            icon={<Apple size={16} />}
            label="macOS"
            extra={<NewBadge />}
            checked={s.env === 'macos'}
            hover={s.hover === 'macos'}
          />
          <Row icon={<Windows size={15} />} label="Windows" />
        </div>
      ) : null}
    </div>
  );
};
