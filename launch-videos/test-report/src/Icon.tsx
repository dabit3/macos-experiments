import { Img, staticFile } from "remotion";

export type IconName =
  | "check"
  | "chevron-right"
  | "close"
  | "computer"
  | "cursor"
  | "dots"
  | "download"
  | "flag"
  | "full-width"
  | "kbd-cmd"
  | "kbd-enter"
  | "loop"
  | "mic"
  | "next"
  | "panel"
  | "pause"
  | "plus"
  | "prev"
  | "session-info"
  | "shell"
  | "slash"
  | "stop"
  | "test"
  | "voice";

export const Icon: React.FC<{
  name: IconName;
  size: number;
  style?: React.CSSProperties;
}> = ({ name, size, style }) => (
  <Img
    src={staticFile(`icons/${name}.svg`)}
    style={{ width: size, height: size, display: "block", flexShrink: 0, ...style }}
  />
);

type SvgProps = { size?: number; color?: string; style?: React.CSSProperties };

const stroke = (color: string) => ({
  fill: "none",
  stroke: color,
  strokeWidth: 1.25,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
});

export const Chevron: React.FC<SvgProps & { dir?: "down" | "right" }> = ({
  size = 12,
  color = "rgba(25,25,25,0.56)",
  dir = "down",
  style,
}) => (
  <svg width={size} height={size} viewBox="0 0 12 12" style={style}>
    <path
      d={dir === "down" ? "M3 4.5 6 7.5 9 4.5" : "M4.5 3 7.5 6 4.5 9"}
      {...stroke(color)}
    />
  </svg>
);

export const ArrowUp: React.FC<SvgProps> = ({ size = 18, color = "#fff" }) => (
  <svg width={size} height={size} viewBox="0 0 18 18">
    <path d="M9 14.5v-11M4.5 8 9 3.5 13.5 8" {...stroke(color)} strokeWidth={1.4} />
  </svg>
);

export const Sliders: React.FC<SvgProps> = ({ size = 18, color = "#191919" }) => (
  <svg width={size} height={size} viewBox="0 0 18 18">
    <g {...stroke(color)}>
      <circle cx="5.5" cy="6" r="1.9" />
      <path d="M5.5 7.9v7.1M5.5 3v1.1" />
      <circle cx="12.5" cy="12" r="1.9" />
      <path d="M12.5 10.1V3M12.5 13.9V15" />
    </g>
  </svg>
);

export const Ubuntu: React.FC<SvgProps> = ({ size = 16 }) => (
  <svg width={size} height={size} viewBox="0 0 16 16">
    <circle cx="8" cy="8" r="4.6" fill="none" stroke="#e95420" strokeWidth="1.6" />
    {[0, 120, 240].map((a) => (
      <circle
        key={a}
        cx={8 + 5.6 * Math.cos(((a - 180) * Math.PI) / 180)}
        cy={8 + 5.6 * Math.sin(((a - 180) * Math.PI) / 180)}
        r="1.75"
        fill="#e95420"
        stroke="#f9f9f9"
        strokeWidth="0.9"
      />
    ))}
  </svg>
);

export const Apple: React.FC<SvgProps> = ({ size = 16, color = "#555" }) => (
  <svg width={size} height={size} viewBox="0 0 16 16">
    <path
      fill={color}
      d="M11.2 8.5c0-1.4 1.1-2 1.2-2.1-.7-1-1.7-1.1-2.1-1.1-.9-.1-1.7.5-2.2.5-.4 0-1.1-.5-1.9-.5-1 0-1.9.6-2.4 1.5-1 1.8-.3 4.4.7 5.8.5.7 1 1.5 1.8 1.4.7 0 1-.5 1.9-.5s1.1.5 1.9.5 1.3-.7 1.7-1.4c.5-.8.8-1.6.8-1.6s-1.4-.6-1.4-2.5ZM9.8 4.3c.4-.5.7-1.2.6-1.9-.6 0-1.3.4-1.7.9-.4.4-.7 1.1-.6 1.8.7.1 1.3-.3 1.7-.8Z"
    />
  </svg>
);

export const Windows: React.FC<SvgProps> = ({ size = 16 }) => (
  <svg width={size} height={size} viewBox="0 0 16 16">
    <rect x="2" y="2" width="5.6" height="5.6" fill="#f35325" />
    <rect x="8.4" y="2" width="5.6" height="5.6" fill="#81bc06" />
    <rect x="2" y="8.4" width="5.6" height="5.6" fill="#05a6f0" />
    <rect x="8.4" y="8.4" width="5.6" height="5.6" fill="#ffba08" />
  </svg>
);

export const Star: React.FC<SvgProps & { filled?: boolean }> = ({
  size = 14,
  color = "rgba(25,25,25,0.56)",
  filled,
}) => (
  <svg width={size} height={size} viewBox="0 0 14 14">
    <path
      d="M7 1.8 8.55 5l3.5.45-2.57 2.42.66 3.47L7 9.66l-3.14 1.68.66-3.47L1.95 5.45 5.45 5Z"
      fill={filled ? color : "none"}
      stroke={color}
      strokeWidth="1.1"
      strokeLinejoin="round"
    />
  </svg>
);

export const CheckMark: React.FC<SvgProps> = ({ size = 14, color = "rgba(25,25,25,0.56)" }) => (
  <svg width={size} height={size} viewBox="0 0 14 14">
    <path d="M2.8 7.3 5.6 10 11.2 4" {...stroke(color)} />
  </svg>
);

export const Laptop: React.FC<SvgProps> = ({ size = 14, color = "#1c6ae4" }) => (
  <svg width={size} height={size} viewBox="0 0 14 14">
    <g {...stroke(color)} strokeWidth={1.1}>
      <rect x="2.5" y="3" width="9" height="6.2" rx="1" />
      <path d="M1 11.2h12" />
    </g>
  </svg>
);

export const Sidebar: React.FC<SvgProps> = ({ size = 18, color = "#191919" }) => (
  <svg width={size} height={size} viewBox="0 0 18 18">
    <g {...stroke(color)} strokeWidth={1.1}>
      <rect x="2.5" y="3.5" width="13" height="11" rx="2" />
      <path d="M6.8 3.5v11" />
    </g>
  </svg>
);

export const Progress: React.FC<SvgProps> = ({ size = 16, color = "#191919" }) => (
  <svg width={size} height={size} viewBox="0 0 16 16">
    <g {...stroke(color)} strokeWidth={1.1}>
      <path d="M12 7V3.5A1.5 1.5 0 0 0 10.5 2h-6A1.5 1.5 0 0 0 3 3.5v9A1.5 1.5 0 0 0 4.5 14H7" />
      <path d="M5.5 5h4M5.5 7.5h2.5" />
      <circle cx="10.5" cy="10.5" r="2" />
      <path d="m12 12 1.6 1.6" />
    </g>
  </svg>
);

export const Expand: React.FC<SvgProps> = ({ size = 18, color = "#191919" }) => (
  <svg width={size} height={size} viewBox="0 0 18 18">
    <path d="M10.5 3.5h4v4M14.5 3.5 10 8M7.5 14.5h-4v-4M3.5 14.5 8 10" {...stroke(color)} strokeWidth={1.1} />
  </svg>
);
