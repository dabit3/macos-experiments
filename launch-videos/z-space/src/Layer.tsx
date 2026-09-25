import React from "react";
import { C } from "./theme";
import { Pose, transform } from "./motion";

export type Rect = { x: number; y: number; w: number; h: number };

export const Layer: React.FC<{
  rect: Rect;
  pose: Pose;
  lift?: number;
  radius?: number;
  card?: boolean;
  bg?: string;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ rect, pose, lift = 0, radius = 12, card = true, bg, children, style }) => {
  const l = Math.max(0, Math.min(1, lift));
  const shadow =
    l > 0.001
      ? `0 ${1 + 2 * l}px ${2 + 4 * l}px rgba(0,0,0,${0.04 * l}), 0 ${10 * l}px ${30 * l}px rgba(0,0,0,${0.07 * l}), 0 ${30 * l}px ${70 * l}px rgba(0,0,0,${0.06 * l})`
      : "none";
  return (
    <div
      style={{
        position: "absolute",
        left: rect.x,
        top: rect.y,
        width: rect.w,
        height: rect.h,
        transform: transform(pose),
        transformStyle: "preserve-3d",
        opacity: pose.o,
        borderRadius: radius,
        background: bg ?? (card ? `rgba(253,253,253,${l})` : undefined),
        boxShadow: card ? shadow : undefined,
        outline: card && l > 0.001 ? `0.8px solid rgba(0,0,0,${0.07 * l})` : undefined,
        backfaceVisibility: "hidden",
        ...style,
      }}
    >
      {children}
    </div>
  );
};

export const Stage: React.FC<{ camera: Pose; scale: number; children: React.ReactNode; bg?: string }> = ({ camera, scale, children, bg = C.stage }) => (
  <div style={{ position: "absolute", inset: 0, background: bg, perspective: 2600, perspectiveOrigin: "50% 50%", overflow: "hidden" }}>
    <div
      style={{
        position: "absolute",
        left: "50%",
        top: "50%",
        width: 0,
        height: 0,
        transformStyle: "preserve-3d",
        transform: `translate3d(${camera.x}px, ${camera.y}px, ${camera.z}px) rotateX(${camera.rx}deg) rotateY(${camera.ry}deg) rotateZ(${camera.rz}deg) scale(${scale * camera.s})`,
      }}
    >
      {children}
    </div>
  </div>
);
