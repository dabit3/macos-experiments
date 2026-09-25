import type { CSSProperties, ReactNode } from "react";
import { c } from "./theme";

type P = { size?: number; color?: string; style?: CSSProperties; sw?: number };

const S = ({ size = 18, color = c.icon, style, sw = 1.5, children, vb = 24 }: P & { children: ReactNode; vb?: number }) => (
  <svg width={size} height={size} viewBox={`0 0 ${vb} ${vb}`} fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" style={{ display: "block", flexShrink: 0, ...style }}>
    {children}
  </svg>
);

export const IconSidebar = (p: P) => (
  <S {...p}><rect x="3" y="4.5" width="18" height="15" rx="2.5" /><path d="M9 4.5v15" /></S>
);
export const IconPanelRight = (p: P) => (
  <S {...p}><rect x="3" y="4.5" width="18" height="15" rx="2.5" /><path d="M15 4.5v15" /></S>
);
export const IconPlus = (p: P) => (<S {...p}><path d="M12 4v16M4 12h16" /></S>);
export const IconSlash = (p: P) => (
  <S {...p}><rect x="4" y="4" width="16" height="16" rx="2.5" /><path d="M13.8 8 10.2 16" /></S>
);
export const IconSliders = ({ dot = true, ...p }: P & { dot?: boolean }) => (
  <div style={{ position: "relative", width: p.size ?? 18, height: p.size ?? 18 }}>
    <S {...p}>
      <path d="M7 3v8M17 13v8M7 17v4M17 3v4" />
      <circle cx="7" cy="14" r="2.6" />
      <circle cx="17" cy="10" r="2.6" />
    </S>
    {dot ? <div style={{ position: "absolute", right: -3, top: -3, width: 6.5, height: 6.5, borderRadius: 9, background: "#2F6FEB" }} /> : null}
  </div>
);
export const IconMic = (p: P) => (
  <S {...p}><rect x="9" y="3" width="6" height="11" rx="3" /><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21" /></S>
);
export const IconWave = (p: P) => (
  <S {...p}><path d="M4 10v4M8 7v10M12 4v16M16 8v8M20 10.5v3" /></S>
);
export const IconArrowUp = (p: P) => (<S {...p}><path d="M12 19V5M6 11l6-6 6 6" /></S>);
export const IconChevronDown = (p: P) => (<S {...p}><path d="m6 9 6 6 6-6" /></S>);
export const IconChevronRight = (p: P) => (<S {...p}><path d="m9 6 6 6-6 6" /></S>);
export const IconCheck = (p: P) => (<S {...p}><path d="m5 12.5 4.5 4.5L19 7.5" /></S>);
export const IconList = (p: P) => (
  <S {...p}><circle cx="5" cy="7" r="1.4" /><circle cx="5" cy="17" r="1.4" /><path d="M10 7h10M10 17h10" /></S>
);
export const IconFlag = (p: P) => (<S {...p}><path d="M5 21V4h11l-1.5 4L16 12H5" /></S>);
export const IconDots = (p: P) => (
  <S {...p} sw={2.2}><path d="M5 12h.01M12 12h.01M19 12h.01" /></S>
);
export const IconExpand = (p: P) => (<S {...p}><path d="M14 4h6v6M10 20H4v-6M20 4l-6.5 6.5M4 20l6.5-6.5" /></S>);
export const IconArrowLeft = (p: P) => (<S {...p}><path d="M19 12H5M11 6l-6 6 6 6" /></S>);
export const IconArrowRight = (p: P) => (<S {...p}><path d="M5 12h14M13 6l6 6-6 6" /></S>);
export const IconMute = (p: P) => (
  <S {...p}><path d="M4 20 20 4M9 16H6a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1h3l5-4v5M14 14v6l-3-2.4" /></S>
);
export const IconPopout = (p: P) => (
  <S {...p}><rect x="3" y="7" width="12" height="12" rx="2" /><path d="M9 3h10a2 2 0 0 1 2 2v10M13 11l8-8" /></S>
);
export const IconProgress = (p: P) => (
  <S {...p}><path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h4" /><path d="M9 8h6M9 12h3" /><circle cx="16.5" cy="16.5" r="3" /><path d="m18.8 18.8 2.2 2.2" /></S>
);
export const IconComputer = (p: P) => (
  <S {...p}><rect x="3" y="4" width="18" height="13" rx="2" /><path d="M8 21h8M12 17v4" /><path d="m10 9 4 2.5-3 .5-.5 2.5z" /></S>
);
export const IconLaptop = (p: P) => (
  <S {...p}><rect x="4" y="5" width="16" height="11" rx="1.5" /><path d="M2 19h13" /><rect x="15" y="12" width="6" height="9" rx="1.2" fill="#E1EBFA" /></S>
);
export const IconClose = (p: P) => (<S {...p}><path d="M6 6l12 12M18 6 6 18" /></S>);

export const IconApple = ({ size = 16, color = "#1A1A1A" }: P) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: "block", flexShrink: 0 }}>
    <path fill={color} d="M16.37 12.62c-.02-2.35 1.92-3.48 2.01-3.54-1.1-1.6-2.8-1.82-3.4-1.85-1.44-.15-2.82.85-3.55.85-.74 0-1.86-.83-3.06-.81-1.57.02-3.02.92-3.83 2.33-1.64 2.84-.42 7.03 1.17 9.33.78 1.13 1.7 2.39 2.91 2.35 1.17-.05 1.61-.76 3.03-.76 1.41 0 1.81.76 3.05.73 1.26-.02 2.06-1.14 2.82-2.28.9-1.31 1.26-2.59 1.28-2.66-.03-.01-2.45-.94-2.43-3.69zM14.05 5.73c.64-.78 1.08-1.86.96-2.94-.93.04-2.06.62-2.72 1.4-.6.69-1.12 1.8-.98 2.86 1.04.08 2.1-.53 2.74-1.32z" />
  </svg>
);

export const IconUbuntu = ({ size = 16 }: P) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: "block", flexShrink: 0 }} fill="none">
    <circle cx="12" cy="12" r="6.4" stroke="#E95420" strokeWidth="2.3" />
    <circle cx="4.6" cy="12" r="2.4" fill="#E95420" stroke="#F9F9F9" strokeWidth="1.2" />
    <circle cx="15.7" cy="5.6" r="2.4" fill="#E95420" stroke="#F9F9F9" strokeWidth="1.2" />
    <circle cx="15.7" cy="18.4" r="2.4" fill="#E95420" stroke="#F9F9F9" strokeWidth="1.2" />
  </svg>
);

export const IconWindows = ({ size = 16 }: P) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: "block", flexShrink: 0 }}>
    <rect x="3" y="3" width="8.5" height="8.5" fill="#F35325" />
    <rect x="12.5" y="3" width="8.5" height="8.5" fill="#81BC06" />
    <rect x="3" y="12.5" width="8.5" height="8.5" fill="#05A6F0" />
    <rect x="12.5" y="12.5" width="8.5" height="8.5" fill="#FFBA08" />
  </svg>
);

export const IconGithub = ({ size = 16, color = "#1A1A1A" }: P) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: "block" }}>
    <path fill={color} d="M12 2C6.48 2 2 6.58 2 12.23c0 4.52 2.87 8.35 6.84 9.7.5.1.68-.22.68-.49l-.01-1.7c-2.78.62-3.37-1.21-3.37-1.21-.46-1.18-1.11-1.5-1.11-1.5-.91-.64.07-.62.07-.62 1 .07 1.53 1.06 1.53 1.06.9 1.57 2.35 1.12 2.92.85.09-.66.35-1.12.64-1.37-2.22-.26-4.56-1.14-4.56-5.07 0-1.12.39-2.04 1.03-2.76-.1-.26-.45-1.3.1-2.71 0 0 .84-.28 2.75 1.05a9.4 9.4 0 0 1 5 0c1.91-1.33 2.75-1.05 2.75-1.05.55 1.41.2 2.45.1 2.71.64.72 1.03 1.64 1.03 2.76 0 3.94-2.34 4.81-4.57 5.06.36.32.68.94.68 1.9l-.01 2.81c0 .27.18.6.69.49A10.24 10.24 0 0 0 22 12.23C22 6.58 17.52 2 12 2z" />
  </svg>
);

/* Figma test-viewer icons (5:15894), 14x14 */
export const IconTestCase = ({ size = 14, color = c.blue }: P) => (
  <svg width={size} height={size} viewBox="0 0 14 14" style={{ display: "block", flexShrink: 0 }}>
    <path fillRule="evenodd" clipRule="evenodd" fill={color} d="M7.42 1.87814C7.59086 1.70729 7.86788 1.70729 8.03874 1.878L12.1221 5.96149C12.2929 6.13235 12.2929 6.40932 12.1221 6.58017C11.9512 6.75103 11.6742 6.75103 11.5033 6.58017L11.2294 6.30624L5.41375 12.1218C4.43748 13.0981 2.85463 13.0981 1.87836 12.1218C0.90209 11.1456 0.90209 9.56276 1.87836 8.58649L7.69399 2.77083L7.42 2.49686C7.2492 2.32601 7.2492 2.04899 7.42 1.87814ZM8.31273 3.38955L4.70227 7H9.29816L10.6107 5.6875L8.31273 3.38955Z" />
    <path fill={color} d="M12.2523 3.5C12.2523 3.82216 11.9911 4.08333 11.6689 4.08333C11.3468 4.08333 11.0856 3.82216 11.0856 3.5C11.0856 3.17784 11.3468 2.91667 11.6689 2.91667C11.9911 2.91667 12.2523 3.17784 12.2523 3.5Z" />
    <path fill={color} d="M11.6689 1.45833C11.6689 1.94158 11.2772 2.33333 10.7939 2.33333C10.3107 2.33333 9.91894 1.94158 9.91894 1.45833C9.91894 0.975083 10.3107 0.583334 10.7939 0.583334C11.2772 0.583334 11.6689 0.975083 11.6689 1.45833Z" />
  </svg>
);

export const IconPassed = ({ size = 14, color = c.green }: P) => (
  <svg width={size} height={size} viewBox="0 0 14 14" style={{ display: "block", flexShrink: 0 }}>
    <path fillRule="evenodd" clipRule="evenodd" fill={color} d="M7 1.16667C3.77834 1.16667 1.16667 3.77834 1.16667 7C1.16667 10.2216 3.77834 12.8333 7 12.8333C10.2216 12.8333 12.8333 10.2216 12.8333 7C12.8333 3.77834 10.2216 1.16667 7 1.16667ZM9.08862 5.81871C9.24163 5.6317 9.21404 5.35607 9.02703 5.20306C8.84001 5.05006 8.56438 5.07762 8.41138 5.26462L6.09251 8.09883L5.26769 7.27399C5.09684 7.10313 4.81983 7.10313 4.64897 7.27399C4.47812 7.44485 4.47812 7.72182 4.64897 7.89268L5.81564 9.05934C5.90304 9.14678 6.02333 9.1931 6.14682 9.18697C6.27025 9.18079 6.38534 9.12269 6.46362 9.02703L9.08862 5.81871Z" />
  </svg>
);

export const IconSkipBack = ({ size = 14 }: P) => (
  <svg width={size} height={size} viewBox="0 0 14 14" style={{ display: "block" }}>
    <path fill="#191919" d="M3.79167 2.33333H2.625C2.46392 2.33333 2.33333 2.46392 2.33333 2.625V11.375C2.33333 11.5361 2.46392 11.6667 2.625 11.6667H3.79167C3.95275 11.6667 4.08333 11.5361 4.08333 11.375V2.625C4.08333 2.46392 3.95275 2.33333 3.79167 2.33333Z" />
    <path fill="#191919" d="M11.6667 11.6667V2.33333L5.25 7L11.6667 11.6667Z" />
  </svg>
);
export const IconPause = ({ size = 16 }: P) => (
  <svg width={size} height={size} viewBox="0 0 16 16" style={{ display: "block" }}>
    <path fill="#191919" d="M6 2.66667H4.66667C4.29848 2.66667 4 2.96514 4 3.33333V12.6667C4 13.0349 4.29848 13.3333 4.66667 13.3333H6C6.36819 13.3333 6.66667 13.0349 6.66667 12.6667V3.33333C6.66667 2.96514 6.36819 2.66667 6 2.66667Z" />
    <path fill="#191919" d="M11.3333 2.66667H10C9.63181 2.66667 9.33333 2.96514 9.33333 3.33333V12.6667C9.33333 13.0349 9.63181 13.3333 10 13.3333H11.3333C11.7015 13.3333 12 13.0349 12 12.6667V3.33333C12 2.96514 11.7015 2.66667 11.3333 2.66667Z" />
  </svg>
);
export const IconSkipFwd = ({ size = 14 }: P) => (
  <svg width={size} height={size} viewBox="0 0 14 14" style={{ display: "block" }}>
    <path fill="#191919" fillOpacity="0.56" d="M2.33333 2.33333V11.6667L8.75 7L2.33333 2.33333Z" />
    <path fill="#191919" fillOpacity="0.56" d="M11.375 2.33333H10.2083C10.0472 2.33333 9.91667 2.46392 9.91667 2.625V11.375C9.91667 11.5361 10.0472 11.6667 10.2083 11.6667H11.375C11.5361 11.6667 11.6667 11.5361 11.6667 11.375V2.625C11.6667 2.46392 11.5361 2.33333 11.375 2.33333Z" />
  </svg>
);
export const IconLoop = ({ size = 16 }: P) => (
  <svg width={size} height={size} viewBox="0 0 16 16" fill="none" stroke="#191919" strokeOpacity="0.56" strokeWidth="1.33333" strokeLinecap="round" strokeLinejoin="round" style={{ display: "block" }}>
    <path d="M11.3333 0.666666L14 3.33333L11.3333 6" />
    <path d="M2 7.33333V6C2 5.29276 2.28095 4.61448 2.78105 4.11438C3.28115 3.61428 3.95942 3.33333 4.66667 3.33333H14" />
    <path d="M4.66667 15.3333L2 12.6667L4.66667 10" />
    <path d="M14 8.66667V10C14 10.7072 13.719 11.3855 13.219 11.8856C12.7189 12.3857 12.0406 12.6667 11.3333 12.6667H2" />
  </svg>
);
export const IconDownload = ({ size = 16 }: P) => (
  <svg width={size} height={size} viewBox="0 0 16 16" fill="none" stroke="#191919" strokeOpacity="0.56" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" style={{ display: "block" }}>
    <path d="M8 2.5v7.6M5.4 7.6 8 10.2l2.6-2.6M2.5 9.8v1.6a2 2 0 0 0 2 2h7a2 2 0 0 0 2-2V9.8" />
  </svg>
);
