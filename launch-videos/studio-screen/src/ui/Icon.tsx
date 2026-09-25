import { Img, staticFile } from "remotion";

export type IconName =
  | "sidebar" | "session-info" | "flag" | "dots" | "computer" | "plus" | "expand" | "panel"
  | "kbd-cmd" | "kbd-enter" | "mic" | "voice" | "stop" | "slash" | "chevron" | "close" | "cursor"
  | "prev" | "pause" | "next" | "loop" | "download" | "setup" | "test" | "check";

export const Icon: React.FC<{ name: IconName; size: number; style?: React.CSSProperties }> = ({ name, size, style }) => (
  <Img src={staticFile(`icons/${name}.svg`)} style={{ width: size, height: size, display: "block", flexShrink: 0, ...style }} />
);
